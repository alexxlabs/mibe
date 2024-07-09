#!/usr/bin/env bash

# for mibe_install.sh
: ${DS_MIBE:="tank/mibe"}
: ${DS_MIBE_QUOTA:="300G"}

# default disk quota of ALL created zones [mibe_vm.sh]
: ${UUID_DISK_QUOTA:="15G"}

# latest base image
export BASE_IMG_NAME="minimal-64-trunk"
export BASE_IMG_VERSION="20240116" # also fix 'version' in: 'manifest' and 'manifest.json'

export MI_HOME=/${DS_MIBE}
export PATH=$PATH:${MI_HOME}/bin
export VM_HOME=${MI_HOME}/vms
export CURR_DIR=$(pwd)

# support for use variables from /usbkey/config
source /opt/custom/lib/lib_deploy.sh && load_usbkey_vars

echo ${CONFIG_dns_resolvers:?"variable not set in /usbkey/config"}>/dev/null 2>&1
DNS_RESOLVERS=$(echo "${CONFIG_dns_resolvers:-10.211.0.1,10.211.0.2}" | jq --raw-input 'split(",")')

echo ${CONFIG_dns_domain:?"variable not set in /usbkey/config"}>/dev/null 2>&1
DNS_DOMAIN="${CONFIG_dns_domain:-alexxlabs.com}"

echo ${CONFIG_mta_mailto:?"variable not set in /usbkey/config"}>/dev/null 2>&1
MTA_MAILTO="${CONFIG_mta_mailto:-master@alexxlabs.com}"

echo ${CONFIG_mta_host:?"variable not set in /usbkey/config"}>/dev/null 2>&1
MTA_HOST="${CONFIG_mta_host:-master@alexxlabs.com}"

echo ${CONFIG_gz_zones_alexxlabs_pass:?"variable not set in /usbkey/config"}>/dev/null 2>&1
ALEXXLABS_PASS=${CONFIG_gz_zones_alexxlabs_pass}
