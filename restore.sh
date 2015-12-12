#!/bin/bash

restore () {
	RESTORE_FILE=$1
	echo "restoring data from mysql dump file $RESTORE_FILE"
	gunzip < $RESTORE_FILE | mysql -u$MYSQL_ENV_MYSQL_USER -p $MYSQL_ENV_MYSQL_DATABASE -p$MYSQL_ENV_MYSQL_ROOT_PASSWORD -h mysql 
	echo "restore complete"
}

echo "Select file to restore"

PS3="Restore #: "

select FILENAME in $BACKUP_LOCATION/*;
do
  case $FILENAME in
        *)
          echo "You picked $FILENAME"
          restore $FILENAME
          break;
          ;;
  esac
done

