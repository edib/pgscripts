<?php
//define necessary parameters
define('PARAMS',array(
  'PG_CTL' => "/usr/pgsql-11/bin/pg_ctl",
  'PG_RESTORE_DIR' => "/var/lib/postgresql/11/test",
  'PG_RESTORE_PORT' => "5555",
  'STANZA_NAME' => "test"
));

function validateDate($date, $format = 'd-m-Y H:i:s')
{
    $d = DateTime::createFromFormat($format, $date);
    return $d && $d->format($format) == $date;
}

function timeReadLine($all_backups, $selected) {
  do {
  echo "Select a time to restore, or press enter the default time \n [".date("d-m-Y H:i:s", $all_backups[$selected]->timestamp->stop)."]";
  $selected_time = readline();
  if ($selected_time === ""):
    $selected_time = date("d-m-Y H:i:s", $all_backups[$selected]->timestamp->stop);
  endif;
} while (!validateDate($selected_time));
  return $selected_time;
}


# find the all available backups
$pgb_info = json_decode(shell_exec("pgbackrest info --stanza ".PARAMS['STANZA_NAME']." --output json"));
//$pgb_info = json_decode(file_get_contents("dosya.json"));

$all_backups = $pgb_info[0]->backup;

# show backup list menu
foreach ($all_backups as $key => $backup) {
  $key++;
  print($key." ".$backup->label." [".strtoupper(substr($backup->type,0,1))."] (".date("d M Y H:i:s", $backup->timestamp->stop).")\n");
}

$selected_backup = readline("Select a backup:");

//revert the number to the array key
$selected = $selected_backup - 1;
$backup_set = $all_backups[$selected]->label;
$backup_time = timeReadLine($all_backups, $selected);
echo "Your database will be restored to $backup_set and time $backup_time","\n";
$confirm = readline("Restore will begin. y[es]? CTRL^c to cancel.");
if ($confirm === "y"):
  sleep(2);
  #set pitr params
  $PITR_STRING=" --type time '--target=".$backup_time."'  --set=$backup_set";

  system(PARAMS['PG_CTL']." -D ".PARAMS['PG_RESTORE_DIR']." stop");
  system("rm -rf ".PARAMS['PG_RESTORE_DIR']);
  system("mkdir ".PARAMS['PG_RESTORE_DIR']);
  system("chmod -R 700 ".PARAMS['PG_RESTORE_DIR']);

  system("pgbackrest --stanza=".PARAMS['STANZA_NAME']." --log-level-console=detail restore ".$PITR_STRING." --pg1-path ".PARAMS['PG_RESTORE_DIR']);
  system("echo 'port=".PARAMS['PG_RESTORE_PORT']."' >> ".PARAMS['PG_RESTORE_DIR']."/postgresql.auto.conf");
  system("echo '#archive_command=' >> ".PARAMS['PG_RESTORE_DIR']."/postgresql.auto.conf");
  system("echo '#archive_mode=' >> ".PARAMS['PG_RESTORE_DIR']."/postgresql.auto.conf");
  system(PARAMS['PG_CTL']." -D ".PARAMS['PG_RESTORE_DIR']." start");
else:
  exit;
endif;
