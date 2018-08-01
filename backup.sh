#!/bin/bash

set -e

NOW=`date '+%Y%m%d-%H%M'`
BACKUP_FILE_PREFIX="backup"

usage() { echo "Usage: backup [-f (exclude ghost files)] [-d (exclude db)] [-p (do not purge old backups)]" 1>&2; exit 0; }

# Simple log, write to stdout
log () {
  echo "`date -u`: $1" | tee -a $LOG_LOCATION
}

# Backup the ghost DB (either sqlite3 or mysql)
backupDB () {
  # Test the env that is set if a mysql container is linked
  if [ -z $MYSQL_NAME ]; then
    # sqlite
    log " creating ghost db archive (sqlite)..."
    cd $GHOST_LOCATION/content/data && sqlite3 ghost.db ".backup temp.db" && gzip -c temp.db > "$BACKUP_LOCATION/$BACKUP_FILE_PREFIX-db_$NOW.gz" && rm temp.db
  else
    # mysql/mariadb
    log " creating ghost db archive (mysql)..."
    # If container has been linked correctly, these environment variables should be available
    if [ -z "$MYSQL_ENV_MYSQL_USER" ]; then log "Error: MYSQL_ENV_MYSQL_USER not set. Have you linked in the mysql/mariadb container?"; log "Finished: FAILURE"; exit 1; fi
    if [ -z "$MYSQL_ENV_MYSQL_DATABASE" ]; then log "Error: MYSQL_ENV_MYSQL_DATABASE not set. Have you linked in the mysql/mariadb container?"; log "Finished: FAILURE"; exit 1; fi
    if [ -z "$MYSQL_ENV_MYSQL_PASSWORD" ]; then log "Error: MYSQL_ENV_MYSQL_PASSWORD not set. Have you linked in the mysql/mariadb container?"; log "Finished: FAILURE"; exit 1; fi
    mysqldump -h mysql --single-transaction -u $MYSQL_ENV_MYSQL_USER --password=$MYSQL_ENV_MYSQL_PASSWORD $MYSQL_ENV_MYSQL_DATABASE | 
     gzip -c > $BACKUP_LOCATION/$BACKUP_FILE_PREFIX-db_$NOW.gz
   fi

  log "...completed: $BACKUP_LOCATION/$BACKUP_FILE_PREFIX-db_$NOW.gz"
}

# Backup the ghost static files (images, themes, apps etc) but not the /data directory (the db backup handles that)
backupGhost () {
  log " creating ghost files archive..."
  #Exclude  /content/data  (we back that up separately), current and versions (Ghost source files from docker image), and content.orig (created when Ghost was built)
  tar cfz "$BACKUP_LOCATION/$BACKUP_FILE_PREFIX-ghost_$NOW.tar.gz" --directory=$GHOST_LOCATION --exclude='content/data' --exclude='content.orig' --exclude='current' --exclude='versions' . 2>&1 | tee -a $LOG_LOCATION 
  log " ...completed: $BACKUP_LOCATION/$BACKUP_FILE_PREFIX-ghost_$NOW.tar.gz"
}

# Purge the backups directory so we only keep the most recent backups
purgeOldBackups () {
  # Each backup contains 2 files, one each for the db and file archives
  RETAIN_FILES=$((2 * $BACKUPS_RETAIN_LIMIT))
  # Remove all the backup files, apart from the RETAIN_FILES most recent ones
  cd $BACKUP_LOCATION && (ls -t | grep $BACKUP_FILE_PREFIX | head -n $RETAIN_FILES; ls | grep $BACKUP_FILE_PREFIX) | sort | uniq -u | xargs --no-run-if-empty rm
}

#By default do a complete backup with purging
include_files=true
include_db=true
purge=true
while getopts "FDP" opt; do
  case $opt in
    F)
      include_files=false
      log "excluding ghost files archive in backup"
      ;;
    D)
      include_db=false
      log "excluding db archive in backup"
      ;;
    P)
      purge=false
      log "not purging old backups (limit is set to $BACKUPS_RETAIN_LIMIT)"
      ;;
    \?)
      usage
      exit 0
      ;;
  esac
done

# Initiate the backup
log "creating backup: $NOW..."
if [ $include_files = true ]; then
  backupGhost
fi
if [ $include_db = true ]; then
  backupDB
fi
if [ $purge = true ]; then
  purgeOldBackups
fi

log "completed backup to $BACKUP_LOCATION"