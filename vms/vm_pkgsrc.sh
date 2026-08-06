BASED_ON_NAME="pkgbuild-lts"
BASED_ON_VERSION="24.4.1"
IMAGE_UUID=$(imgadm list -H name=${BASED_ON_NAME} version=~${BASED_ON_VERSION}| awk '{ print $1 }' | tail -1)
#IMAGE_UUID="7c4e57a9-1273-40e2-8fcc-569fbbaf6d53" # or directly specify base image 'uuid'

UUID="638c15c8-3e76-11ef-9194-0cc47aabb682" # unique: https://www.guidgenerator.com/online-guid-generator.aspx
UUID_DISK_QUOTA="500G" # default '15G' is setupped in mibe_lib.sh, if you want to override it - uncomment and setup

ALIAS="pkgsrc"
PRIORITY="99"
MAC="12:33:40:a9:1d:${PRIORITY}"
RAM=25600 # in MB (default is 512)

#PKGSRC_SIGNED_MOUNTPOINT="/data/packages_signed"		# should start with '/data'
PKGSRC_SIGNED_MOUNTPOINT="/data/packages/SmartOS/trunk/x86_64/All"
PKGSRC_ALEXXLABS_MOUNTPOINT="/data/pkgsrc/alexxlabs"
LOFS_DIR="${VM_HOME}/vm_pkgsrc/lofs"

[[ -d "${LOFS_DIR}" ]] || die "${LOFS_DIR} not_exist"

define FILESYSTEMS <<-EOF
	{"type": "lofs", "source": "${LOFS_DIR}", "target": "/data/alexxlabs"},
	{"type": "lofs", "source": "/zones/alexxlabs/pkgsrc", "target": "${PKGSRC_SIGNED_MOUNTPOINT}"}
EOF

# 'GPG_KEY_ID' from mibe_lib.sh is used in:
# vms/vm_pkgsrc/lofs/pkgsrc_repo.sh -> repo_update()
# to prepare packages signing (need both - pub and private keys)
define CUSTOMER_METADATA <<-FF
	"root_known_hosts":				"router.alexxlabs.com",
	"PKGSRC_SIGNED_MOUNTPOINT":		"${PKGSRC_SIGNED_MOUNTPOINT}",
	"PKGSRC_ALEXXLABS_MOUNTPOINT":	"${PKGSRC_ALEXXLABS_MOUNTPOINT}",
FF

# dataset declaration ("dataset", "quota", "mountpoint", "sharesmb")
# - dataset		:
# - quota		:
# - mountpoint	:
# - sharesmb	: 'no' or 'user:group' to chown shared directory
#dataset_pkgsrc=("zones/alexxlabs/pkgsrc" "300G" "/data/packages/SmartOS/trunk/x86_64/All" "no")
# names of datasets, defined above, to process (create, optional setup 'quota', 'mountpoint', 'sharesmb')
#datasets_to_process=("dataset_pkgsrc")
datasets_to_process=()

custom_packages=(
	bmake				# for pkgsrc
	gmake				# for custom Makefile
	url2pkg				# install the pkgtools/url2pkg package, as this massively simplifies the task in hand.
	gnupg20				# !!! for signing packages	!!! it's important - NOT 'gnupg2', but 'gnupg20' !!!
						# - The version of GPG in the pkgbuild zone itself must be 'gnupg20'
						# - The version of GPG in the pkgbuild sandbox must be 'gnupg20'. This should be automatic.
						# - The version fo GPG that is importing the key into the pkgsrc.gpg keyring
						# - 	for the eventual target host doing the pkg_add must also be 'gnupg20'.
	gcc13				# for rust
	pkg-config			# for cargo installations
	lld					# for cargo installations
)
CUSTOM_PACKAGES="${custom_packages[@]}"

# =====================================================================================================
# because pkgsrc image is not based on our alexxlabs-base (with our initial setup procedure)
# provide some separate setup procedure for newly deployed 'pkgsrc'
#define VM_SETUP_FROM_GZ_INIT <<-FF
#	zoneroot="/zones/${UUID}/root"
#	[[ -f ${MI_HOME}/repos/mi-alexxlabs-base/copy/etc/ssh/sshd_config ]] \
#		&& echo "copy sshd_config inside zone: ${UUID}" \
#		&& cp ${MI_HOME}/repos/mi-alexxlabs-base/copy/etc/ssh/sshd_config \${zoneroot}/etc/ssh
#FF
#
#define VM_SETUP_INSIDE_INIT << 'FF'
#FF
