#!/bin/bash

# Match string to indicate a ghost archive
GHOST_ARCHIVE_MATCH='ghost'
# Match string to indicate a db archive
DB_ARCHIVE_MATCH='db'
# Ghost files location
GHOST_LOCATION='/var/lib/ghost'

# Restore the database from the given archive file
restoreDB () {
	RESTORE_FILE=$1
	echo "restoring data from mysql dump file: $RESTORE_FILE"
	gunzip < $RESTORE_FILE | mysql -u$MYSQL_ENV_MYSQL_USER -p $MYSQL_ENV_MYSQL_DATABASE -p$MYSQL_ENV_MYSQL_ROOT_PASSWORD -h mysql 
	echo "restore complete"
}

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
				if [[ $choice =~ .*$DB_ARCHIVE_MATCH.* ]]
				then
					restoreDB $choice
				elif [[ $choice =~ .*$GHOST_ARCHIVE_MATCH.* ]]
				then
					restoreGhost $choice
				else
					echo "unrecognised format - the file should be either a ghost files or db archive"
				fi
	          ;;
	  esac
	done
}

while getopts "i" opt; do
	case $opt in
		i)
			chooseFile
			;;
	esac
done



