BASED_ON_NAME="alexxlabs-base"
BASED_ON_VERSION="20240116.1"
IMAGE_UUID=$(imgadm list -H name=${BASED_ON_NAME} version=~${BASED_ON_VERSION}| awk '{ print $1 }' | tail -1)
#IMAGE_UUID="" # or directly specify alexxlabs-base@20240116.0 uuid

UUID="19f0280c-3d2a-11ef-ae00-0cc47aabb682" # unique: https://www.guidgenerator.com/online-guid-generator.aspx
#UUID_DISK_QUOTA="15G" # default '15G' is setupped in mibe_lib.sh, if you want to override it - uncomment and setup

ALIAS="test"
PRIORITY="98"
MAC="12:33:40:a9:1d:${PRIORITY}"
RAM=1024 # default is 512

#define FILESYSTEMS <<-EOF
#	{"type": "lofs", "source": "/${DS_PKGSRC}", "target": "${DS_PKGSRC_MOUNTPOINT}"}
#EOF

define CUSTOMER_METADATA <<-FF
	"root_known_hosts":	"router.alexxlabs.com",
FF

# dataset declaration ("dataset", "quota", "mountpoint", "sharesmb")
# - dataset		:
# - quota		:
# - mountpoint	:
# - sharesmb	: 'no' or 'user:group' to chown shared directory
dataset_tce=("tank/tce" "300G" "/tce" "no")
dataset_http_root=("zones/alexxlabs/http_root" "300G" "default" "admin:staff")
# tank/rpi  sharenfs  rw=@10.2.0.0/24,root=@10.2.0.0/24

# names of datasets, defined above, to process on VM operations: /tank/mibe/mibe_vm.sh
# (create, optional setup 'quota', 'mountpoint', 'sharesmb')
datasets_to_process=("dataset_tce" "dataset_http_root")
