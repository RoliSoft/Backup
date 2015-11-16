#!/bin/bash

. funcs.sh

# check for remnants

if [[ ! $(ls -1 temp/ | wc -l) -eq 0 ]]; then
	echo $(ts) "previous backup files exist"
	rm temp/*
fi

# start backup

echo $(ts) "starting backup process"
./backup.sh

# start upload

echo $(ts) "starting upload process"
./upload.sh

echo $(ts) "backup script finished"