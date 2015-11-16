#!/bin/bash

. funcs.sh

# enumerate backups ready to upload

find "arch" -mindepth 1 -maxdepth 1 -type f | sed 's/^arch\///' | while read -r file; do
	echo $(ts) "uploading archive $file..."
	
	name=$(echo "$file" | sed 's/\.\./\//g' | sed 's/^arch\///')
	dstdir=${name%/*}
	
	# move to temp and rename, since most tools don't allow to specify a new name
	
	name=${name##*/}
	mv -f "arch/$file" "temp/$name"
	
	# upload to google
	
	(\
		rclone -v copy "temp/$name" "gdjk:Backup/Automatic/$dstdir" 2>&1 | awk '{ print "[gdrive] " $0 }' \
	)&
	
	# upload to mega
	
	(\
		megamkdir "/Root/Backup/Automatic/$dstdir" 2>&1 | tr '\r' '\n' | awk '{ print "[mega] " $0 }'; \
		megaput --path "/Root/Backup/Automatic/$dstdir" "temp/$name" 2>&1 | tr '\r' '\n' | awk '{ print "[mega] " $0 }' \
	)&
	
	# upload to ftp
	
	(\
		cd "temp"; \
		echo -e "cd \"Digi Cloud/Backup/Automatic\"\nmkdir \"$dstdir\"\ncd \"$dstdir\"\nput \"$name\"" | \
		ftp -p -i -v storage.rcs-rds.ro 2>&1 | awk '{ print "[ftp] " $0 }' \
	)&
	
	# wait for all uploads to finish
	
	wait
	
	# remove file
	
	rm "temp/$name"
done
