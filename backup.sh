#!/bin/bash

set -e

#Load common vars
source common.sh

usage() { echo "Usage: backup [-F (exclude ghost content files)] [-J (exclude ghost json file)] [-D (exclude db)] [-p (do not purge old backups)]" 1>&2; exit 0; }

# Backup the ghost DB (either sqlite3 or mysql)
backupDB () {
  # Test the env that is set if a mysql container is linked
  export_file=$BACKUP_LOCATION/$BACKUP_FILE_PREFIX-db_$NOW.gz
  if [ $MYSQL_CONTAINER_LINKED = true ]; then
    # mysql/mariadb

    log " creating ghost db archive (mysql)..."
    mysqldump -h $MYSQL_SERVICE_NAME --single-transaction -u $MYSQL_SERVICE_USER --password=$MYSQL_SERVICE_PASSWORD $MYSQL_SERVICE_DATABASE |
     gzip -c > $export_file

  else
    # sqlite

    log " creating ghost db archive (sqlite)..."
    cd $GHOST_LOCATION/content/data && sqlite3 $SQLITE_DB_NAME ".backup temp.db" && gzip -c temp.db > $export_file && rm temp.db
  fi

  log " ...completed: $export_file"
}

# Backup the ghost static files (images, themes, apps etc) but not the /data directory (the db backup handles that)
backupGhost () {
  log " creating ghost content files archive..."
  export_file="$BACKUP_LOCATION/$BACKUP_FILE_PREFIX-ghost_$NOW.tar.gz"
  #Exclude  /content/data  (we back that up separately), current and versions (Ghost source files from docker image), and content.orig (created when Ghost was built)
  tar cfz $export_file --directory=$GHOST_LOCATION --exclude='content/data' --exclude='content.orig' --exclude='current' --exclude='versions' . 2>&1 | tee -a $LOG_LOCATION
  log " ...completed: $export_file"
}

# Backup the ghost static files (images, themes, apps etc) but not the /data directory (the db backup handles that)
backupGhostJsonFile () {
  log " ...exporting ghost json file..."
  export_file="$BACKUP_LOCATION/$BACKUP_FILE_PREFIX-ghost_$NOW.json"

  checkGhostAvailable

  if [ $GHOST_CONTAINER_LINKED = true ]; then
    retrieveClientSecret
    retrieveClientBearerToken
    log " ...downloading ghost json file..."
    curl --silent -o $export_file http://$GHOST_SERVICE_NAME:$GHOST_SERVICE_PORT/ghost/api/v0.1/db?access_token=$BEARER_TOKEN
    log " ...completed: $export_file"
  else
    log "Error: Your ghost service was not found on the network. Make sure you have configured GHOST_SERVICE_NAME and GHOST_SERVICE_PORT correctly"; log "Finished: FAILURE";
    exit 1;
  fi

}

# Purge the backups directory so we only keep the most recent backups
purgeOldBackups () {
  log "purging old backups (set to retain the most recent $BACKUPS_RETAIN_LIMIT)"
  # Keep only the most recent number of db archives
  purgeFiles $DB_ARCHIVE_MATCH "database"
  # Keep only the most recent number of ghost content archives
  purgeFiles $GHOST_ARCHIVE_MATCH "ghost content archive"
  # Keep only the most recent number of ghost json files
  purgeFiles $GHOST_JSON_FILE_MATCH "ghost json"
}

purgeFiles () {
    match=$1
    type=$2

    cd $BACKUP_LOCATION
    num_files=$(ls | grep "$match" | wc -l)
    num_purge=$((num_files-BACKUPS_RETAIN_LIMIT))
    num_purge="$(( $num_purge < 0 ? 0 : $num_purge ))"

    log " ...found $num_files $type files (purging $num_purge)"
    (ls -t | grep $match | head -n $BACKUPS_RETAIN_LIMIT; ls | grep $match) | sort | uniq -u | xargs --no-run-if-empty rm
}

#By default do a complete backup with purging
include_db=true
include_files=true
include_json_file=true
purge=true
while getopts "FDJp" opt; do
  case $opt in
    D)
      include_db=false
      log "-D set: excluding db archive in backup"
      ;;
    F)
      include_files=false
      log "-F set: excluding ghost files archive in backup"
      ;;
    J)
      include_json_file=false
      log "-J set: excluding ghost json in backup"
      ;;
    p)
      purge=false
      log "-p set: not purging old backups (limit is set to $BACKUPS_RETAIN_LIMIT)"
      ;;
    \?)
      usage
      exit 0
      ;;
  esac
done

# Initiate the backup
log "creating backup: $NOW..."

log "backing up ghost database"
if [ $include_db = true ]; then backupDB; else log " ...skipped" ; fi
log "backing up ghost content files"
if [ $include_files = true ]; then backupGhost; else log " ...skipped" ; fi
log "backing up ghost json file"
if [ $include_json_file = true ]; then backupGhostJsonFile; else log " ...skipped" ; fi

if [ $purge = true ]; then
  purgeOldBackups
fi

log "completed backup to $BACKUP_LOCATION"