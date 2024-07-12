#!/usr/bin/env bash

# parce parameters:
readonly REPONAME=${1:-empty}; shift

source ./mibe_lib.sh

#	-g	Git support.
#		* Remotly create repo on github (using custom 'gh' tool)
#		* Locally create ALL needed files AND commit AND push ALL to remote repo
repo_init -g smartos "mi-alexxlabs-${REPONAME}"
