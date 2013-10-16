#!/bin/bash
if [[ ! $IPLANTUSER ]];then
    read -p "iPlant username: " USER
fi

if [[ ! $TOKEN ]];then
    read -s -p "iPlant password: " TOKEN
fi

grep '"name"\|"version"' *json | perl -pe 's/^.+:\s+|[",]+//g' \
|perl -pe 's/(stampede\S*|lonestar\S*)\n/$1-/g' | sed 's/^/delete_app.sh /' | /bin/bash
