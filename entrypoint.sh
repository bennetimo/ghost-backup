#!/bin/bash

set -e

if [ "$AUTOMATED_BACKUPS" == "true" ]; then

    CRON_TAB="/etc/cron.d/ghost-backup"
    ENV_FILE="/root/ghost-backup-envs.sh"

    echo "Automated backups are on...installing crontab..."
    printenv | sed 's/^\(.*\)\=\(.*\)$/export \1\="\2"/g' > $ENV_FILE
    chmod +x $ENV_FILE
    (echo "$BACKUP_TIME root . $ENV_FILE; /bin/backup"; echo "")  > $CRON_TAB

    cat $CRON_TAB
fi

# Create the backup folder if it doesn't exist
mkdir -p $BACKUP_LOCATION

echo "ghost-backup setup complete"
exec "$@"