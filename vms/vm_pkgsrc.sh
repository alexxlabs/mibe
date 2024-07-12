BASED_ON_NAME="pkgbuild-trunk"
BASED_ON_VERSION="20240116"
IMAGE_UUID=$(imgadm list -H name=${BASED_ON_NAME} version=~${BASED_ON_VERSION}| awk '{ print $1 }' | tail -1)
#IMAGE_UUID="uuid" # or directly specify base image 'uuid'

UUID="638c15c8-3e76-11ef-9194-0cc47aabb682" # unique: https://www.guidgenerator.com/online-guid-generator.aspx
UUID_DISK_QUOTA="500G" # default '15G' is setupped in mibe_lib.sh, if you want to override it - uncomment and setup

ALIAS="pkgsrc"
PRIORITY="99"
MAC="12:33:40:a9:1d:${PRIORITY}"
RAM=10240 # default is 512

LOFS_DIR="${VM_HOME}/vm_pkgsrc"
if [[ -d ${LOFS_DIR} ]]; then
	define FILESYSTEMS <<-EOF
	{"type": "lofs", "source": "${LOFS_DIR}", "target": "/data/alexxlabs"}
	EOF
fi

: ${DS_PKGSRC:="zones/alexxlabs/pkgsrc"}
: ${DS_PKGSRC_QUOTA:="300G"}
#: ${DS_PKGSRC_MOUNTPOINT:="/opt/pkgsrc"} # default mountpoint will be '/${DS_PKGSRC}'
echo -n ">>> processing ${DS_PKGSRC} ... "
ds_exists=$(zfs list -H -o name| grep "${DS_PKGSRC}")
[[ "x${ds_exists}" != "x" ]] && echo "exists." || (echo "not exists, create it." && zfs create ${DS_PKGSRC})
[[ "x${DS_PKGSRC_QUOTA}" != "x" ]] && zfs set quota="${DS_PKGSRC_QUOTA}" ${DS_PKGSRC}
zfs set xattr=off ${DS_PKGSRC}
zfs set atime=off ${DS_PKGSRC}
zfs set compression=lz4 ${DS_PKGSRC}
# !!! WARNING !!! WE CHANGE MOUNTPOINT OF THIS DATASET !!! we 'inherit' it on zone deletion
# !!! commented for now, gives error:
# !!!		- cannot set property for 'tank/tce': 'mountpoint' cannot be set on dataset in a non-global zone
#[[ "x${DS_PKGSRC_MOUNTPOINT}" != "x" ]] \
#	&& echo "===> set mountpoint of ${DS_PKGSRC} dataset to: ${DS_PKGSRC_MOUNTPOINT}" \
#	&& zfs set mountpoint="${DS_PKGSRC_MOUNTPOINT}" ${DS_PKGSRC}

# https://thetooth.name/blog/homelab-2022-part-2-samba-on-smartos-using-delegated-datasets/
# !!! instead of delegate datasets and LOFS - use this mounting inside zone !!!
# The official documentation would lead you to believe that the only step required is setting the delegate_dataset flag.
# But as cautioned in the guide anything we put into this zone will share it's life cycle with the zone itself.
# We won't be using this flag at all and instead I will be delegating an existing dataset in such a way that the zone
# can be deleted at any time while retaining our content for future zones or importing straight into any other ZFS capable
# operating system. A side note on LOFS:
#   If you need multiple zones to access the same dataset concurrently but also cannot use NFS/Samba an alternate option
#   is LOFS. LOFS, works kind of like 'mount --bind', abstracting the calls to perform reads and writes and some simple
#   locking, it is however not an ideal solution. It's possible for a misbehaving zone to lock a file forever and crash,
#   needing a full host power cycle to get things moving again. The performance isn't much better than Samba either,
#   expect a hard cap on IOPs and no more than 100MB/s throughput. And of course it wont work with HVM guests at all.
datasets_to_mount=(
	${DS_PKGSRC}
)

#	"vfstab":	"storage.alexxlabs.com:/export/data  -  /data  nfs  -  yes  rw,bg,intr"
define CUSTOMER_METADATA <<-FF
	"datasets_to_mount":	"${datasets_to_mount[@]}",
FF

# because pkgsrc image is not based on our alexxlabs-base (with our initial setup procedure)
# provide some separate setup procedure for newly deployed 'pkgsrc'
define VM_SETUP_FROM_GZ_INIT <<-FF
	zoneroot="/zones/${UUID}/root"
	[[ -f ${MI_HOME}/repos/mi-alexxlabs-base/copy/etc/ssh/sshd_config ]] \
		&& echo "copy sshd_config inside zone: ${UUID}" \
		&& cp ${MI_HOME}/repos/mi-alexxlabs-base/copy/etc/ssh/sshd_config \${zoneroot}/etc/ssh
FF

define VM_SETUP_INSIDE_INIT << 'FF'

	pkgin up && pkgin ug
	pkgin install bmake

	# Configure root ssh authorized_keys file if available via mdata
	if mdata-get root_authorized_keys 1>/dev/null 2>&1; then
		mkdir -p /root/.ssh
		echo "# This file is managed by mdata-get root_authorized_keys" > /root/.ssh/authorized_keys
		# after getting key inside VM replace $ symbol with newlines - so we get correct newlines inside VM
		key=$(mdata-get root_authorized_keys| /usr/bin/tr "$" "\n" || echo "no_key")
		echo ${key} >> /root/.ssh/authorized_keys
		chmod 700 /root/.ssh
		chmod 644 /root/.ssh/authorized_keys
	fi

	# Configure known_hosts for root user in mdata variable
	if mdata-get root_known_hosts 1>/dev/null 2>&1; then
		mkdir -p /root/.ssh
		echo "# This file is managed by mdata-get root_known_hosts" > /root/.ssh/known_hosts
		known_hosts=$(mdata-get root_known_hosts| /usr/bin/tr "$" "\n" || echo "no_known_hosts")
		echo "${known_hosts}"  >> /root/.ssh/known_hosts
	fi

	# restart sshd because we copy new 'sshd_config' inside zone
	svcadm restart ssh
FF
