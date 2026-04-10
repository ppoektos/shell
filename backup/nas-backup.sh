#!/bin/bash
dirs="folder1 folder2 folder3 folder4 folder5 folder6 folder7 \
      folder8 folder9 folder10"

for directory in $dirs; do

    echo Mount $directory

    if mount nas2:$directory /mnt/nas2/ ; then

        echo Doing sync
        rsync -azhS --stats --delete /share/$directory/ /mnt/nas2/

    fi

    sleep 10

    echo Unmount $directory

    if umount nas2:$directory ; then
        echo Unmounted
    fi

    sleep 30

done
