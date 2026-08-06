BASED_ON_NAME="alexxlabs-torr"
BASED_ON_VERSION="25.4.0"
IMAGE_UUID=$(imgadm list -H name=${BASED_ON_NAME} version=~${BASED_ON_VERSION}| awk '{ print $1 }' | tail -1)
#IMAGE_UUID="" # or directly specify alexxlabs-torr@24.4.1_1 uuid

UUID="19f0280c-3d2a-11ef-ae00-0cc47aabb682" # unique: https://www.guidgenerator.com/online-guid-generator.aspx
#UUID_DISK_QUOTA="15G" # default '15G' is setupped in mibe_lib.sh, if you want to override it - uncomment and setup

ALIAS="torr"
PRIORITY="98"
MAC="12:33:40:a9:1d:${PRIORITY}"
RAM=4096 # default is 512

: ${MOUNT_POINT_LOFS:="/opt/etc"}
: ${MOUNT_POINT_TORRENTS:="/torrents"}

LOFS_DIR="${VM_HOME}/vm_torr/lofs"
if [[ -d ${LOFS_DIR} ]]; then
	define FILESYSTEMS <<-EOF
	{"type": "lofs", "source": "${LOFS_DIR}", "target": "${MOUNT_POINT_LOFS}"}
	EOF
fi

define CUSTOMER_METADATA <<-FF
	"root_known_hosts":	"router.alexxlabs.com",
	"mountpoint_lofs": "${MOUNT_POINT_LOFS}",
	"mountpoint_torrents": "${MOUNT_POINT_TORRENTS}",
FF

# dataset declaration ("dataset", "quota", "mountpoint", "sharesmb")
# - dataset		:
# - quota		:
# - mountpoint	:
# - sharesmb	: 'no' or 'user:group' to chown shared directory
dataset_media=("tank/media" "1500G" "/media" "admin:staff")
dataset_http_root=("zones/alexxlabs/http_root" "300G" "default" "admin:staff")
dataset_torrents=("zones/alexxlabs/torrents" "300G" "${MOUNT_POINT_TORRENTS}" "admin:staff")
dataset_install=("zones/alexxlabs/install" "300G" "/install" "admin:staff")
# tank/rpi  sharenfs  rw=@10.2.0.0/24,root=@10.2.0.0/24

# names of datasets, defined above, to process on VM operations: /tank/mibe/mibe_vm.sh
# (create, optional setup 'quota', 'mountpoint', 'sharesmb')
datasets_to_process=("dataset_media" "dataset_http_root" "dataset_torrents" "dataset_install")
