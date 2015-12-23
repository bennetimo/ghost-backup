# ghost-backup

ghost-backup is a simple, automated, backup (and restore) [Docker] container for a [Ghost] blog. It supports Ghost configured with either sqlite or mysql/[mariadb]. 

By default it will create a backup of the ghost content files (images, themes, apps, config.js) and the database (actual posts) daily at 3am, keeping the most recent 30 backups.

### Quick Start (Ghost using sqlite)
Ghost uses sqlite by default, if you have not changed the [configuration] to mysql.

Create and run the ghost-backup container with the volumes from your Ghost data container:

`docker run --name ghost-backup -d --volumes-from <your-data-container>  bennetimo/ghost-backup`

Where:

`<your-data-container>` is either your Ghost blog container, or a separate data-only container holding your blog files. Basically, wheverever your blog content lives.

That's it! This will create and run a container named 'ghost-backup' which will create a backup of your Ghost database and content files under /backups every day at 3am.

See below sections for customizing the backup.

### Quick Start (Ghost using mysql/mariadb)

If your Ghost [configuration] is using mysql/mariadb then you just need to link in your mysql container when you create the backup container:

`docker run --name ghost-backup -d --volumes-from <your-data-container> --link <your-mysql-container>:mysql bennetimo/ghost-backup`

Where:

`<your-data-container>` is as above
`<your-mysql-container>` is your mysql/mariadb database container for your blog

> The linked mysql container needs to have the alias 'mysql' as shown.

The following environment variables should be set on the mysql container, which is what ghost-backup will use to connect:

 * MYSQL_ENV_MYSQL_USER
 * MYSQL_ENV_MYSQL_PASSWORD
 * MYSQL_ENV_MYSQL_DATABASE

### Perform a manual backup
`docker exec ghost-backup backup`

This will create an immediate backup. You should now have two archives created in the backup folder (/backups by default). One archive is the database, the other the ghost content files.

>Note that backups are are tagged with the date and time in the form yyyymmdd-hhmm, therefore if two backups are created in the same minute then the second will overwrite the first.

### Restore a backup
A backup is no good if it can't be restored :) You can do that in two ways:

#### Interactive restore
You can launch an interactive backup menu using:
`docker exec -it ghost-backup restore -i`
This will display a menu with all of the available backup files. You can select which to restore by number or name. 

> Using interactive backup you can restore a DB archive separately to a Ghost files archive

#### By date restore
You can also restore by date:

`docker exec ghost-backup restore -d <yyyymmdd-hhmm>`
This will restore the backup files (database and content) from yyyymmdd-hhmm, if found. 

### Advanced Configuration
ghost-backup has a number of options which can be configured as you need. 

| Environment Variable  | Default       | Meaning           |
| --------------------- | ------------- | ----------------- | 
| BACKUP_TIME           | "0 3 * * *"   | A [cron expression] controlling the backup schedule.|
| BACKUP_LOCATION       | "/backups"    | Where the backups are written to|
| BACKUPS_RETAIN_LIMIT  | 30            | How many backups to keep. Oldest are removed first|
| LOG_LOCATION          | "/var/log/ghost-backup.log" | Location of the log file |
| GHOST_LOCATION		| "/var/lib/ghost" | Location of ghost content and db files |

For example, if you wanted to backup at 2AM to the location /some/dir/backups, storing 10 days of backups you would use:

`docker run --name ghost-backup -d --volumes-from <your-data-container> -e "BACKUP_LOCATION=/some/dir/backups" -e "BACKUP_TIME=0 2 * * *" -e "BACKUPS_RETAIN_LIMIT=10"  bennetimo/ghost-backup`

> This example is for Ghost using sqlite. If you're using mysql/mariadb just add the linked mysql containers as described above.

### Backup to Dropbox
You can configure the backup location as you wish, which if used in conjunction with [bennetimo/docker-dropbox] will backup to a [Dropbox] folder.

To do this, you need to have a dropbox container running, linked to your account:
`docker run -d --name dropbox bennetimo/docker-dropbox`

> You need to link this container to your Dropbox account first, see [docker-dropbox quickstart]

Then create your backup container using the Dropbox volume:
`docker run --name ghost-backup -d --volumes-from <your-data-container> --volumes-from <your-dropbox-container> -e "BACKUP_LOCATION=/root/Dropbox" bennetimo/ghost-backup`

That's it. Now if your Dropbox container has been linked correctly to your account you'll have a backup of your blog added every day at 3am to your Dropbox. 

### View the logs
`docker logs ghost-backup`
Will display logs of all of backup runs (manual and automated) and restore operations. By default the log file is at: `/var/log/ghost-backup.log`

### Disabling automated backups
If you want to disable automated backups and just perform them manually as necessary, then you can stop the crontab installation by starting your container as:

`docker run -d --name ghost-backup --volumes-from <your-data-container> -e "AUTOMATED_BACKUPS=false" ghost-backup`

Now you can run:
`docker exec ghost-backup backup`

Every time you want to take a backup. You can restore as normal (described above).

### Using ghost-backup for cloning an environment locally
You can use ghost-backup to create a local test environment for your blog, with all the posts and content. 

1. Setup your dockerised ghost blog
2. Setup the ghost-backup container on your blog as described in this readme, with e.g. Dropbox as the backup location
3. Create a local dockerised ghost blog
4. Link and run the ghost-backup container restore script once to populate your local blog

### Other Info
When using sqlite, the backup/restore is handled using the [command line shell] of the [online backup API].

When using mysql/mariadb, the backup/restore is handled using mysqldump. You should use InnoDB tables for [online backup].

This container was inspired by [wordpress-backup]

 [Docker]: https://www.docker.com/
 [Ghost]: https://ghost.org/
 [cron expression]: https://en.wikipedia.org/wiki/Cron#Format
 [Dropbox]: https://www.dropbox.com/
 [bennetimo/docker-dropbox]: https://hub.docker.com/r/bennetimo/docker-dropbox/
 [docker-dropbox quickstart]: https://github.com/bennetimo/docker-dropbox#quick-start
 [configuration]: http://support.ghost.org/config/#database
 [mariadb]: https://hub.docker.com/_/mariadb/
 [command line shell]: https://www.sqlite.org/cli.html
 [online backup API]: https://www.sqlite.org/backup.html
 [online backup]: https://dev.mysql.com/doc/refman/5.5/en/mysqldump.html
 [wordpress-backup]: https://hub.docker.com/r/aveltens/wordpress-backup/