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

# dataset declaration ("dataset", "dataset_quota", "dataset_mountpoint", "sharesmb")
dataset_pkgsrc=("zones/alexxlabs/pkgsrc" "300G" "/data/packages/SmartOS/trunk/x86_64/All" "no")

# names of datasets, defined above, to process (create, optional setup 'quota', 'mountpoint', 'sharesmb')
datasets_to_process=("dataset_pkgsrc")


#define CUSTOMER_METADATA <<-FF
#	"vfstab":	"storage.alexxlabs.com:/export/data  -  /data  nfs  -  yes  rw,bg,intr",
#FF

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

	datasets_to_mount=$(mdata-get datasets_to_mount)
	[ -z ${datasets_to_mount} ] || 
	for dataset in "${datasets_to_mount[@]}"; do
		# if need to change mountpoint, change it
		ds_mountpoint_to_set=$(zfs get -H -o "value" com.alexxlabs:mountpoint ${dataset})
		[[ "x${ds_mountpoint_to_set}" != "x-" ]] \
			&& [[ "x${ds_mountpoint_to_set}" != "xdefault" ]] \
				&& zfs set mountpoint=${ds_mountpoint_to_set} ${dataset}
	done

FF
