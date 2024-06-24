#!/usr/bin/env bash

# parce parameters:
readonly MODE=${1:-list}; shift
#readonly NODE=${2:-master} # ; shift

source ./mibe_lib.sh

echo -n ">>> checking 'gh' tool: "
command -v gh >/dev/null 2>&1 \
	&& gh version \
	|| echo >&2 "not installed."

echo -n ">>> processing ${DS_MIBE} ... "
ds_exists=$(zfs list -H -o name| grep "${DS_MIBE}")
[[ "x${ds_exists}" != "x" ]] \
	&& echo "exists." \
	|| (echo "not exists, create it." && zfs create ${DS_MIBE})
zfs set quota="${DS_MIBE_QUOTA}" ${DS_MIBE}
zfs set xattr=off ${DS_MIBE}
zfs set atime=off ${DS_MIBE}
zfs set compression=lz4 ${DS_MIBE}

cd $(dirname "${MI_HOME}")
[[ ! -d "$(basename ${MI_HOME})" ]] && git clone https://github.com/alexxlabs/mibe.git
cd ${MI_HOME} &&  git pull

# Additional defaults will be loaded from mi_home/.mibecfg and $HOME/.mibecfg.
# This configuration needs to be bash sourceable.
# Possible configuration options with their current default values:
cat > ${MI_HOME}/.mibecfg <<-EOF
owneruuid="5d9f7b2e-2fc5-11ef-aca1-0cc47aabb682"
ownername="alexxlabs"
urn_cloud_name="alexxlabs"
urn_creator_name="alexxlabs"
compression="gzip"
EOF

# Import latest base/base64 image to build images from:
imgadm import $(imgadm avail | awk '/minimal-64/ { print $1 }' | tail -1)