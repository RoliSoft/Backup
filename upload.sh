#!/bin/bash

. funcs.sh

# enumerate backups ready to upload

find "arch" -mindepth 1 -maxdepth 1 -type f | while read -r file; do
	echo "uploading archive $file..."
	
	name=$(echo "$file" | sed 's/\.\./\//g' | sed 's/^arch\///')
	dstdir=${name%/*}
	
	# upload to google
	
	(\
		rclone -v copy "$file" "gdjk:Backup/Automatic/$dstdir" 2>&1 | awk '{ print "gdrive: " $0 }' \
	)&
	
	# upload to mega
	
	(\
		megamkdir "/Root/Backup/Automatic/$dstdir" 2>&1 | tr '\r' '\n' | awk '{ print "mega: " $0 }'; \
		megaput --path "/Root/Backup/Automatic/$dstdir" $file 2>&1 | tr '\r' '\n' | awk '{ print "mega: " $0 }' \
	)&
	
	# wait for all uploads to finish
	
	wait
	
	# remove file
	
	rm "$file"
done