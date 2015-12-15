FROM debian:jessie

MAINTAINER Tim Bennett

RUN \
  apt-get update && \
  apt-get install -y mysql-client cron sqlite3

# Default location for storing backups
ENV BACKUP_LOCATION "/backups"

# Default number of complete backups to retain (one backup = one db archive and one files archive)
ENV BACKUPS_RETAIN_LIMIT 10

# Default location for the log file
ENV LOG_LOCATION "/var/log/ghost-backup.log"

RUN mkdir $BACKUP_LOCATION

VOLUME $BACKUP_LOCATION

# By default, create a backup once a day at 3am
ENV BACKUP_TIME 0 3 * * *

# Setup the entrypoint script for initiating the crontab
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Add the backup/restore scripts
COPY backup.sh /bin/ghost-backup
COPY restore.sh /bin/ghost-restore
RUN chmod +x /bin/ghost-backup
RUN chmod +x /bin/ghost-restore

ENTRYPOINT ["/entrypoint.sh"]

#To workaround tail -F behavior (which says "has been replaced with a remote file. giving up on this name"), create and truncate log file on start up
CMD ["sh", "-c", "cron && truncate -s0 $LOG_LOCATION; tail -n0 -F $LOG_LOCATION"]
