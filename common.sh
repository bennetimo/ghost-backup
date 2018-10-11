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

# Initially client secret is empty
CLIENT_SECRET=
BEARER_TOKEN=

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
        if [ -z "$MYSQL_SERVICE_USER" ]; then log "Error: MYSQL_SERVICE_USER not set. Make sure it's set for your ghost-backup container?"; log "Finished: FAILURE"; exit 1; fi
        if [ -z "$MYSQL_SERVICE_DATABASE" ]; then log "Error: MYSQL_SERVICE_DATABASE not set. Make sure it's set for your ghost-backup container?"; log "Finished: FAILURE"; exit 1; fi
        if [ -z "$MYSQL_SERVICE_PASSWORD" ]; then log "Error: MYSQL_SERVICE_PASSWORD not set. Make sure it's set for your ghost-backup container?"; log "Finished: FAILURE"; exit 1; fi

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

retrieveClientSecret () {
    log " ...retrieving client secret for client: $CLIENT_SLUG"

    sql="select secret from clients where slug='$CLIENT_SLUG'"

    if [ $MYSQL_CONTAINER_LINKED = true ]; then
        CLIENT_SECRET=$(mysql --raw -s -N --host=$MYSQL_SERVICE_NAME  --port=$MYSQL_SERVICE_PORT \
            --user=$MYSQL_SERVICE_USER --password=$MYSQL_SERVICE_PASSWORD --database=$MYSQL_SERVICE_DATABASE -e "$sql")
    else
        CLIENT_SECRET=$(sqlite3 $GHOST_LOCATION/content/data/$SQLITE_DB_NAME "$sql")
    fi

    if [ -z "$CLIENT_SECRET" ]; then log "Error: Unable to retrieve the client secret for $CLIENT_SLUG from the database."; log "Finished: FAILURE"; exit 1; fi
    log " ...retrieved client secret: $CLIENT_SECRET for client slug: $CLIENT_SLUG"
}

retrieveClientBearerToken () {
    # Retrieve a valid bearer token so that we can call the db api (see here for more info: https://api.ghost.org/docs/user-authentication#retrieve-a-bearer-token-via-curl)
    BEARER_TOKEN=$(curl -s \
    -H "Accept: application/json" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -X POST -d "grant_type=password&username=$AUTH_EMAIL&password=$AUTH_PASSWORD&client_id=$CLIENT_SLUG&client_secret=$CLIENT_SECRET" \
    $GHOST_SERVICE_NAME:$GHOST_SERVICE_PORT/ghost/api/v0.1/authentication/token | jq -r .access_token)

    if [ -z "$BEARER_TOKEN" ]; then log "Error: Unable to retrieve an access token for the api. Check all your credentials are correct"; log "Finished: FAILURE"; exit 1; fi
}


# Run before both the backup and restore scripts
checkMysqlAvailable