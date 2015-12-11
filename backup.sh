#!/bin/bash

echo "Backing up Ghost files to $BACKUP_LOCATION"
tar cvfz $BACKUP_LOCATION/backup_`date '+%Y%m%d'`.tar.gz /var/lib/ghost

echo "Backup complete"
