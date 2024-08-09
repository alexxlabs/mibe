BASED_ON_NAME="alexxlabs-pgsql"
BASED_ON_VERSION="20240116.1"
IMAGE_UUID=$(imgadm list -H name=${BASED_ON_NAME} version=~${BASED_ON_VERSION}| awk '{ print $1 }' | tail -1)

UUID="e6819cf0-4678-11ef-bfd4-123340a91d97" # unique
#
# default '15G' is setupped in mibe_lib.sh
# if you want to override it - uncomment and setup
#UUID_DISK_QUOTA="15G"

ALIAS="backup.pgsql"
PRIORITY="95"
MAC="12:33:40:a9:1d:${PRIORITY}"
RAM=2048 # default is 512

#define FILESYSTEMS <<-EOF
#	{"type": "lofs", "source": "/${DS_PKGSRC}", "target": "${DS_PKGSRC_MOUNTPOINT}"}
#EOF

# psql_init_db: if 'yes', then initialize PG Database
# ( see: mi-alexxlabs-pgsql/copy/var/zoneinit/includes/31-postgresql.sh )
#
define CUSTOMER_METADATA <<-FF
	"root_known_hosts":				"pgsql.alexxlabs.com",
	"psql_postgres_pwd":			"${ALEXXLABS_PASS}",

	"psql_role":					"backup",
	"psql_role_backup_main_host":	"pgsql.alexxlabs.com",
FF

# ===== dataset declaration ("dataset", "quota", "mountpoint", "sharesmb") =====
#
# !!! setup 'sharesmb' of 'dataset_pgsql' to 'no' to prevent chown data folder to 'admin:staff'
# !!! in time of: /var/zoneinit/includes/989-datasets-smbshare.sh (inside the zone)
# !!! which breaks database files permissions
#
# !!! and do not AT ALL share ANY 'zfs' by smb inside this zone, because attempt to share something
# !!! inside 'pgsql' zone gives error of service: svc:/system/idmap:default ( do not know - why !!! )
# 	Error creating database /var/idmap/idmap.db (malformed database schema - unable to open a temporary database file for storing temporary tables)
# 	Failed to initialize db /var/idmap/idmap.db
# 	unable to initialize mapping system
# TODO: try to share on NEXT alexxlabs-base version ( based on next 'minimal-64-trunk' ), maybe something change !!!
#
# TODO: zfs allow -dl root mount,create,rename,snapshot,receive tank/pgsql_backup_server
#
# and if change 'mountpoints' here, then also fix pathes inside zone definition:
# 	- /tank/mibe/repos/mi-alexxlabs-pgsql/copy/var/zoneinit/includes/31-postgresql.sh
dataset_pgsql=("tank/pgsql_backup_server" "300G" "/var/pgsql/data" "no")

# names of datasets, defined above, to process on VM operations: /tank/mibe/mibe_vm.sh
# (create, optional setup 'quota', 'mountpoint', 'sharesmb')
datasets_to_process=("dataset_pgsql")
