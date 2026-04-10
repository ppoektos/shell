#!/bin/bash

[[ $(id -u) -eq 0 ]] && exec sudo -H -u <ADMIN_USER> $0

cd /home/<ADMIN_USER> || exit 11

rm -f ./*.gz

Options="--no-defaults --add-drop-database --add-drop-table --complete-insert --users --log-error-file=/home/<ADMIN_USER>/dump_err.log"
Url="https://api.telegram.org/bot<TELEGRAM_BOT_TOKEN>/sendMessage"
Hosts="<BACKUP_HOST_1> <NAS_HOST> <ORACLE_HOST>"
Databases="expenses inventory lunchorder"
SshPath="/home/<ADMIN_USER>/.ssh"
Date=$(date +%d-%m-%y)
TelegramSend=false

copy_archive () {

Source=$1
ToRemove=${Source#*_}

for Host in $Hosts; do

    case $Host in
       <BACKUP_HOST_1>) Path="<BACKUP_HOST_1_PATH>"
                        Host="root@$Host"
                        Key="-i $SshPath/id_dsa"
       ;;
       <NAS_HOST>) Path="/share/mysql/"
                   Host="admin@$Host"
                   Key="-i $SshPath/id_dsa"
       ;;
       <ORACLE_HOST>) Path="/mnt/oradisk/"
                      Host="ubuntu@$Host"
                      Key="-i $SshPath/oracle"
       ;;
    esac

    if scp -q $Key $Source $Host:$Path ; then

        [[ $TelegramSend = true ]] && curl -s -X POST $Url -d chat_id=<TELEGRAM_CHAT_ID> -d text="$Source added to ${Host#*@}" > /dev/null

        ssh $Key $Host "cd $Path && rm -f \$(ls -t1 *$ToRemove | tail -n +5)"

    fi

    sleep 5

done

}


mysql -e "FLUSH TABLES WITH READ LOCK;"

for Database in $Databases; do

    mysqlpump $Options $Database | gzip -q9 > ${Date}_$Database.gz

    copy_archive ${Date}_$Database.gz

done

mysqlpump

gzip -q9 db.sql
mv db.sql.gz ${Date}_mysql2.gz

TelegramSend=true

copy_archive ${Date}_mysql2.gz

mysql -e "UNLOCK TABLES;"
