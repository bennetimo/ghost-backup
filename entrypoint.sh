#!/bin/bash

# Install the crontab for ghost-backup if it does not exist already
if [[ $(crontab -l 2>/dev/null | egrep -c ghost-backup) -le 1 ]]; then
  echo "Intalling cron entry to start ghost-backup at: $BACKUP_TIME"
  
  # Add mysql env vars to the heredoc if that is the db being used
  if [ "$MYSQL_ENV_DB_CLIENT" == "mysql" ]; then 
  	read -r -d '' MYSQL_ENVS <<-EOF
	MYSQL_ENV_DB_CLIENT=$MYSQL_ENV_DB_CLIENT
	MYSQL_ENV_MYSQL_USER=$MYSQL_ENV_MYSQL_USER
	MYSQL_ENV_MYSQL_DATABASE=$MYSQL_ENV_MYSQL_DATABASE
	MYSQL_ENV_MYSQL_ROOT_PASSWORD=$MYSQL_ENV_MYSQL_ROOT_PASSWORD
	EOF
  else
  	MYSQL_ENVS=""
  fi
  # Note: Must use tabs with indented 'here' scripts.
  {
  	cat <<-EOF
	BACKUP_LOCATION=$BACKUP_LOCATION
	BACKUPS_RETAIN_LIMIT=$BACKUPS_RETAIN_LIMIT
	$MYSQL_ENVS
	$BACKUP_TIME ghost-backup >> $LOG_LOCATION 2>&1
	EOF
  } | crontab -
fi

echo "crontab for ghost-backup is:"
crontab -l

exec "$@"