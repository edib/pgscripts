<?php
if ($argc < 4):
  echo "
  #===============================================================================
  #
  #          FILE:  pgbackrest_check.php
  #
  #         USAGE:  php ./pgbackrest_check.php DATABASEHOST STANZA [time|wal|okcheck|label]
  #
  #   DESCRIPTION: This script is to check pgbackrest stanza information and is designed to be used in Zabbix agent UserParameter and can be used externally.
  #                 Zabbix integration documentation is not included.
  #
  #       OPTIONS:
  #  REQUIREMENTS: 1. This script must run on pgbackrest server.
  #                2. System must have php-cli, php-pgsql and must access to the pgsql databases on which the arcive commands run.
  #          BUGS:  ---
  #         NOTES: Script gets the different information about each stanza. For each information script must run again.
  #                1st parameter is the host that postgres database runs on.
  #                2nd param is your stanza name and
  #                3rd parameter is one of the followings:
  #                time : how many seconds late the backup is.
  #                wal: how many wal files late the backup is.
  #                okcheck: whether the backup is in failed state.
  #                label: it is intended for zabbix usage to create a trigger and check daily backup success.
  #        AUTHOR:  ibrahim edib kökdemir, kokdemir@gmail.com
  #       COMPANY:  Tübitak YTE
  #       VERSION:  1.0
  #       CREATED:  2018-02-28 17:24:00 +03
  #      REVISION:  2019-03-11 18:19:53 +03
  #===============================================================================
  ";
  exit;
endif;

// return all backups and convert to an object
# for testing purposes
//$pgb_info = json_decode(file_get_contents("pgbackrest.json"));
$pgb_info = json_decode(shell_exec('pgbackrest info --stanza '.$argv[2].' --output json'));

//last backup object
$last_backup = end($pgb_info[0]->backup);

$myPDO = new PDO('pgsql:host='.$argv[1].';dbname=postgres', 'postgres', 'postgres');

$archive_result = $myPDO->query("select last_failed_wal, extract(EPOCH from (now()-last_archived_time)) archive_time_diff, last_archived_wal from pg_stat_archiver");

$archiver_array = $archive_result->fetch(PDO::FETCH_ASSOC);

switch ($argv[3]) {
    case "time":
      # delay wal archive as seconds
      # check now - last wal time
      echo $archiver_array['archive_time_diff'];
      break;
    case "wal":
      # delay as # of archived wal files
      # check in flushed xlog
      $pg_version = $myPDO->query("show server_version_num");
      // find the server version according to which wal query changes.
      $pg_version = $pg_version->fetch(PDO::FETCH_ASSOC);
      // if the version is 10 or more
      if ( $pg_version['server_version_num'] > 100000 ):
        $last_flushed_wal = $myPDO->query("SELECT pg_walfile_name(pg_current_wal_flush_lsn()) pg_current_wal_flush_lsn");
      // if the version is less than 10
      else:
        $last_flushed_wal = $myPDO->query("SELECT pg_xlogfile_name(pg_current_xlog_flush_location()) pg_current_wal_flush_lsn");
      endif;

      $last_backrest_wal = hexdec(substr($pgb_info[0]->archive[0]->max,16,23));
      $last_archive_wal = hexdec(substr($last_flushed_wal->fetch(PDO::FETCH_ASSOC)['pg_current_wal_flush_lsn'],16,23));
      $archive_wal_diff = $last_archive_wal-$last_backrest_wal;
      echo $archive_wal_diff;
      break;
    case "okcheck":
      # this part checks whether archive_command is failed.
      $last_failed_wal = hexdec(substr($archiver_array['last_failed_wal'],16,23));
      $last_archived_wal = hexdec(substr($archiver_array['last_archived_wal'],16,23));
      if ($last_archived_wal <= $last_failed_wal):
        echo 0;
      else:
        echo 1;
      endif;
      break;
    case "label":
      // to check daily backup succeed. this value is only meaningful when compared with previous checked value.
      echo $last_backup->label;
      break;
    }
