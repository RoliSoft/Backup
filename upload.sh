#!/bin/bash

# enumerate backups ready to upload

find "arch" -mindepth 1 -maxdepth 1 -type f | while read -r file; do
	echo "uploading archive $file..."
	
	name=$(echo "$file" | sed 's/\.\./\//g' | sed 's/^arch\///')
	megadir=${name%/*}
	
	# upload to google
	
	( rclone copy "$file" "gdjk:Backup/Automatic/$name" )&
	
	# upload to mega
	
	( megamkdir "/Root/Backup/Automatic/$megadir"; megaput --path "/Root/Backup/Automatic/$name" $file )&
	
	# wait for all uploads to finish
	
	wait
	
	# remove file
	
	#rm "$file"
done