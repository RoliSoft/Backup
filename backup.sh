#!/bin/bash

# prints an error to stderr
error ()
{
	echo "$@" 1>&2
}

# echoes the current time
ts ()
{
	echo -n $(date +"[%Y-%m-%d %H:%M:%S]")
}

# checks whether the specified directory has had any changes since the last backup
# retval: indicates change status, where 0 is false, 1 is true
has_mods ()
{
	if [ ! -f "data/$1.lastdate.txt" ]; then
		# if no data available, assume first run
		return 1
	fi
	
	date=$(cat "data/$1.lastdate.txt")
	
	IFS=' ' read -a cond <<< "$3"
	ret=$(( cd "$2"; find . -type f "${cond[@]}" -newermt "$date" ! -newermt "now" ! -name 'desktop.ini' ! -name 'Thumbs.db' -print -quit ) | wc -l)
	
	return $ret
}

# archives the specified directory
archive ()
{
	date=$(date +"%Y-%m-%d.%H-%M")
	
	# generate complementary VCS ignores, if not listing via find
	
	if [ -z "$3" ]; then
		php exclude.php "$2" > "data/$1.exclude.txt"
	fi
	
	# compress files
	
	# compress directly to file
	#if [ -z "$3" ]; then
	#	tar --exclude-vcs-ignores --exclude-backups --exclude-from "data/$1.exclude.txt" -cJf "temp/$1..$date.tar.xz" -C "$2" .
	#else
	#	IFS=' ' read -a cond <<< "$3"
	#	( cd "$2"; find . -type f "${cond[@]}" ) | tar --exclude-vcs-ignores --exclude-backups -cJf "temp/$1..$date.tar.xz" -C "$2" --no-recursion --files-from -
	#fi
	# compress and encrypt
	if [ -z "$3" ]; then
		# encrypt with openssl:
		#tar --exclude-vcs-ignores --exclude-backups --exclude-from "data/$1.exclude.txt" -cJ -C "$2" . | openssl aes-256-cbc -salt -out "temp/$1..$date.tar.xz.enc" -pass env:OPENSSL_PWD
		# encrypt with gpg:
		tar --exclude-vcs-ignores --exclude-backups --exclude-from "data/$1.exclude.txt" -cJ -C "$2" . | gpg --encrypt --always-trust --recipient F879E486B30172F92C5C28267646148D0A934BBC --output "temp/$1..$date.tar.xz.gpg" -
	else
		IFS=' ' read -a cond <<< "$3"
		# encrypt with openssl:
		#( cd "$2"; find . -type f "${cond[@]}" ) | tar --exclude-vcs-ignores --exclude-backups -cJ -C "$2" --no-recursion --files-from - | openssl aes-256-cbc -salt -out "temp/$1..$date.tar.xz.enc" -pass env:OPENSSL_PWD
		# encrypt with gpg:
		( cd "$2"; find . -type f "${cond[@]}" ) | tar --exclude-vcs-ignores --exclude-backups -cJ -C "$2" --no-recursion --files-from - | gpg --encrypt --always-trust --recipient F879E486B30172F92C5C28267646148D0A934BBC --output "temp/$1..$date.tar.xz.gpg" -
	fi
	
	# move from temp to folder which contains the files to upload
	
	mv temp/"$1..$date".tar.xz* "arch/"
	
	# set last backup date
	
	if [ $? -eq 0 ]; then
		date --rfc-3339=seconds > "data/$1.lastdate.txt"
	else
		error $(ts) "an error occurred while archiving $1"
	fi
	
	# clean up
	
	if [ -z "$3" ]; then
		rm -f "data/$1.exclude.txt"
	fi
}

# tests whether a backup is needed and performs it
backup ()
{
	has_mods "$1" "$2" "$3"
	if [ $? -eq 1 ]; then
		echo $(ts) "backing up $1..."
		archive "$1" "$2" "$3"
	fi
}

# traverses a directory full of project folders and treats each one individually
# parameter 3 is an optional regular expression for skipping projects
backup_dev ()
{
	find "$2" -mindepth 1 -maxdepth 1 -type d | while read -r dir; do
		if [ ! -z "$3" ] && [[ $(basename "$dir") =~ ^($3)$ ]]; then
			continue
		fi
		
		name=$(basename "$dir" | tr -dc '[:alnum:]')
		backup "$1..$name" "$dir"
	done
}

# helper stuff

# matches visual studio projects which were created with the default name; these will be skipped
GenericVsProj='(ATL)?Project[0-9]+|(WindowsForms|Console|Wpf|Silverlight|Web)Application[0-9]+'

# list of backups

# backup stuff I throw on the desktop
backup Desktop..euvps /cygdrive/c/Users/RoliSoft/Desktop/euvps
backup Desktop..cloudflare /cygdrive/c/Users/RoliSoft/Desktop/cloudflare
backup Desktop..backup /cygdrive/c/Users/RoliSoft/Desktop/backup
backup Desktop..misc /cygdrive/c/Users/RoliSoft/Desktop "-size -50M ! -path ./backup* ! -path ./euvps* ! -path ./cloudflare* ! -path ./*-master*"

# backup visual studio projects
for vsd in /cygdrive/c/Users/RoliSoft/Documents/Visual\ Studio*/Projects; do
	backup_dev VisualStudio "$vsd" $GenericVsProj
done

# backup php projects
backup WebSites.._nginx /cygdrive/c/inetpub/server/bin/nginx/conf
backup_dev WebSites /cygdrive/c/inetpub/wwwroot 'seriesprep|jobsite'
