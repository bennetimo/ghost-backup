FROM debian:jessie

MAINTAINER Tim Bennett

RUN \
  apt-get update && \
  apt-get install -y mysql-client cron

# Default location for storing backups
ENV BACKUP_LOCATION "/backups"

RUN mkdir $BACKUP_LOCATION

VOLUME $BACKUP_LOCATION

# Add the backup/restore scripts
COPY backup.sh /bin/ghost-backup
COPY restore.sh /bin/ghost-restore
RUN chmod +x /bin/ghost-backup
RUN chmod +x /bin/ghost-restore

CMD "true"
