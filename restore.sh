#!/bin/bash

# Match string to indicate a ghost archive
GHOST_ARCHIVE_MATCH='ghost'
# Match string to indicate a db archive
DB_ARCHIVE_MATCH='db'
# Ghost files location
GHOST_LOCATION='/var/lib/ghost'

usage() { echo "Usage: restore [-i (interactive)] [-d <yyyymmdd-hhmm>]" 1>&2; exit 1; }

# Restore the database from the given archive file
restoreDB () {
  RESTORE_FILE=$1

  # Test the env that is set if a mysql container is linked
  if [ -z $MYSQL_NAME ]; then
    # sqlite
    echo "restoring data from sqlite dump file: $RESTORE_FILE"
    cd $GHOST_LOCATION/data && gunzip -c $RESTORE_FILE > temp.db && sqlite3 ghost.db ".restore temp.db" && rm temp.db
    echo "...restored ghost DB archive $RESTORE_FILE"
  else
    # mysql/mariadb
    echo "restoring data from mysql dump file: $RESTORE_FILE"
    # If container has been linked correctly, these environment variables should be available
    if [ -z "$MYSQL_ENV_MYSQL_USER" ]; then echo "Error: MYSQL_ENV_MYSQL_USER not set. Have you linked in the mysql/mariadb container?"; echo "Finished: FAILURE"; exit 1; fi
    if [ -z "$MYSQL_ENV_MYSQL_DATABASE" ]; then echo "Error: MYSQL_ENV_MYSQL_DATABASE not set. Have you linked in the mysql/mariadb container?"; echo "Finished: FAILURE"; exit 1; fi
    if [ -z "$MYSQL_ENV_MYSQL_ROOT_PASSWORD" ]; then echo "Error: MYSQL_ENV_MYSQL_PASSWORD not set. Have you linked in the mysql/mariadb container?"; echo "Finished: FAILURE"; exit 1; fi
    gunzip < $RESTORE_FILE | mysql -u$MYSQL_ENV_MYSQL_USER -p $MYSQL_ENV_MYSQL_DATABASE -p$MYSQL_ENV_MYSQL_ROOT_PASSWORD -h mysql 
    echo "...restored ghost DB archive $RESTORE_FILE"
  fi
  
  echo "restore complete"
}

# Restore the ghost files (themes etc) from the given archive file
restoreGhost () {
  RESTORE_FILE=$1
  echo "removing ghost files in $GHOST_LOCATION"
  rm -r $GHOST_LOCATION/apps/ $GHOST_LOCATION/images/ $GHOST_LOCATION/themes/ $GHOST_LOCATION/config.js #Do not remove /data
  echo "restoring ghost files from archive file: $RESTORE_FILE"
  tar -xzf $RESTORE_FILE --directory=$GHOST_LOCATION
  echo "restore complete"
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
          if [[ $choice =~ .*$DB_ARCHIVE_MATCH.* ]]; then
            restoreDB $choice
          elif [[ $choice =~ .*$GHOST_ARCHIVE_MATCH.* ]]; then
            restoreGhost $choice
          else
            echo "unrecognised format - the file should be either a ghost files or db archive"
          fi
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
      echo "The ghost archive file $GHOST_ARCHIVE does not exist. Aborting."
      exit 1
  fi
  if [ ! -f $DB_ARCHIVE ]; then
      echo "The ghost db archive file $DB_ARCHIVE does not exist. Aborting."
      exit 1
  fi

  echo "Restoring ghost files and db from date: $DATE"
  restoreGhost $GHOST_ARCHIVE
  restoreDB $DB_ARCHIVE
}

while getopts "id:" opt; do
  case $opt in
    i)
      chooseFile
      exit 0
      ;;
    d)
      restoreDate ${OPTARG}
      exit 0
      ;;
    \?)
      usage
      exit 0
      ;;
  esac
done

usage



