#!/bin/bash
echo *.json | perl -pe  's/\s+/\n/g' |sed 's/^/install_app.sh /' | /bin/bash
