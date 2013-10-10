#!/bin/bash
if [[ ! $IPLANTUSER ]];then
    read -p "iPlant username: " USER
fi

if [[ ! $TOKEN ]];then
    read -s -p "iPlant password: " TOKEN
fi

curl  -sku "$IPLANTUSER:$TOKEN" https://foundation.iplantc.org/apps-v1/jobs/list \
| json_xs | grep '"status"\|"id"\|"software"\|"archivePath"' \
| grep -v success | perl -pe  's/^\s+//' |sed 's/"sta/\n"sta/'
