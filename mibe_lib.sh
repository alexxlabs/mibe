#!/usr/bin/env bash

# for mibe_install.sh
: ${DS_MIBE:="tank/mibe"}
: ${DS_MIBE_QUOTA:="300G"}

export MI_HOME=/${DS_MIBE}
export PATH=$PATH:${MI_HOME}/bin
export CURR_DIR=$(pwd)

# support for use variables from /usbkey/config
source /opt/custom/lib/lib_deploy.sh && load_usbkey_vars
#echo ${CONFIG_gz_zones_alexxlabs_pass:?"variable not set in /usbkey/config"}>/dev/null 2>&1
#GZ_ALEXXLABS_PASS="${CONFIG_gz_zones_alexxlabs_pass:-no_gz_alexxlabs_pass}"
#echo ${CONFIG_gz_github_token:?"variable not set in /usbkey/config"}>/dev/null 2>&1
#GITHUB_TOKEN="${CONFIG_gz_github_token:-no_token}"

print() {
	echo -e "\n\033[1m> ${1}\033[0m\n"
}

die() {
	printf '\033[1;31mERROR:\033[0m %s\n' "$@" >&2  # bold red
	exit 1
}
