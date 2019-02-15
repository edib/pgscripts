#!/bin/bash

#===============================================================================
#
#          FILE:  pgbackrest_restore.sh
#
#         USAGE:  ./pgbackrest_restore.sh
#
#   DESCRIPTION: This script is intended to restore pgbackrest stanza to some local directory that predefined in this file. Be careful to set the directory parameters.
#
#       OPTIONS:  
#  REQUIREMENTS: 1. R_PARAM parameters must be set before running the script.
#          BUGS:  ---
#         NOTES: Script has two path:
#                1. PITR: restore to some point in backup history. For that, you must choose backup set that shown in the menu and restore time after that backup set. 
#                2. or you may choose to restore to the latest point.    
#        AUTHOR:  ibrahim edib kökdemir, kokdemir@gmail.com
#       COMPANY:  Tübitak YTE
#       VERSION:  0.1
#       CREATED:  2018-01-29 11:12:45 +03
#      REVISION:  2019-02-15 22:19:07 +03
#===============================================================================

# parameters: these parameters must be set before running the code.

declare -A R_PARAM=( \
        [PG_CTL]="/usr/pgsql-11/bin/pg_ctl"       \
        [PG_RESTORE_DIR]="/var/lib/pgsql/11/data3" \
        [PG_RESTORE_PORT]="5555" \
        [STANZA_NAME]="data" \
    )

for PARAM in "${R_PARAM[@]}"
        do 
                if [ -z $PARAM ]; then
                        echo "All restore parameters must be set !";
                        return 1;
                fi
        done




# find the all backup types
backups=($(pgbackrest info | grep -E '[full|diff|incr] backup' | awk -F ': ' '{ print $2}'))


title="Select Backup Set to Restore"
prompt="Pick a Backup:"

echo "$title"
PS3="$prompt"
select set in "${backups[@]}" "Latest Backup" "Quit"; do
    case "$REPLY" in
    $(( ${#backups[@]}+1 )) ) latest=${#backups[@]}+1; echo "You choose to restore the latest backup!";  break;;
    $(( ${#backups[@]}+2 )) ) echo "Goodbye!"; return 1;;
    *) echo "You  choose $set ";break;;
    esac
done


if [[ -z $set ]]; then
        echo "need backup set"
        return 1
fi

# to restore to a time point
if [ -z $latest ]; then
        read -p "Pick a time after the backup time (i.e: `date +'%Y-%m-%d %H:%M:%S'` ): " time

        if [[ -z $time ]]; then
                echo "need restore time"
                return 1
        fi

echo "Set ${set} and time ${time}"
# just wait to show above
sleep 2

#set pitr params
PITR_STRING=" --type=time "--target=${time}"  --set=${set}"
fi

# for repeated test, you can uncomment below lines 
#${R_PARAM[PG_CTL]} -D ${R_PARAM[PG_RESTORE_DIR]} stop
#rm -rf ${R_PARAM[PG_RESTORE_DIR]}
mkdir ${R_PARAM[PG_RESTORE_DIR]}
chmod -R 700 ${R_PARAM[PG_RESTORE_DIR]}


pgbackrest --stanza=${R_PARAM[STANZA_NAME]} \
       --log-level-console=detail restore \
        $PITR_STRING \
       --pg1-path ${R_PARAM[PG_RESTORE_DIR]}


echo "port=${R_PARAM[PG_RESTORE_PORT]}" >> ${R_PARAM[PG_RESTORE_DIR]}/postgresql.auto.conf
echo "#archive_command=" >> ${R_PARAM[PG_RESTORE_DIR]}/postgresql.auto.conf
echo "#archive_mode=" >> ${R_PARAM[PG_RESTORE_DIR]}/postgresql.auto.conf
${R_PARAM[PG_CTL]} -D ${R_PARAM[PG_RESTORE_DIR]} start
