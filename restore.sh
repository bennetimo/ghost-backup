#!/bin/bash

set -e

#Load common vars
source common.sh

# Whether to extract the ghost files in place (without removing existing files first)
IN_PLACE_RESTORE=false

usage() { echo "Usage: restore [-i (interactive)] [-d yyyymmdd-hhmm] [-f filename]" 1>&2; exit 0; }

# Restore the database from the given archive file
restoreDB () {
  RESTORE_FILE=$1

  # Check if we should restore a mysql or sqlite file
  if [ $MYSQL_CONTAINER_LINKED = true ]; then
    # mysql/mariadb
    log "restoring data from mysql dump file: $RESTORE_FILE"
    # If container has been linked correctly, these environment variables should be available

    gunzip < $RESTORE_FILE | mysql --host=$MYSQL_SERVICE_NAME  --port=$MYSQL_SERVICE_PORT --user=$MYSQL_USER --password=$MYSQL_PASSWORD $MYSQL_DATABASE || exit 1
  else
    # sqlite
    log "restoring data from sqlite dump file: $RESTORE_FILE"
    cd $GHOST_LOCATION/content/data && gunzip -c $RESTORE_FILE > temp.db && sqlite3 ghost.db ".restore temp.db" && rm temp.db
  fi

  log "...restore complete"
}

# Restore the ghost files (themes etc) from the given archive file
restoreGhost () {
  RESTORE_FILE=$1

  if [ $IN_PLACE_RESTORE = true ]; then
    log "restoring ghost files from archive file: $RESTORE_FILE"
    tar -xzf $RESTORE_FILE --directory=$GHOST_LOCATION --keep-newer-files --warning=no-ignore-newer 2>&1 | tee -a $LOG_LOCATION
  else
    log "removing ghost files in $GHOST_LOCATION"
    rm -rf $GHOST_LOCATION/content/apps/ $GHOST_LOCATION/content/images/ $GHOST_LOCATION/content/settings/ $GHOST_LOCATION/content/themes/ #Do not remove /data or config.production.json
    log "restoring ghost files from archive file: $RESTORE_FILE"
    tar -xzf $RESTORE_FILE --directory=$GHOST_LOCATION --exclude='config.production.json' 2>&1 | tee -a $LOG_LOCATION
  fi

  log "...restore complete"
}

# Restore the database from the given json file
restoreGhostJsonFile () {
  RESTORE_FILE=$1

  log "restoring data from ghost json export file: $RESTORE_FILE"

  checkGhostAvailable

  if [ $GHOST_CONTAINER_LINKED = true ]; then
    retrieveClientSecret
    retrieveClientBearerToken
    log " ...uploading and importing ghost json file..."
    curl --silent --form "importfile=@$RESTORE_FILE" -H "Authorization: Bearer $BEARER_TOKEN" $GHOST_SERVICE_NAME:$GHOST_SERVICE_PORT/ghost/api/v0.1/db
  else
    log "Error: Your ghost service was not found on the network. Configure GHOST_SERVICE_NAME and GHOST_SERVICE_PORT"; exit 1
  fi

  log "...restore complete"
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
  GHOST_ARCHIVE="$BACKUP_LOCATION/$BACKUP_FILE_PREFIX-ghost_$DATE.tar.gz"
  DB_ARCHIVE="$BACKUP_LOCATION/$BACKUP_FILE_PREFIX-db_$DATE.gz"

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
  elif [[ $FILE =~ .*$GHOST_JSON_FILE_MATCH.* ]]; then
    restoreGhostJsonFile $FILE
  else
    echo "unrecognised format - the file should be either a ghost content archive, db archive, or exported ghost .json file"
  fi
}

while getopts "id:f:ID:F:" opt; do
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
