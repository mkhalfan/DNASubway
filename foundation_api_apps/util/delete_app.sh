#!/bin/bash

if [[ ! $IPLANTUSER ]];then
    read -p "iPlant username: " USER
fi

if [[ ! $TOKEN ]];then
    read -s -p "iPlant password: " TOKEN
fi

APP=$1
if ! [[ -n $APP ]]; then
    read -p "Application to delete (e.g. dnalc-tophat-lonestar-2.0.6): " APP
fi

echoerr() { echo "$@" 1>&2; }

if [[ $IPLANTUSER  ]] && [[ $TOKEN ]] && [[ $APP ]]; 
then
    echoerr "Hello ${USER}.  I will now delete $APP!"
    curl -X DELETE -sku "$IPLANTUSER:$TOKEN" https://foundation.iplantc.org/apps-v1/apps/$APP |json_xs -f json 
else
    echoerr "You must provide a username, password, and JSON file name!"
fi

