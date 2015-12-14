#!/bin/bash

# Ghost files location
GHOST_LOCATION='/var/lib/ghost'

# If container has been linked correctly, these environment variables should be available
if [ -z "$MYSQL_ENV_MYSQL_USER" ]; then echo "Error: MYSQL_ENV_MYSQL_USER not set. Have you linked in the mysql/mariadb container?"; echo "Finished: FAILURE"; exit 1; fi
if [ -z "$MYSQL_ENV_MYSQL_DATABASE" ]; then echo "Error: MYSQL_ENV_MYSQL_DATABASE not set. Have you linked in the mysql/mariadb container?"; echo "Finished: FAILURE"; exit 1; fi
if [ -z "$MYSQL_ENV_MYSQL_ROOT_PASSWORD" ]; then echo "Error: MYSQL_ENV_MYSQL_PASSWORD not set. Have you linked in the mysql/mariadb container?"; echo "Finished: FAILURE"; exit 1; fi

echo "Creating ghost files archive"
tar cvfz "$BACKUP_LOCATION/backup-ghost_`date '+%Y%m%d'`.tar.gz" --directory=$GHOST_LOCATION .

echo "Creating database dump"
mysqldump -h mysql --single-transaction -u $MYSQL_ENV_MYSQL_USER --password=$MYSQL_ENV_MYSQL_ROOT_PASSWORD $MYSQL_ENV_MYSQL_DATABASE | 
 gzip -c > $BACKUP_LOCATION/backup-db_`date '+%Y%m%d'`.sql.gz

echo "Completed backup to $BACKUP_LOCATION"