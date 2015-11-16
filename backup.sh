#!/bin/bash

. funcs.sh

# global variables
btype="full" # backup type
force=0      # force backup regardless of change state
crypt="gpg"  # encryption type

gpg_keyid="F879E486B30172F92C5C28267646148D0A934BBC" # consult documentation for GPG's --recipient
openssl_pass="env:OPENSSL_PWD" # consult documentation for OpenSSL's -pass

# read options
while getopts ":t:e:g:o:fh" opt; do
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
	e)
		case $OPTARG in
			n|nop|none)
				crypt="nop"
			;;
			g|gpg|pgp)
				crypt="gpg"
			;;
			o|osl|openssl)
				crypt="osl"
			;;
			*)
				error "encryption type not supported: $OPTARG"
				exit 1
			;;
		esac
	;;
	g)
		gpg_keyid="$OPTARG"
	;;
	o)
		openssl_pass="$OPTARG"
	;;
	f)
		force=1
	;;
	h)
		echo "usage: $0 [-f] [-t f|i] [-e n|g|o] [-g recipient] [-o password]"
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

# print run info

echo -n $(ts) "backup type: "

case $btype in
	full)
		echo -n "full"
	;;
	incr)
		echo -n "incremental"
	;;
esac

echo -n "; encryption: "

case $crypt in
	nop)
		echo -n "none"
	;;
	gpg)
		echo -n "GPG"
	;;
	osl)
		echo -n "OpenSSL"
	;;
esac

echo

# checks whether the specified directory has had any changes since the last backup
# retval: indicates change status, where 0 is false, 1 is true
has_mods ()
{
	if [ ! -f "data/$1.lastdate.txt" ]; then
		# if no data available, assume first run
		return 1
	fi
	
	# read last backup date
	date=$(cat "data/$1.lastdate.txt")
	
	if [ -z "$3" ]; then
		# generate complementary git ignores, if not backing up through find
		gen_git_ignores "$2" 0 > "data/$1.exclude.txt"
	else
		# parse find conditions into an array
		IFS=' ' read -a cond <<< "$3"
	fi
	
	ret=$(\
			( cd "$2"; find . -type f "${cond[@]}" -newermt "$date" ! -newermt "now" ! -name 'desktop.ini' ! -name 'Thumbs.db' -print ) | \
			( [[ -z "$3" ]] && grep -vFf "data/$1.exclude.txt" || cat ) | \
			wc -l \
		)
	
	# clean up
	
	if [ -z "$3" ]; then
		rm -f "data/$1.exclude.txt"
	fi
	
	return $ret
}

# traverses the specified path and lists all files ignored by git
gen_git_ignores ()
{
	( cd "$1"; find . -type d -name '.git' -print0 ) | while IFS= read -r -d $'\0' dir; do
		dir=$(echo "$dir" | sed 's/\.git$//')
		(\
			cd "$1"; cd "$dir"; \
			git ls-files -oi --exclude-standard --directory | \
			awk '{ print "'"$dir"'" $0 }' | \
			( [[ $2 -eq 1 ]] && sed 's/\/$/\/*/' || cat ) \
		)
	done
}

# archives the specified directory
archive ()
{
	date=$(date +"%Y-%m-%d_%H-%M")
	
	# generate complementary git ignores, if not listing via find
	
	if [ -z "$3" ]; then
		gen_git_ignores "$2" 1 > "data/$1.exclude.txt"
	fi
	
	# compress files
	
	if [ -z "$3" ]; then
		# using tar to list files
		
		if [[ $btype == "incr" ]] && [ -f "data/$1.lastdate.txt" ]; then
			cond2=("--newer-mtime=$(cat "data/$1.lastdate.txt")")
		fi
		
		case $crypt in
			nop)
				# no encryption
				tar --ignore-failed-read --exclude-vcs-ignores --exclude-backups --exclude-from "data/$1.exclude.txt" "${cond2[@]}" -cJf "temp/$1..$date.$btype.tar.xz" -C "$2" .
			;;
			gpg)
				# encrypt with gpg
				tar --ignore-failed-read --exclude-vcs-ignores --exclude-backups --exclude-from "data/$1.exclude.txt" "${cond2[@]}" -cJ -C "$2" . | \
				gpg --encrypt --always-trust --recipient "$gpg_keyid" --output "temp/$1..$date.$btype.tar.xz.gpg" -
			;;
			osl)
				# encrypt with openssl
				tar --ignore-failed-read --exclude-vcs-ignores --exclude-backups --exclude-from "data/$1.exclude.txt" "${cond2[@]}" -cJ -C "$2" . | \
				openssl aes-256-cbc -salt -out "temp/$1..$date.$btype.tar.xz.enc" -pass "$openssl_pass"
			;;
		esac
	else
		# using find to send file list to tar
		
		IFS=' ' read -a cond <<< "$3"
		
		if [[ $btype == "incr" ]] && [ -f "data/$1.lastdate.txt" ]; then
			cond2=("-newermt" "$(cat "data/$1.lastdate.txt")" "!" "-newermt" "now")
		fi
		
		case $crypt in
			nop)
				# no encryption
				( cd "$2"; find . -type f "${cond[@]}" "${cond2[@]}" ) | \
				tar --ignore-failed-read --exclude-vcs-ignores --exclude-backups "${cond2[@]}" -cJf "temp/$1..$date.$btype.tar.xz" -C "$2" --no-recursion --files-from -
			;;
			gpg)
				# encrypt with gpg
				( cd "$2"; find . -type f "${cond[@]}" "${cond2[@]}" ) | \
				tar --ignore-failed-read --exclude-vcs-ignores --exclude-backups -cJ -C "$2" --no-recursion --files-from - | \
				gpg --encrypt --always-trust --recipient "$gpg_keyid" --output "temp/$1..$date.$btype.tar.xz.gpg" -
			;;
			osl)
				# encrypt with openssl
				( cd "$2"; find . -type f "${cond[@]}" "${cond2[@]}" ) | \
				tar --ignore-failed-read --exclude-vcs-ignores --exclude-backups -cJ -C "$2" --no-recursion --files-from - | \
				openssl aes-256-cbc -salt -out "temp/$1..$date.$btype.tar.xz.enc" -pass "$openssl_pass"
			;;
		esac
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
	if [ $? -gt 0 ] || [ $force -eq 1 ]; then
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
