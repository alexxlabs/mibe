#!/usr/bin/env bash

source <(curl -s https://raw.githubusercontent.com/alexxlabs/mibe/master/mibe_lib.sh)

echo -n ">>> checking 'git' tool... "
command -v git >/dev/null 2>&1 \
	&& git version \
	|| die "git not installed."

echo -n ">>> processing ${DS_MIBE} ... "
ds_exists=$(zfs list -H -o name| grep "${DS_MIBE}")
[[ "x${ds_exists}" != "x" ]] \
	&& echo "exists." \
	|| (echo "not exists, create it." && zfs create ${DS_MIBE})
zfs set quota="${DS_MIBE_QUOTA}" ${DS_MIBE}
zfs set xattr=off ${DS_MIBE}
zfs set atime=off ${DS_MIBE}
zfs set compression=lz4 ${DS_MIBE}

cd "${MI_HOME}"
[[ -d ".git" ]] && git pull || git clone https://github.com/alexxlabs/mibe.git .

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

# Import base/base64 image to build images from:
#	setup BASE_IMG_NAME and BASE_IMG_VERSION in 'mibe_lib.sh'
imgadm import $(imgadm avail name=${BASE_IMG_NAME} version=~${BASE_IMG_VERSION}| awk '{ print $1 }' | tail -1)

# or get the latest availible 'minimal-64' image:
#imgadm import $(imgadm avail | awk '/minimal-64/ { print $1 }' | tail -1)
