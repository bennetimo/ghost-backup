FROM debian:jessie

MAINTAINER Tim Bennett

RUN \
  apt-get update && \
  apt-get install -y mysql-client cron sqlite3

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

# -----------------------

RUN mkdir $BACKUP_LOCATION

VOLUME $BACKUP_LOCATION

# Setup the entrypoint script for initiating the crontab
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Add the backup/restore scripts
COPY backup.sh /bin/backup
COPY restore.sh /bin/restore
RUN chmod +x /bin/backup
RUN chmod +x /bin/restore

# Clean up
RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

ENTRYPOINT ["/entrypoint.sh"]

#To workaround tail -F behavior (which says "has been replaced with a remote file. giving up on this name"), create and truncate log file on start up
CMD ["sh", "-c", "cron && truncate -s0 $LOG_LOCATION; tail -n0 -F $LOG_LOCATION"]
