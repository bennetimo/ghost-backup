#!/bin/bash

set -e

# Match string to indicate a ghost archive
GHOST_ARCHIVE_MATCH='ghost'
# Match string to indicate a db archive
DB_ARCHIVE_MATCH='db'
# Whether to extract the ghost files in place (without removing existing files first)
IN_PLACE_RESTORE=false

usage() { echo "Usage: restore [-i (interactive)] [-d yyyymmdd-hhmm] [-f filename]" 1>&2; exit 0; }

# Simple log, write to stdout
log () {
  echo "`date -u`: $1" | tee -a $LOG_LOCATION
}

# Restore the database from the given archive file
restoreDB () {
  RESTORE_FILE=$1

  # Test the env that is set if a mysql container is linked
  if [ -z $MYSQL_NAME ]; then
    # sqlite
    log "restoring data from sqlite dump file: $RESTORE_FILE"
    cd $GHOST_LOCATION/content/data && gunzip -c $RESTORE_FILE > temp.db && sqlite3 ghost.db ".restore temp.db" && rm temp.db
    log "...restored ghost DB archive $RESTORE_FILE"
  else
    # mysql/mariadb
    log "restoring data from mysql dump file: $RESTORE_FILE"
    # If container has been linked correctly, these environment variables should be available
    if [ -z "$MYSQL_ENV_MYSQL_USER" ]; then log "Error: MYSQL_ENV_MYSQL_USER not set. Have you linked in the mysql/mariadb container?"; log "Finished: FAILURE"; exit 1; fi
    if [ -z "$MYSQL_ENV_MYSQL_DATABASE" ]; then log "Error: MYSQL_ENV_MYSQL_DATABASE not set. Have you linked in the mysql/mariadb container?"; log "Finished: FAILURE"; exit 1; fi
    if [ -z "$MYSQL_ENV_MYSQL_PASSWORD" ]; then log "Error: MYSQL_ENV_MYSQL_PASSWORD not set. Have you linked in the mysql/mariadb container?"; log "Finished: FAILURE"; exit 1; fi
    gunzip < $RESTORE_FILE | mysql -u$MYSQL_ENV_MYSQL_USER -p $MYSQL_ENV_MYSQL_DATABASE -p$MYSQL_ENV_MYSQL_PASSWORD -h mysql || exit 1
    log "...restored ghost DB archive $RESTORE_FILE"
  fi
  
  log "restore complete"
}

# Restore the ghost files (themes etc) from the given archive file
restoreGhost () {
  RESTORE_FILE=$1

  if [ $IN_PLACE_RESTORE = true ]; then
    log "restoring ghost files from archive file: $RESTORE_FILE"
    tar -xzf $RESTORE_FILE --directory=$GHOST_LOCATION --keep-newer-files --warning=no-ignore-newer 2>&1 | tee -a $LOG_LOCATION
  else
    log "removing ghost files in $GHOST_LOCATION"
    rm -r $GHOST_LOCATION/content/apps/ $GHOST_LOCATION/content/images/ $GHOST_LOCATION/content/themes/ #Do not remove /data or config.production.json
    log "restoring ghost files from archive file: $RESTORE_FILE"
    tar -xzf $RESTORE_FILE --directory=$GHOST_LOCATION 2>&1 | tee -a $LOG_LOCATION
  fi

  log "restore complete"
}

# Interactively choose a DB or ghost files archive to restore
chooseFile () {
  echo "Select DB or Ghost archive file to restore, or 'q' to quit"
  PS3="Restore #: "

  select FILENAME in $BACKUP_LOCATION/*;
  do
    [[ -z $FILENAME ]] && choice=$REPLY || choice=$FILENAME
    case $choice in
        q|Q|exit) 
          break;
          ;;
        *)
          restoreFile $choice
          ;;
        \?)
          echo "usage..."
          ;;
    esac
  done
}

# Attempt to restore ghost and db files from a given yyyymmdd-hhmm date
restoreDate () {
  DATE=$1
  GHOST_ARCHIVE="$BACKUP_LOCATION/backup-ghost_$DATE.tar.gz"
  DB_ARCHIVE="$BACKUP_LOCATION/backup-db_$DATE.gz"

  if [ ! -f $GHOST_ARCHIVE ]; then
      log "The ghost archive file $GHOST_ARCHIVE does not exist. Aborting."
      exit 1
  fi
  if [ ! -f $DB_ARCHIVE ]; then
      log "The ghost db archive file $DB_ARCHIVE does not exist. Aborting."
      exit 1
  fi

  log "Restoring ghost files and db from date: $DATE"
  restoreGhost $GHOST_ARCHIVE
  restoreDB $DB_ARCHIVE
}

# Determine whether file is db or ghost file and restore it
restoreFile () {
  FILE=$1
  if [[ $FILE =~ .*$DB_ARCHIVE_MATCH.* ]]; then
    restoreDB $FILE
  elif [[ $FILE =~ .*$GHOST_ARCHIVE_MATCH.* ]]; then
    restoreGhost $FILE
  else
    echo "unrecognised format - the file should be either a ghost files or db archive"
  fi

}

while getopts "idf:IDF:" opt; do
  case $opt in
    i)
      chooseFile
      exit 0
      ;;
    I)
      IN_PLACE_RESTORE=true
      chooseFile
      exit 0
      ;;
    d)
      restoreDate ${OPTARG}
      exit 0
      ;;
    D)
      IN_PLACE_RESTORE=true
      restoreDate ${OPTARG}
      exit 0
      ;;
    f)
      restoreFile ${OPTARG}
      exit 0
      ;;  
    F)
      IN_PLACE_RESTORE=true
      restoreFile ${OPTARG}
      exit 0
      ;;  
    \?)
      usage
      exit 0
      ;;
  esac
done

usage