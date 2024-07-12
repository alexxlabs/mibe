BASED_ON_NAME="alexxlabs-base"
BASED_ON_VERSION="20240116.0"
IMAGE_UUID=$(imgadm list -H name=${BASED_ON_NAME} version=~${BASED_ON_VERSION}| awk '{ print $1 }' | tail -1)
#IMAGE_UUID="69fe7a6a-3d34-11ef-9790-0cc47aabb682" # or directly specify alexxlabs-base@20240116.0 uuid

UUID="19f0280c-3d2a-11ef-ae00-0cc47aabb682" # unique: https://www.guidgenerator.com/online-guid-generator.aspx
#UUID_DISK_QUOTA="15G" # default '15G' is setupped in mibe_lib.sh, if you want to override it - uncomment and setup

ALIAS="test"
PRIORITY="99"
MAC="12:33:40:a9:1d:${PRIORITY}"
RAM=1024 # default is 512

#define FILESYSTEMS <<-EOF
#{"type": "lofs", "source": "/${DS_PKGSRC}", "target": "${DS_PKGSRC_MOUNTPOINT}"}
#EOF

: ${DS_TCE:="tank/tce"}
: ${DS_TCE_QUOTA:="300G"}
#: ${DS_TCE_MOUNTPOINT:="/tce"} # default mountpoint will be '/${DS_TCE}'
echo -n ">>> processing ${DS_TCE} ... "
ds_exists=$(zfs list -H -o name| grep "${DS_TCE}")
[[ "x${ds_exists}" != "x" ]] && echo "exists." || (echo "not exists, create it." && zfs create ${DS_TCE})
[[ "x${DS_TCE_QUOTA}" != "x" ]] && zfs set quota="${DS_TCE_QUOTA}" ${DS_TCE}
zfs set xattr=off ${DS_TCE}
zfs set atime=off ${DS_TCE}
zfs set compression=lz4 ${DS_TCE}
# !!! WARNING !!! WE CHANGE MOUNTPOINT OF THIS DATASET !!! we 'inherit' it on zone deletion
# !!! commented for now, gives error:
# !!!		- cannot set property for 'tank/tce': 'mountpoint' cannot be set on dataset in a non-global zone
#[[ "x${DS_TCE_MOUNTPOINT}" != "x" ]] \
#	&& echo "===> set mountpoint of ${DS_TCE} dataset to: ${DS_TCE_MOUNTPOINT}" \
#	&& zfs set mountpoint="${DS_TCE_MOUNTPOINT}" ${DS_TCE}

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
	${DS_TCE}
)

#	"vfstab":	"storage.alexxlabs.com:/export/data  -  /data  nfs  -  yes  rw,bg,intr"
define CUSTOMER_METADATA <<-FF
	"datasets_to_mount":	"${datasets_to_mount[@]}",
FF
