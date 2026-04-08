#!/bin/bash

AuthURL=https://<THINGSBOARD_HOST>/api/auth/login
AddUserURL=https://<THINGSBOARD_HOST>/api/user

CustomerId=<CUSTOMER_ID>
CustomerAdmin=<TB_USERNAME>
CustomerPassword=<TB_PASSWORD>
authority=CUSTOMER_USER
AdminGroupId=<ADMIN_GROUP_ID>
UserGroupId=<USER_GROUP_ID>

UsersList="John,Smith,jsmith@example.com,admin
           John,Doe,jdoe@example.com,user
           Bill,Gates,bgates@example.com,user"

Token=$(curl -sS -n -X POST \
-H 'Content-Type:application/json' \
-H 'Accept:application/json' \
-d '{"username":"'$CustomerAdmin'","password":"'$CustomerPassword'"}' \
$AuthURL | python -mjson.tool | grep token | awk -F\" '{print $4}')

for User in $UsersList; do

    firstName=${User%%,*}

    lastName=${User#*,}
    lastName=${lastName%%,*}

    email=${User%,*}
    email=${email##*,}

    group=${User##*,}

    case $group in
        admin) GroupId=$AdminGroupId
        ;;
        user)  GroupId=$UserGroupId
        ;;
    esac

    Parameters="?sendActivationMail=false&entityGroupId=$GroupId"

    PostAddUserURL="$AddUserURL$Parameters"

    curl -sS -n -X POST \
    -H 'Content-Type:application/json' \
    -H 'Accept:application/json' \
    -H 'X-Authorization: Bearer '$Token'' \
    -d '{"firstName":"'$firstName'","lastName":"'$lastName'","email":"'$email'","authority":"'$authority'"}' \
    $PostAddUserURL

    echo

done
