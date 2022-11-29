FROM debian:bullseye

LABEL org.opencontainers.image.authors="Tim Bennett"

# Set workdir for npm: https://stackoverflow.com/questions/57534295/npm-err-tracker-idealtree-already-exists-while-creating-the-docker-image-for
WORKDIR /usr/app

RUN \
  apt-get update && \
  apt-get install -y --no-install-recommends wget cron sqlite3 curl jq netcat mariadb-client && \
  apt-get clean && \
  rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

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

# Service name to expect for ghost connections. If using json file backup/restore then your ghost service must be
# available on the network at this address
ENV GHOST_SERVICE_NAME="ghost"

# Service port for ghost connections (if applicable)
ENV GHOST_SERVICE_PORT="2368"

# File which stores retrieved ghost session cookie for accessing the api
ENV GHOST_COOKIE_FILE="/tmp/ghost-cookie.txt"

# Name of the ghost session cookie expected
ENV GHOST_ADMIN_COOKIE_NAME="ghost-admin-api-session"

# Set to false to disable compressing DB dumps
ENV COMPRESS_DB_DUMP=true

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

# Create user scripts folder
RUN mkdir /bin/user

ENTRYPOINT ["/entrypoint.sh"]

# Run cron and continually watch the ghost backup log file
CMD ["sh", "-c", "touch $LOG_LOCATION && cron && tail -F $LOG_LOCATION"]
