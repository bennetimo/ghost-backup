#!/bin/bash

# Install the crontab for ghost-backup if it does not exist already
if [ $(crontab -l 2>/dev/null | egrep -c ghost-backup) -le 1 ] && [ "$AUTOMATED_BACKUPS" == "true" ]; then
  echo "Intalling cron entry to start ghost-backup at: $BACKUP_TIME"
  
  # Add mysql env vars to the heredoc if that is the db being used
  if [ -z $MYSQL_NAME ]; then
  	# sqlite
  	MYSQL_ENVS=""
  else
  	# mysql/mariadb
  	cat <<-EOF>~/mysql.env
	MYSQL_NAME=$MYSQL_NAME
	MYSQL_ENV_MYSQL_USER=$MYSQL_ENV_MYSQL_USER
	MYSQL_ENV_MYSQL_DATABASE=$MYSQL_ENV_MYSQL_DATABASE
	MYSQL_ENV_MYSQL_PASSWORD=$MYSQL_ENV_MYSQL_PASSWORD
	EOF
	MYSQL_ENVS=". ~/mysql.env; "
	chmod 600 ~/mysql.env
  fi

  {
  	cat <<-EOF
	BACKUP_LOCATION=$BACKUP_LOCATION
	BACKUPS_RETAIN_LIMIT=$BACKUPS_RETAIN_LIMIT
	$BACKUP_TIME $MYSQL_ENVS /bin/backup >> $LOG_LOCATION 2>&1
	EOF
  } | crontab -
fi

echo "crontab for ghost-backup is:"
crontab -l

exec "$@"