#!/usr/bin/env bash

# for mibe_install.sh
: ${DS_MIBE:="tank/mibe"}
: ${DS_MIBE_QUOTA:="300G"}

# latest base image
export BASE_IMG_NAME="minimal-64-trunk"
export BASE_IMG_VERSION="20240116"

export MI_HOME=/${DS_MIBE}
export PATH=$PATH:${MI_HOME}/bin
export VM_HOME=${MI_HOME}/vms
export CURR_DIR=$(pwd)

# support for use variables from /usbkey/config
source /opt/custom/lib/lib_deploy.sh && load_usbkey_vars

echo ${CONFIG_dns_resolvers:?"variable not set in /usbkey/config"}>/dev/null 2>&1
DNS_RESOLVERS=$(echo "${CONFIG_dns_resolvers:-10.211.0.1,10.211.0.2}" | jq --raw-input 'split(",")')

echo ${CONFIG_gz_zones_logs_mount:?"variable not set in /usbkey/config"}>/dev/null 2>&1
LOGS_MOUNT="${CONFIG_gz_zones_logs_mount:-/var/log/alexxlabs}"

DNS_DOMAIN="${CONFIG_dns_domain:-alexxlabs.com}"

print() {
	echo -e "\n\033[1m> ${1}\033[0m\n"
}

die() {
	printf '\033[1;31mERROR:\033[0m %s\n' "$@" >&2  # bold red
	exit 1
}
