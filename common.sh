#!/bin/bash

# Sourced by ghost-backup backup and restore

# Match string to indicate a db archive
DB_ARCHIVE_MATCH="${BACKUP_FILE_PREFIX}.*db.*gz"
# Match string to indicate a ghost archive
GHOST_ARCHIVE_MATCH="${BACKUP_FILE_PREFIX}.*ghost.*tar"
# Match string to indicate a ghost json export file
GHOST_JSON_FILE_MATCH="${BACKUP_FILE_PREFIX}.*ghost.*json"

NOW=`date '+%Y%m%d-%H%M'`

# Initially set to false before being tested
MYSQL_CONTAINER_LINKED=false
GHOST_CONTAINER_LINKED=false

# Simple log, write to stdout
log () {
    echo "`date -u`: $1" | tee -a $LOG_LOCATION
}

# Check if we have a mysql container on the network to use (instead of sqlite)
checkMysqlAvailable () {
    log "Checking if a mysql container exists on the network at $MYSQL_SERVICE_NAME:$MYSQL_SERVICE_PORT"

    if nc -z $MYSQL_SERVICE_NAME $MYSQL_SERVICE_PORT > /dev/null 2>&1 ; then
        MYSQL_CONTAINER_LINKED=true
        log " ...a mysql container exists on the network. Using mysql mode"

        # Check the appropriate env vars needed for mysql have been set
        if [ -z "$MYSQL_USER" ]; then log "Error: MYSQL_USER not set. Make sure it's set for your ghost-backup container?"; log "Finished: FAILURE"; exit 1; fi
        if [ -z "$MYSQL_DATABASE" ]; then log "Error: MYSQL_DATABASE not set. Make sure it's set for your ghost-backup container?"; log "Finished: FAILURE"; exit 1; fi
        if [ -z "$MYSQL_PASSWORD" ]; then log "Error: MYSQL_PASSWORD not set. Make sure it's set for your ghost-backup container?"; log "Finished: FAILURE"; exit 1; fi

    else
        log " ...no mysql container exists on the network. Using sqlite mode"
    fi
}

# Check if we have a ghost on the network to use for json file backup/restore
checkGhostAvailable () {
    log " ...checking if a ghost container exists on the network at $GHOST_SERVICE_NAME:$GHOST_SERVICE_PORT"

    if nc -z $GHOST_SERVICE_NAME $GHOST_SERVICE_PORT > /dev/null 2>&1 ; then
        GHOST_CONTAINER_LINKED=true
        log " ...found ghost service on the network"
    else
        log " ...no ghost service found on the network"
    fi
}

createGhostAdminCookie () {
    # Create a valid session cookie so that we can call the db api (see here for more info: https://ghost.org/docs/admin-api/#user-authentication)
    log " ...Retrieving ghost session cookie for user $GHOST_SERVICE_USER_EMAIL"

    if [ -z "$GHOST_COOKIE_FILE" ]; then log "Error: GHOST_COOKIE_FILE not set. Must be the name of the ghost admin session cookie"; log "Finished: FAILURE"; exit 1; fi

    curl --silent -c $GHOST_COOKIE_FILE \
        -d "username=$GHOST_SERVICE_USER_EMAIL&password=$GHOST_SERVICE_USER_PASSWORD" \
        -H "Origin: https://$GHOST_SERVICE_NAME" \
        "$GHOST_SERVICE_NAME:$GHOST_SERVICE_PORT/ghost/api/v3/admin/session/"

    if ! grep -q "$GHOST_ADMIN_COOKIE_NAME" "$GHOST_COOKIE_FILE"; then log "Error: Unable to create a admin session cookie. Check all your credentials are correct"; log "Finished: FAILURE"; exit 1; fi
}

checkGhostAdminCookie () {
    if ! grep -q "$GHOST_ADMIN_COOKIE_NAME" "$GHOST_COOKIE_FILE"; then log "Error: Unable to find a retrieved admin cookie named $GHOST_ADMIN_COOKIE_NAME in file $GHOST_COOKIE_FILE"; log "Finished: FAILURE"; exit 1; fi
}

# Run before both the backup and restore scripts
checkMysqlAvailable
createGhostAdminCookie