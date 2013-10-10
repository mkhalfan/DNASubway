#!/bin/bash
if [[ ! $IPLANTUSER ]];the
    read -p "iPlant username: " USER
fi

if [[ ! $TOKEN ]];then
    read -s -p "iPlant password: " TOKEN
fi

curl -sku "$IPLANTUSER:$TOKEN" https://foundation.iplantc.org/apps-v1/job/$1/output/ipc.stderr

