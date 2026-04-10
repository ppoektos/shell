#!/bin/bash

Date=$(date +%d-%m-%y)
P=$(cat /root/pswd)
ArchiveFull="${Date}_mysql_full.gz"
DB="information_schema mysql lunchorder expenses inv effort"
Hosts="<BACKUP_HOST_1> <NAS_HOST> <ORACLE_HOST>"
Url="https://api.telegram.org/bot<TELEGRAM_BOT_TOKEN>/sendMessage"
TelegramSend=false
Key=

cd /root/backup || exit 1
rm -f ./*mysql_full.gz


copy_archive () {

Source=$1
ToRemove=${Source#*_}

for Host in $Hosts; do

    case $Host in
       <BACKUP_HOST_1>) Path="<BACKUP_HOST_1_PATH>"
       ;;
       <NAS_HOST>) Path="/share/mysql/"
                   Host="admin@$Host"
       ;;
       <ORACLE_HOST>) Path="/mnt/oradisk/"
                      Host="ubuntu@$Host"
                      Key="-i /root/.ssh/oracle"
       ;;
    esac

    if scp -q $Key $Source $Host:$Path ; then

        [[ $TelegramSend = true ]] && curl -s -X POST $Url -d chat_id=<TELEGRAM_CHAT_ID> -d text="$Source added to ${Host#*@}" > /dev/null

        ssh $Key $Host "cd $Path && rm -f \$(ls -t1 *$ToRemove | tail -n +5)"

    fi

done

}

for f in $DB; do

    ArchiveSmall="${Date}_$f.gz"
    mysqldump -u root -p$P --lock-all-tables --routines --triggers --events $f | gzip -q9 > $ArchiveSmall
    copy_archive $ArchiveSmall
    rm -f $ArchiveSmall

done

mysqldump -u root -p$P --lock-all-tables --routines --triggers --events \
-B $DB | gzip -9 > $ArchiveFull

TelegramSend=true

copy_archive $ArchiveFull
