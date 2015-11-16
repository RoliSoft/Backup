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

# global variables
btype="full" # backup type
force=0      # force backup regardless of change state

# read options
while getopts ":t:fh" opt; do
	case $opt in
	t)
		case $OPTARG in
			f|full)
				btype="full"
			;;
			i|incr)
				btype="incr"
			;;
			*)
				error "backup type not supported: $OPTARG"
				exit 1
			;;
		esac
	;;
	f)
		force=1
	;;
	h)
		echo "usage: $0 [-f] [-t f|i]"
		echo
		echo "This is more of a DIY backup solution. For more info check the source."
		exit 0
	;;
	\?)
		error "option not supported: -$OPTARG"
		exit 1
	;;
	:)
		error "option requires argument: -$OPTARG"
		exit 1
	;;
	esac
done

case $btype in
	full)
		echo $(ts) "full backup requested"
	;;
	incr)
		echo $(ts) "incremental backup requested"
	;;
esac

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

# traverses the specified path and lists all files ignored by git
gen_git_ignores ()
{
	( cd "$1"; find . -type d -name '.git' -print0 ) | while IFS= read -r -d $'\0' dir; do
		dir=$(echo "$dir" | sed 's/\.git$//')
		( cd "$1"; cd "$dir"; git ls-files -oi --exclude-standard --directory | awk '{ print "'"$dir"'" $0 }' )
	done
}

# archives the specified directory
archive ()
{
	date=$(date +"%Y-%m-%d.%H-%M")
	
	# generate complementary git ignores, if not listing via find
	
	if [ -z "$3" ]; then
		gen_git_ignores "$2" > "data/$1.exclude.txt"
	fi
	
	# compress files
	
	# compress directly to file
	#if [ -z "$3" ]; then
	#	if [[ $btype == "incr" ]] && [ -f "data/$1.lastdate.txt" ]; then
	#		cond2=("--newer-mtime=$(cat "data/$1.lastdate.txt")")
	#	fi
	#	
	#	tar --exclude-vcs-ignores --exclude-backups --exclude-from "data/$1.exclude.txt" "${cond2[@]}" -cJf "temp/$1..$date.$btype.tar.xz" -C "$2" .
	#else
	#	IFS=' ' read -a cond <<< "$3"
	#	
	#	if [[ $btype == "incr" ]] && [ -f "data/$1.lastdate.txt" ]; then
	#		cond2=("-newermt" "$(cat "data/$1.lastdate.txt")" "!" "-newermt" "now")
	#	fi
	#	
	#	( cd "$2"; find . -type f "${cond[@]}" "${cond2[@]}" ) | tar --exclude-vcs-ignores --exclude-backups "${cond2[@]}" -cJf "temp/$1..$date.$btype.tar.xz" -C "$2" --no-recursion --files-from -
	#fi
	# compress and encrypt
	if [ -z "$3" ]; then
		if [[ $btype == "incr" ]] && [ -f "data/$1.lastdate.txt" ]; then
			cond2=("--newer-mtime=$(cat "data/$1.lastdate.txt")")
		fi
		
		# encrypt with openssl:
		#tar --exclude-vcs-ignores --exclude-backups --exclude-from "data/$1.exclude.txt" "${cond2[@]}" -cJ -C "$2" . | openssl aes-256-cbc -salt -out "temp/$1..$date.$btype.tar.xz.enc" -pass env:OPENSSL_PWD
		# encrypt with gpg:
		tar --exclude-vcs-ignores --exclude-backups --exclude-from "data/$1.exclude.txt" "${cond2[@]}" -cJ -C "$2" . | gpg --encrypt --always-trust --recipient F879E486B30172F92C5C28267646148D0A934BBC --output "temp/$1..$date.$btype.tar.xz.gpg" -
	else
		IFS=' ' read -a cond <<< "$3"
		
		if [[ $btype == "incr" ]] && [ -f "data/$1.lastdate.txt" ]; then
			cond2=("-newermt" "$(cat "data/$1.lastdate.txt")" "!" "-newermt" "now")
		fi
		
		# encrypt with openssl:
		#( cd "$2"; find . -type f "${cond[@]}" "${cond2[@]}" ) | tar --exclude-vcs-ignores --exclude-backups -cJ -C "$2" --no-recursion --files-from - | openssl aes-256-cbc -salt -out "temp/$1..$date.$btype.tar.xz.enc" -pass env:OPENSSL_PWD
		# encrypt with gpg:
		( cd "$2"; find . -type f "${cond[@]}" "${cond2[@]}" ) | tar --exclude-vcs-ignores --exclude-backups -cJ -C "$2" --no-recursion --files-from - | gpg --encrypt --always-trust --recipient F879E486B30172F92C5C28267646148D0A934BBC --output "temp/$1..$date.$btype.tar.xz.gpg" -
	fi
	
	# move from temp to folder which contains the files to upload
	
	mv temp/"$1..$date.$btype".tar.xz* "arch/"
	
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
	if [ $? -eq 1 ] || [ $force -eq 1 ]; then
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
