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
