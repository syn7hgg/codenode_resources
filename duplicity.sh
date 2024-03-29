#!/bin/bash

# The S3 destination followed by bucket name
DEST="s3://s3.us-central-1.wasabisys.com//codenode-game/"

# Set up some variables for logging
LOGFILE="/var/log/duplicity/backup.log"
DAILYLOGFILE="/var/log/duplicity/backup.daily.log"
FULLBACKLOGFILE="/var/log/duplicity/backup.full.log"
HOST=`hostname`
DATE=`date +%Y-%m-%d`
MAILADDR="andres@codenode.gg"
TODAY=$(date +%d%m%Y)

is_running=$(ps -ef | grep duplicity  | grep python | wc -l)

if [ ! -d /var/log/duplicity ];then
    mkdir -p /var/log/duplicity
fi

if [ ! -f $FULLBACKLOGFILE ]; then
    touch $FULLBACKLOGFILE
fi

if [ $is_running -eq 0 ]; then
    # Clear the old daily log file
    cat /dev/null > ${DAILYLOGFILE}

    # Trace function for logging, don't change this
    trace () {
            stamp=`date +%Y-%m-%d_%H:%M:%S`
            echo "$stamp: $*" >> ${DAILYLOGFILE}
    }

    # How long to keep backups for
    OLDER_THAN="3D"

    # The source of your backup
    SOURCE=/var/lib/pterodactyl/volumes/

    FULL=
    tail -1 ${FULLBACKLOGFILE} | grep ${TODAY} > /dev/null
    if [ $? -ne 0 -a $(date +%d) -eq 1 ]; then
            FULL=full
    fi;

    trace "------------------------------------"
    trace "Backup for game servers started"

    trace "... removing old backups"

    duplicity remove-older-than ${OLDER_THAN} ${DEST} >> ${DAILYLOGFILE} 2>&1

    trace "... backing up files"

    duplicity ${FULL} ${SOURCE} ${DEST} >> ${DAILYLOGFILE} 2>&1

    trace "Backup for game servers complete"
    trace "------------------------------------"

    # Send the daily log file by email
    #cat "$DAILYLOGFILE" | mail -s "Duplicity Backup Log for $HOST - $DATE" $MAILADDR
    BACKUPSTATUS=`cat "$DAILYLOGFILE" | grep Errors | awk '{ print $2 }'`
    if [ "$BACKUPSTATUS" != "0" ]; then
       cat "$DAILYLOGFILE" | mail -s "Duplicity Backup Log for $HOST - $DATE" $MAILADDR
    elif [ "$FULL" = "full" ]; then
        echo "$(date +%d%m%Y_%T) Full Back Done" >> $FULLBACKLOGFILE
    fi

    # Append the daily log file to the main log file
    cat "$DAILYLOGFILE" >> $LOGFILE
fi