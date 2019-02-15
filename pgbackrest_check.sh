#!/bin/bash
if [ $# -lt 2 ]
  then
    
    cat <<HELP_USAGE
#===============================================================================
#
#          FILE:  pgbackrest_check.sh
#
#         USAGE:  ./pgbackrest_check.sh YOUR_STANZA_NAME [time|wal|okcheck]
#
#   DESCRIPTION: This script is to check pgbackrest stanza information and is designed to be used in Zabbix agent UserParameter and can be used externally. Zabbix side docs is not included.
#
#       OPTIONS:  
#  REQUIREMENTS: 1. This script must run on pgbackrest server. 
#                2. System must have psql client and must access to the pgsql databases on which the arcive commands run.
#          BUGS:  ---
#         NOTES: 1. Script gets the 3 different information about each stanza. For each information script must run again. 
#                2. 1st param must be your stanza namze and 2nd parameter must be one of time, wal and ok words.
#                3. time : how many seconds late the backup is. 
#                4. wal: how many wal files late the backup is.
#                5. okcheck: whether the backup is in failed state.
#        AUTHOR:  ibrahim edib kökdemir, kokdemir@gmail.com
#       COMPANY:  Tübitak YTE
#       VERSION:  0.7
#       CREATED:  02/28/2018 5:24 PM GMT+3
#      REVISION:  02/13/2019 18:50 PM GMT+3
#===============================================================================
HELP_USAGE
    return 1
fi

declare -A HOSTMAP=( \
    [stanza1]=host1 \
    [stanza2]=host2 \
    [stanza3]=host3 \
    )

HOST=${HOSTMAP[$1]}

if [ -z ${HOST} ]; then
  echo "The stanza name you declared is not in the stanza list."
  return 1 ;
fi

STANZA=$1
USER=""
# the password can also be declared in .pgpass file.
export PGPASSWORD=""

CONN_STR="-qAtX -h $HOST -U $USER postgres"
IFS='|' read -r -a archiver_array <<< `psql $CONN_STR -tAc "select last_failed_wal, extract(EPOCH from (now()-last_archived_time)), last_archived_wal from pg_stat_archiver;"`
returncode=$?; 
if [[ $returncode != 0 ]]; then 

  last_failed_wal=${archiver_array[0]}
  archive_time_diff=${archiver_array[1]}
  last_archive_wal=${archiver_array[2]}
  case $2 in
        time)
          # check now - last wal time
          echo $archive_time_diff;;
        wal)
          # wall difference
          # check in pgbackrest
          last_backrest_wal=`pgbackrest --stanza $STANZA info | grep "wal archive min/max" | awk '{ print $NF }'`
          # check in flushed xlog
          pg_version=`psql $CONN_STR -c "show server_version_num;"`
          if [ $pg_version -ge 10000 ]; then
            last_flushed_wal=`psql $CONN_STR -c "SELECT pg_walfile_name(pg_current_wal_flush_lsn());"`
          else
            last_flushed_wal=`psql $CONN_STR -c "SELECT pg_xlogfile_name(pg_current_xlog_flush_location());"`
          fi
          last_archive_wal=$((16#${last_flushed_wal:16:23}))
          last_backrest_wal=$((16#${last_backrest_wal:16:23}))
          archive_wal_diff=$((last_archive_wal-last_backrest_wal))
          echo $archive_wal_diff;;
        okcheck)
          if [[ $last_archive_wal == $last_failed_wal ]]; then
            echo 0
          else
            echo 1
          fi
          ;;
          *)
            echo "method not defined!"
            return 1;;
  esac
fi