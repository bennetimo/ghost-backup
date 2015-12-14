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

backupGhost () {
  echo "Creating ghost files archive..."
  tar cvfz "$BACKUP_LOCATION/backup-ghost_$NOW.tar.gz" --directory=$GHOST_LOCATION --exclude='data' . #Exclude the /data directory (we back that up separately)
  echo "...ghost files archive created at: $BACKUP_LOCATION/backup-ghost_$NOW.tar.gz"
}

# Initiate the backup
backupGhost
backupDB

echo "Completed backup to $BACKUP_LOCATION"