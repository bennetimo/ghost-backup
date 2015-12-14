#!/bin/bash

# Install the crontab for ghost-backup if it does not exist already
if [[ $(crontab -l 2>/dev/null | egrep -c ghost-backup) -le 1 ]]; then
  echo "Intalling cron entry to start ghost-backup at: $BACKUP_TIME"
  # Note: Must use tabs with indented 'here' scripts.
  {
  	cat <<-EOF
	BACKUP_LOCATION=$BACKUP_LOCATION
	$BACKUP_TIME ghost-backup
	EOF
  } | crontab -
fi

exec "$@"