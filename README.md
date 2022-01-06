# ghost-backup

ghost-backup is a simple, automated, backup (and restore) [Docker] container for a [Ghost] blog. It supports Ghost configured with either sqlite or mysql/[mariadb].

The current version is designed for use with Ghost 4.x.

ghost-backup can:

 * Take a full backup of your ghost blog with a single `backup` command
   * Database backup (mysql or mariadb)
   * Content files backup (images, themes etc)
   * Json file backup (retrieved by accessing the export feature of the ghost api)
 * Automate backups according to any arbitrary schedule (via cron)
 * Allow restore of files selectively and interactively
 * Be extensively customised

By default it will create a backup of your ghost content directory (images, themes, apps etc), the database 
(actual posts), and the exported json file daily at 3am, keeping the most recent 30 backups of each.

When using sqlite, the db backup/restore is handled using the [command line shell] of the [online backup API]. 
For mysql/mariadb, it uses [mysqldump](https://dev.mysql.com/doc/refman/5.5/en/mysqldump.html).

### Quick Start (Ghost using sqlite)
Ghost uses sqlite by default if you have not changed the [configuration](https://docs.ghost.org/docs/config) to mysql.

Create and run the ghost-backup container with the volumes from your Ghost data container:

`docker run --name ghost-backup -d --volumes-from <your-ghost-container> bennetimo/ghost-backup`

Where:

`<your-ghost-container>` is either your Ghost blog container, or a separate data-only container/[volume] holding your blog files. Basically, wherever your blog content lives.

That's it! This will create and run a container named 'ghost-backup' which will create a backup of your Ghost database and content files under `/backups` inside the `ghost-backup` container every day at 3am.

> If you want json file backup also, a few more options are required

The below sections walk through customizing the backup.

### Quick Start (Ghost using mysql/mariadb)

If your Ghost [configuration](https://docs.ghost.org/docs/config) is using mysql/mariadb then you just need to start the ghost-backup
container on the same [network] as your database container, so that it can talk to your database.  

```
docker run --name ghost-backup -d \
    --volumes-from <your-ghost-container> \
    --network=<your network> \
    -e MYSQL_USER=<yourdbuser> \
    -e MYSQL_PASSWORD=<yourdbpassword> \
    -e MYSQL_DATABASE=<yourdatabase> \
    bennetimo/ghost-backup
```

Where:
  * `<your-ghost-container>` is as above
  * `<your-network>` is a network that your database container is connected to. It should be accessible using the hostname 'mysql' which you can set with [--network-alias]
  * MYSQL_ vars are the details needed to access your database 
 
> This could also be setup via [container links], but this feature is now considered legacy and deprecated.

### Configuring the backup location

By default, the backups will live in `/backups` inside the `ghost-backup` container. You can verify they're 
there with `docker exec ghost-backup ls /backups`. 

To mount the backups directory somewhere on the host add:
`-v </backup/folder/on/host>:/backups` to your docker run command.

To use [docker volumes](https://docs.docker.com/storage/volumes/), first create the volume, then attach it to both the ghost container 
and backup container. See the bottom of this readme for an example docker-compose
configuration using volumes.

> To change the backups folder used in the container set the env var: BACKUP_LOCATION=/your/new/location

### Ghost json file backup/restore setup

Ghost labs has had a feature to [export your blog content](https://ghost.org/help/the-importer/) as a single json file for a long time. 

There is a similar feature to import a json file. 

> If you import a json file twice, all posts will be duplicated. The API does not seem to currently filter out duplicate posts so be careful

To use the json api, ghost-backup needs to authenticate and obtain a [session cookie](https://ghost.org/docs/admin-api/#user-authentication), and needs to be able to communicate with your ghost service.

You need to configure the following additional environment variables, so that a session cookie can be retrieved:
 
 * GHOST_SERVICE_USER_EMAIL # The email address of a user configured in your ghost installation (N.B. this should be uri encoded, e.g. my-email.%40example.com) 
 * GHOST_SERVICE_USER_PASSWORD # The password for that user
 
 > A good idea would be to create a new user in your ghost admin panel specifically for ghost-backup and use those credentials here

ghost-backup expects to be able to communicate with your ghost service via the hostname `ghost` using the
default port of `2368`. If you need to override these, you can override the env vars:

 * GHOST_SERVICE_NAME 
 * GHOST_SERVICE_PORT

A full configuration with support for json import/export might look like this:

```
docker run --name ghost-backup -d \
    --volumes-from <your-ghost-container> \
    --network=<your-network> \
    -e MYSQL_USER=<yourdbuser> \
    -e MYSQL_PASSWORD=<yourdbpassword> \
    -e MYSQL_DATABASE=<yourdatabase> \
    -e GHOST_SERVICE_USER_EMAIL=<my-email.%40emample.com> \
    -e GHOST_SERVICE_USER_PASSWORD=<mypassword> \
    bennetimo/ghost-backup
```

> Note the APIs used to export and import the json are undocumented. ghost-backup uses the same api that is used when you initiate an export/import through the 
admin interface of your ghost blog.

### Perform a manual backup
`docker exec ghost-backup backup`

This will create an immediate backup. You should now have backup files created in the backup folder (`/backups` by default). 
One archive is the database, one the archive of your content files, and if configured also a json export of your ghost blog.

>Note that backups are tagged with the date and time in the form yyyymmdd-hhmm, therefore if two backups are created in the same minute then the second will overwrite the first.

### Restore a backup
A backup is no good if it can't be restored :) You can do that in three ways:

> N.B. After a database restore you will likely need to restart your ghost blog container to see the changes

#### Interactive restore
You can launch an interactive backup menu using:
`docker exec -it ghost-backup restore -i`
This will display a menu with all of the available backup files. You can select which to restore by number or name. 

> Using interactive backup you can restore a DB archive separately to a Ghost files archive

#### By date restore
You can also restore by date:

`docker exec ghost-backup restore -d yyyymmdd-hhmm`
This will restore the backup files from yyyymmdd-hhmm, if found. 

> Date restore expects to find both a db and content files archive for the corresponding date, or will stop.
If you want to restore just one of the other (or a json file), use either file restore or interactive restore

#### By file restore
You can restore a given file mounted to the container:

`docker exec ghost-backup restore -f /path/to/file/filename`

> N.B. Be sure to use fully qualified path names when restoring a single file

#### In place restore
By default the restore script will remove the ghost files from `GHOST_LOCATION/content` before restoring the archive, except for the database which is handled separately. 

To restore without removing files first you can specify the command argument capitalised, e.g. `-I, -D, -F`.

#### Matching files to restore

ghost-backup uses the following matches to determine whether a file to restore is a db archive, content archive, or json file:

```
DB_ARCHIVE_MATCH="${BACKUP_FILE_PREFIX}.*db.*gz"
GHOST_ARCHIVE_MATCH="${BACKUP_FILE_PREFIX}.*ghost.*tar"
GHOST_JSON_FILE_MATCH="${BACKUP_FILE_PREFIX}.*ghost.*json"
```

If you rename your backup files, they must match these patterns to be able to restore.

### Advanced Configuration
ghost-backup has a number of options which can be configured as you need. 

| Environment Variable  | Default       | Meaning           |
| --------------------- | ------------- | ----------------- | 
| BACKUP_TIME           | 0 3 * * *   | A [cron expression] controlling the backup schedule.|
| BACKUP_LOCATION       | /backups    | Where the backups are written to|
| BACKUPS_RETAIN_LIMIT  | 30            | How many backups to keep. Oldest are removed first|
| LOG_LOCATION          | /var/log/ghost-backup.log | Location of the log file |
| AUTOMATED_BACKUPS     | true             | Whether scheduled backups are on |
| GHOST_LOCATION		| /var/lib/ghost/content | Location of ghost content and db files |
| BACKUP_FILE_PREFIX    | backup | Prefix for all created backup files |
| MYSQL_SERVICE_NAME    | mysql | Hostname  of mysql container (if applicable) |
| MYSQL_SERVICE_PORT    | 3306 | Port of mysql container (if applicable) |
| SQLITE_DB_NAME        | ghost.db      | Name of sqlite database (if applicable) |
| CLIENT_SLUG           | ghost-backup  | client used for authenticating with the ghost json api |
| GHOST_SERVICE_NAME    | ghost         | Hostname of ghost container (if applicable) |
| GHOST_SERVICE_PORT    | 2368          | Port of ghost container   |


For example, if you wanted to backup at 2AM to the location /some/dir/backups, storing 10 days of backups you would use:

```
docker run --name ghost-backup -d \
        --volumes-from <your-data-container> \
        -e "BACKUP_LOCATION=/some/dir/backups" \
        -e "BACKUP_TIME=0 2 * * *" \
        -e "BACKUPS_RETAIN_LIMIT=10" \
         bennetimo/ghost-backup
```

> This example is for Ghost using sqlite. If you're using mysql/mariadb just add the linked mysql containers as described above.

#### Disable backup types

By default, the backup will have a Ghost content files archive, a DB archive, an exported json file 
(if connected to your ghost service) and purge any excess old backups specified by the `BACKUPS_RETAIN_LIMIT`.
Each of these can be disabled with command arguments:

 * -D //Do not include a DB archive
 * -F //Do not include a ghost content files archive
 * -J //Do not include a ghost json file export
 * -P //Do not purge old files

For example to perform a backup of just the DB with no purge:

`docker exec ghost-backup backup -FJP`

### Backup to Dropbox
You can configure the backup location as you wish, which if used in conjunction with [bennetimo/docker-dropbox] will backup to a [Dropbox] folder.

To do this, you need to have a dropbox container running, linked to your account:
`docker run -d --name dropbox bennetimo/docker-dropbox`

> You need to link this container to your Dropbox account first, see [docker-dropbox quickstart]

Then create your backup container using the Dropbox volume:
```
docker run --name ghost-backup -d \
        --volumes-from <your-ghost-container> \
        --volumes-from <your-dropbox-container> \
        -e "BACKUP_LOCATION=/root/Dropbox" 
        bennetimo/ghost-backup`
```

That's it. Now if your Dropbox container has been linked correctly to your account you'll have a backup of your blog added every day at 3am to your Dropbox. 

### View the logs
`docker logs ghost-backup`
Will display logs of all of backup runs (manual and automated) and restore operations. By default the log file is at: `/var/log/ghost-backup.log`

### Disabling automated backups
If you want to disable automated backups and just perform them manually as necessary, then you can stop the crontab installation by starting your container as:

```
docker run -d --name ghost-backup \
    --volumes-from <your-ghost-container> 
    -e "AUTOMATED_BACKUPS=false" bennetimo/ghost-backup
```

Now you can run:
`docker exec ghost-backup backup`

Every time you want to take a backup. You can restore as normal (described above).

### Using ghost-backup for cloning an environment locally
You can use ghost-backup to create a local test environment for your blog, with all the posts and content. This allows
you to write your posts, tweak your theme and check everything is working locally before cloning it exactly
on your live blog. To do this:

1. Setup your local/dev dockerised ghost blog
2. Setup the ghost-backup container for your local blog as described in this readme, with e.g. Dropbox as the backup location
3. Create a live dockerised blog on your remote server, also with ghost-backup configured to use a suitable backups mount

Now your workflow will be:

1. Write/edit content locally
2. Take a local backup with `docker exec ghost-backup backup`
3. Transfer your backup archives to your remote host (e.g. scp/DropBox) to the mounted backup location
4. On the remote host `docker exec ghost-backup restore -i` and restore your backup files
5. Restart your remote ghost blog to pick up changes

### Example Docker Compose Configuration

Using [docker-compose](https://docs.docker.com/compose/) makes it easy to configure all the requirement components. 

The example configuration below will startup a ghost container, mariadb container and ghost-backup container
all on the same network so that ghost backup can work.

Then:

 1. `docker-compose up`
 1. View your blog at [http://localhost:2368/](http://localhost:2368/)
 1. Take a backup with `docker exec ghost-backup backup`
 
> When first starting up, ghost may try to connect to the mysql container before it is ready for connections generating
a few error messages. After a few tries it will succeed, or to avoid this you can start the mysql container separately first,
or do something else to [control startup order](https://docs.docker.com/compose/startup-order/)

```
version: "3.7"

services:
 # Ghost container
 ghost:
  image: ghost:4
  restart: always
  ports:
   - "2368:2368"
  environment:
   - database__client=mysql
   - database__connection__host=mysql
   - database__connection__database=ghost
   - database__connection__user=yourdbuser
   - database__connection__password=yourdbpassword
  volumes:
  - "data-ghost-content:/var/lib/ghost/content"

 # Database container
 mysql:
  image: mariadb:10.3
  restart: always
  environment:
   - MYSQL_ROOT_PASSWORD=myrootpassword
   - MYSQL_USER=yourdbuser
   - MYSQL_PASSWORD=yourdbpassword
   - MYSQL_DATABASE=ghost
  expose:
  - "3306"
  volumes:
  - "data-ghost-db:/var/lib/mysql"

 # Ghost backup container
 ghost-backup:
  image: bennetimo/ghost-backup:4
  container_name: "ghost-backup"
  environment:
   - MYSQL_USER=yourdbuser
   - MYSQL_PASSWORD=yourdbpassword
   - MYSQL_DATABASE=ghost
  volumes:
  - "data-ghost-content:/var/lib/ghost/content"

# Data volumes containing all the persistent storage for the blog
volumes:
 data-ghost-content:
 data-ghost-db:
```

> N.B. The above is shown as a self contained file for completeness. But, you'd probably want to look at using
[env_files](https://docs.docker.com/compose/environment-variables/#the-env_file-configuration-option) or 
[multiple compose files](https://docs.docker.com/compose/extends/#multiple-compose-files) for better separation

### Versions

Ghost 0.x to 1.x introduced some breaking changes so backups and restores between them are not possible without a little work.

ghost-backup 0.7.3 is an earlier version of this container for ghost 0.x releases.

ghost-backup 1.x is for ghost 1.x releases.

ghost-backup 4.x is for ghost 4.x releases.

#### Migrating between Ghost versions

Follow ghosts [update guide](https://ghost.org/docs/update/).

Database backups generally will *not* be compatible between major versions, as breaking changes are introduced. You may find that the json export from an
older version can be successfully imported into a newer version. 

Content files that used to live under `/var/lib/ghost` in 0.x moved to `/var/lib/ghost/content` in 1.x, as
well as there being a few other changes with config/themes etc.

Always check the Ghost docs for up-to-date information and test your workflow.

### Other Info

This container was inspired by [wordpress-backup]. 

**Disclaimer:** Will not be held responsible for any loss of files/backups arising from your use of this 
container. **Be sure to test your backup/restore process when you first set everything up to make sure it
is all working as you expect.**

 [Docker]: https://www.docker.com/
 [volume]: https://docs.docker.com/storage/volumes/
 [container links]: https://docs.docker.com/network/links/
 [network]: https://docs.docker.com/engine/reference/commandline/network_create/#extended-description
 [--network-alias]: https://docs.docker.com/engine/reference/run/#network-settings
 [Ghost]: https://ghost.org/
 [cron expression]: https://en.wikipedia.org/wiki/Cron#Format
 [Dropbox]: https://www.dropbox.com/
 [bennetimo/docker-dropbox]: https://hub.docker.com/r/bennetimo/docker-dropbox/
 [docker-dropbox quickstart]: https://github.com/bennetimo/docker-dropbox#quick-start
 [mariadb]: https://hub.docker.com/_/mariadb/
 [command line shell]: https://www.sqlite.org/cli.html
 [online backup API]: https://www.sqlite.org/backup.html
 [wordpress-backup]: https://hub.docker.com/r/aveltens/wordpress-backup/
 [client authentication]: https://api.ghost.org/docs/client-authentication

