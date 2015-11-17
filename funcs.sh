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

# format the input to plural when value is greater than 1
plural ()
{
	if [ $1 -eq 1 ]; then
		echo "$1 $2"
	else
		echo "$1 $2s"
	fi
}
