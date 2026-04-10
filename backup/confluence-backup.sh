#!/bin/bash
Date=$(date +%d-%m-%y)
CH="/var/atlassian/application-data/confluence/"
Url="https://api.telegram.org/bot<TELEGRAM_BOT_TOKEN>/sendMessage"

cd /mnt/backup || exit 1

rsync -aqzhS --delete \
    --include 'attachments/***' \
    --include 'index/***' \
    --include 'confluence.cfg.xml' \
    --exclude '*' \
    $CH ./rsync/

for f in confluence visit; do

    mysqldump --single-transaction --routines --triggers $f | gzip -9 > ./${f}.gz

    if scp -q ./${f}.gz <BACKUP_HOST_1>:<BACKUP_HOST_1_PATH>/${Date}_${f}.gz ; then

        ssh <BACKUP_HOST_1> "cd <BACKUP_HOST_1_PATH> && rm -f \$(ls -t1 *${f}.gz | tail -n +5)"

        Filelist=$(ssh <BACKUP_HOST_1> "cd <BACKUP_HOST_1_PATH> && ls -1 *${f}.gz")

        curl -s -X POST $Url -d chat_id=<TELEGRAM_CHAT_ID> -d text="$f files on backup host: $Filelist" > /dev/null

    fi

    if scp -q -i /root/.ssh/oracle ./${f}.gz ubuntu@<ORACLE_HOST>:/mnt/oradisk/${Date}_${f}.gz ; then

        ssh -i /root/.ssh/oracle ubuntu@<ORACLE_HOST> "cd /mnt/oradisk && rm -f \$(ls -t1 *${f}.gz | tail -n +5)"

        Filelist=$(ssh -i /root/.ssh/oracle ubuntu@<ORACLE_HOST> "cd /mnt/oradisk && ls -1 *${f}.gz")

        curl -s -X POST $Url -d chat_id=<TELEGRAM_CHAT_ID> -d text="$f files on Oracle: $Filelist" > /dev/null

    fi

done
