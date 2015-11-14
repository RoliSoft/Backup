#!/bin/bash

# prints an error to stderr
error ()
{
	echo "$@" 1>&2
}

# checks whether the specified directory has had any changes since the last backup
# retval: indicates change status, where 0 is false, 1 is true
has_mods ()
{
	if [ ! -f "data/$1.lastdate.txt" ]; then
		# if no data available, assume first run
		return 1
	fi
	
	ret=$(find "$2" -type f -newermt "$(cat data/$1.lastdate.txt)" ! -name 'desktop.ini' ! -name 'Thumbs.db' -print -quit | wc -l)
	
	return $ret
}

# archives the specified directory
archive ()
{
	date=$(date +"%Y-%m-%d.%H-%M")
	
	php exclude.php "$2" > "temp/$1.exclude.txt"
	
	# compress directly to file:
	tar --exclude-vcs-ignores --exclude-backups --exclude-from "temp/$1.exclude.txt" -cJf "temp/$1.$date.tar.xz" -C "$2" .
	
	# compress and encrypt with openssl:
	#tar --exclude-vcs-ignores --exclude-backups --exclude-from "temp/$1.exclude.txt" -cJ -C "$2" . | openssl aes-256-cbc -salt -out "temp/$1.$date.tar.xz.enc" -pass env:OPENSSL_PWD
	
	# compress and encrypt with gpg:
	#tar --exclude-vcs-ignores --exclude-backups --exclude-from "temp/$1.exclude.txt" -cJ -C "$2" . | gpg --encrypt --always-trust --recipient F879E486B30172F92C5C28267646148D0A934BBC --output "temp/$1.$date.tar.xz.gpg" -
	
	rm -f "temp/$1.exclude.txt"
	
	if [ $? -eq 0 ]; then
		date --rfc-3339=seconds > "data/$1.lastdate.txt"
	else
		error "an error occurred while archiving $1"
	fi
}

# tests whether a backup is needed and performs it
backup ()
{
	has_mods "$1" "$2"
	if [ $? -eq 1 ]; then
		echo "backing up $1..."
		archive "$1" "$2"
	fi
}

# traverses a directory full of project folders and treats each one individually
backup_dev ()
{
	find "$2" -mindepth 1 -maxdepth 1 -type d | while read -r dir; do
		name=$(basename "$dir" | tr -dc '[:alnum:]')
		backup "$1.$name" "$dir"
	done
}

# list of backups

#backup test /cygdrive/c/Users/RoliSoft/Desktop/euvps
backup_dev vs "/cygdrive/c/Users/RoliSoft/Documents/Visual Studio 2015/Projects"
backup_dev vs "/cygdrive/c/Users/RoliSoft/Documents/Visual Studio 2012/Projects"
#backup_dev www "/cygdrive/c/inetpub/wwwroot"
