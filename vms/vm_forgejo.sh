BASED_ON_NAME="alexxlabs-forgejo"
BASED_ON_VERSION="20240116.1"
IMAGE_UUID=$(imgadm list -H name=${BASED_ON_NAME} version=~${BASED_ON_VERSION}| awk '{ print $1 }' | tail -1)

UUID="ad4bb312-44f7-11ef-9edc-123340a91d98" # unique: https://www.guidgenerator.com/online-guid-generator.aspx
#UUID_DISK_QUOTA="15G" # default '15G' is setupped in mibe_lib.sh, if you want to override it - uncomment and setup

ALIAS="forgejo"
PRIORITY="96"
MAC="12:33:40:a9:1d:${PRIORITY}"
RAM=4096 # default is 512

#define FILESYSTEMS <<-EOF
#	{"type": "lofs", "source": "/${DS_PKGSRC}", "target": "${DS_PKGSRC_MOUNTPOINT}"}
#EOF

#	"vfstab":	"storage.alexxlabs.com:/export/data  -  /data  nfs  -  yes  rw,bg,intr",
#
define CUSTOMER_METADATA <<-FF
	"forgejo_authorized_keys":	"$(/usr/bin/tr '\n' '$' < /usbkey/ssh/config.d/id_ed25519_router.pem.pub || echo 'key_not_exist')",
	"forgejo_pwd":	"${ALEXXLABS_PASS}",
FF

# ===== dataset declaration ("dataset", "quota", "mountpoint", "sharesmb") =====
#
# !!! setup 'sharesmb' of 'dataset_forgejo' to 'no' to prevent chown data folder to 'admin:staff'
# !!! in time of: /var/zoneinit/includes/989-datasets-smbshare.sh (inside the zone)
# !!! which breaks configuration files permissions
#
# and if change 'mountpoints' here, then also fix pathes inside zone definition:
# 	- /tank/mibe/repos/mi-alexxlabs-forgejo/copy/opt/alexxlabs/var/mdata-setup/includes/41-forgejo.sh [app.ini setup]
dataset_forgejo=("zones/alexxlabs/forgejo" "300G" "/opt/forgejo" "no")

# names of datasets, defined above, to process on VM operations: /tank/mibe/mibe_vm.sh
# (create, optional setup 'quota', 'mountpoint', 'sharesmb')
datasets_to_process=("dataset_forgejo")
