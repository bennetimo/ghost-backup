FROM debian:jessie

MAINTAINER Tim Bennett

RUN \
  apt-get update && \
  apt-get install -y mysql-client cron sqlite3

# Default configuration
ENV BACKUP_LOCATION "/backups"                  # Location for storing backup archives
ENV BACKUPS_RETAIN_LIMIT 30                     # Number of recent backups to retain (one backup = one db archive and one files archive)
ENV LOG_LOCATION "/var/log/ghost-backup.log"    # Location of backup log (written after each automated backup)
ENV BACKUP_TIME 0 3 * * *                       # Backup daily at 3am

RUN mkdir $BACKUP_LOCATION

VOLUME $BACKUP_LOCATION

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
