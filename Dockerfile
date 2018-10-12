FROM debian:stretch

MAINTAINER Tim Bennett

RUN \
  apt-get update && \
  apt-get install -y mysql-client cron sqlite3 curl jq netcat

# -----------------------
# Default configuration
# -----------------------

# Location for storing backup archives
ENV BACKUP_LOCATION "/backups"

# Number of recent backups to retain (one backup = one db archive and one files archive)
ENV BACKUPS_RETAIN_LIMIT 30

# Location of backup log (written after each automated backup)
ENV LOG_LOCATION "/var/log/ghost-backup.log"

# Backup daily at 3am
ENV BACKUP_TIME 0 3 * * *

# Whether to install the crontab or not
ENV AUTOMATED_BACKUPS true

# Ghost files location
ENV GHOST_LOCATION "/var/lib/ghost"

# Prefix to put before all backed up files and archives
ENV BACKUP_FILE_PREFIX="backup"

# Service name to expect for mysql connections (if applicable). If you're using ghost-backup with
# a mysql/mariadb database then your db service must be available on the network using this name
ENV MYSQL_SERVICE_NAME="mysql"

# Service port for mysql connections (if applicable)
ENV MYSQL_SERVICE_PORT=3306

# Name of sqlite database (if applicable)
ENV SQLITE_DB_NAME="ghost.db"

# The client slug used to auth with the api to import/export the json file
ENV CLIENT_SLUG="ghost-backup"

# Service name to expect for ghost connections. If using json file backup/restore then your ghost service must be
# available on the network at this address
ENV GHOST_SERVICE_NAME="ghost"

# Service port for ghost connections (if applicable)
ENV GHOST_SERVICE_PORT="2368"

# -----------------------

RUN mkdir $BACKUP_LOCATION

VOLUME $BACKUP_LOCATION

# Setup the entrypoint script for initiating the crontab
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Add the backup/restore scripts
COPY backup.sh /bin/backup
COPY restore.sh /bin/restore
COPY common.sh /bin/common.sh
RUN chmod +x /bin/backup
RUN chmod +x /bin/restore

# Clean up
RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

ENTRYPOINT ["/entrypoint.sh"]

# Run cron and continually watch the ghost backup log file
CMD ["sh", "-c", "touch $LOG_LOCATION && cron && tail -F $LOG_LOCATION"]
