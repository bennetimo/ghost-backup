#!/bin/bash

# Match string to indicate a ghost archive
GHOST_ARCHIVE_MATCH='ghost'
# Match string to indicate a db archive
DB_ARCHIVE_MATCH='db'
# Ghost files location
GHOST_LOCATION='/var/lib/ghost'

usage() { echo "Usage: ghost-restore [-i (interactive)] [-d <yyyymmdd>]" 1>&2; exit 1; }

# Restore the database from the given archive file
restoreDB () {
  RESTORE_FILE=$1
  echo "restoring data from mysql dump file: $RESTORE_FILE"
  gunzip < $RESTORE_FILE | mysql -u$MYSQL_ENV_MYSQL_USER -p $MYSQL_ENV_MYSQL_DATABASE -p$MYSQL_ENV_MYSQL_ROOT_PASSWORD -h mysql 
  echo "restore complete"
}

# Restore the ghost files (themes etc) from the given archive file
restoreGhost () {
  RESTORE_FILE=$1
  echo "removing ghost files in $GHOST_LOCATION"
  rm -r $GHOST_LOCATION/*
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

# Attempt to restore ghost and db files from a given yyyymmdd date
restoreDate () {
  DATE=$1
  GHOST_ARCHIVE="$BACKUP_LOCATION/backup-ghost_$DATE.tar.gz"
  DB_ARCHIVE="$BACKUP_LOCATION/backup-db_$DATE.sql.gz"

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



