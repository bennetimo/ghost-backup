#!/bin/bash

# Ghost files location
GHOST_LOCATION='/var/lib/ghost'

NOW=`date '+%Y%m%d-%H%M'`

# Backup the ghost DB (either sqlite3 or mysql)
backupDB () {
  echo "Creating ghost database archive..."
  DB=${DB_TYPE:-"sqlite3"}
  case $DB in
    "sqlite3")
      cd $GHOST_LOCATION/data && sqlite3 ghost.db ".backup temp.db" && gzip -c temp.db > "$BACKUP_LOCATION/backup-db_$NOW.gz" && rm temp.db
      echo "...ghost DB archive created at: $BACKUP_LOCATION/backup-db_$NOW.gz"
      ;;
    "mysql")
      # If container has been linked correctly, these environment variables should be available
      if [ -z "$MYSQL_ENV_MYSQL_USER" ]; then echo "Error: MYSQL_ENV_MYSQL_USER not set. Have you linked in the mysql/mariadb container?"; echo "Finished: FAILURE"; exit 1; fi
      if [ -z "$MYSQL_ENV_MYSQL_DATABASE" ]; then echo "Error: MYSQL_ENV_MYSQL_DATABASE not set. Have you linked in the mysql/mariadb container?"; echo "Finished: FAILURE"; exit 1; fi
      if [ -z "$MYSQL_ENV_MYSQL_ROOT_PASSWORD" ]; then echo "Error: MYSQL_ENV_MYSQL_PASSWORD not set. Have you linked in the mysql/mariadb container?"; echo "Finished: FAILURE"; exit 1; fi
      mysqldump -h mysql --single-transaction -u $MYSQL_ENV_MYSQL_USER --password=$MYSQL_ENV_MYSQL_ROOT_PASSWORD $MYSQL_ENV_MYSQL_DATABASE | 
       gzip -c > $BACKUP_LOCATION/backup-db_$NOW.sql.gz
      echo "...ghost DB archive created at: $BACKUP_LOCATION/backup-db_$NOW.gz"
      ;;
    *)
      echo "Database type '$DB' not recognised. Have you set the environment variable $DB_TYPE correctly? (sqlite3 | mysql)"
      exit 1
      ;;
  esac
}

# Backup the ghost static files (images, themes, apps etc) but not the /data directory (the db backup handles that)
backupGhost () {
  echo "Creating ghost files archive..."
  tar cvfz "$BACKUP_LOCATION/backup-ghost_$NOW.tar.gz" --directory=$GHOST_LOCATION --exclude='data' . #Exclude the /data directory (we back that up separately)
  echo "...ghost files archive created at: $BACKUP_LOCATION/backup-ghost_$NOW.tar.gz"
}

# Purge the backups directory so we only keep the most recent backups
purgeOldBackups () {
  # Each backup contains 2 files, one each for the db and file archives
  RETAIN_FILES=$((2 * $BACKUPS_RETAIN_LIMIT))
  # Remove all the backup files, apart from the RETAIN_FILES most recent ones
  cd $BACKUP_LOCATION && (ls -t | head -n $RETAIN_FILES; ls) | sort | uniq -u | xargs --no-run-if-empty rm
}

# Initiate the backup
backupGhost
backupDB
purgeOldBackups

echo "Completed backup to $BACKUP_LOCATION"