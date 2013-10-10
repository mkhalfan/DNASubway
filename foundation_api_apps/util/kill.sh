#!/bin/bash
if [[ ! $IPLANTUSER ]];then
    read -p "iPlant username: " USER
fi

if [[ ! $TOKEN ]];then
    read -s -p "iPlant password: " TOKEN
fi

for job in "$@"
do
    echo "OK, I will kill job $job"
    curl -X DELETE -sku "$IPLANTUSER:$TOKEN" https://foundation.iplantc.org/apps-v1/job/$job |json_xs 
done
