#!/bin/bash


backups=($(pgbackrest info | grep -E '[full|diff|incr] backup' | awk -F ': ' '{ print $2}'))


title="Select Backup Set to Restore"
prompt="Pick a Backup:"

echo "$title"
PS3="$prompt "
select set in "${backups[@]}" "Quit"; do
    case "$REPLY" in
    $(( ${#backups[@]}+1 )) ) echo "Goodbye!"; break;;
    *) echo "You  choose $set ";break;;
    esac
done


if [[ -z $set ]]; then
        echo "need backup set"
        exit 1
fi


read -p "Pick a time after the backup time (i.e: `date +'%Y-%m-%d %H:%M:%S'` ): " time

if [[ -z $time ]]; then
        echo "need restore time"
        exit 1
fi

echo "Set ${set} and time ${time}"
sleep 3

/usr/pgsql-11/bin/pg_ctl -D /var/lib/pgsql/11/data3 stop
rm -rf /var/lib/pgsql/11/data3
mkdir /var/lib/pgsql/11/data3
chmod -R 700 /var/lib/pgsql/11/data3
pgbackrest --stanza=data \
       --log-level-console=detail restore \
       --type=time "--target=${time}" \
       --set=${set} \
       --pg1-path /var/lib/pgsql/11/data3


echo "port=5444" >> /var/lib/pgsql/11/data3/postgresql.auto.conf
echo "#archive_command=" >> /var/lib/pgsql/11/data3/postgresql.auto.conf
echo "#archive_mode=" >> /var/lib/pgsql/11/data3/postgresql.auto.conf
/usr/pgsql-11/bin/pg_ctl -D /var/lib/pgsql/11/data3 start
