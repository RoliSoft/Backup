#!/bin/bash

. funcs.sh

# check if running under cygwin and modify symbolic linking behaviour

sl=1

if [[ $(uname -s) =~ CYGWIN ]]; then
	# check if user is admin
	if id -G | grep -qE '\<(544|0)\>'; then
		# use native NTFS symlinks
		export CYGWIN="winsymlinks:native"
	else
		# NTFS symlinks can only be created by admins
		sl=0
		error $(ts) "you are running Cygwin without admin rights: symlinking will not be used"
	fi
fi

# enumerate backups ready to upload

find "arch" -mindepth 1 -maxdepth 1 -type f | sed 's/^arch\///' | while read -r file; do
	echo $(ts) "uploading archive $file..."
	
	name=$(echo "$file" | sed 's/\.\./\//g' | sed 's/^arch\///')
	dstdir=${name%/*}
	
	# create symlink with new name, since most tools don't allow to specify a new name
	
	if [ $sl -eq 1 ]; then
		name=${name##*/}
		ln -f -s "arch/$file" "arch/$name"
	fi
	
	# upload to google
	
	(\
		rclone -v copy "arch/$name" "gdjk:Backup/Automatic/$dstdir" 2>&1 | awk '{ print "[gdrive] " $0 }' \
	)&
	
	# upload to mega
	
	(\
		megamkdir "/Root/Backup/Automatic/$dstdir" 2>&1 | tr '\r' '\n' | awk '{ print "[mega] " $0 }'; \
		megaput --path "/Root/Backup/Automatic/$dstdir" "arch/$name" 2>&1 | tr '\r' '\n' | awk '{ print "[mega] " $0 }' \
	)&
	
	# upload to ftp
	
	(\
		cd "arch"; \
		echo -e "cd \"Digi Cloud/Backup/Automatic\"\nmkdir \"$dstdir\"\ncd \"$dstdir\"\nput \"$name\"" | \
		ftp -p -i -v storage.rcs-rds.ro 2>&1 | awk '{ print "[ftp] " $0 }' \
	)&
	
	# wait for all uploads to finish
	
	wait
	
	# remove file
	
	rm "arch/$name" "arch/$file"
done
