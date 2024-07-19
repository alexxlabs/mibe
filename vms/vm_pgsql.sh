BASED_ON_NAME="alexxlabs-pgsql"
BASED_ON_VERSION="20240116.1"
IMAGE_UUID=$(imgadm list -H name=${BASED_ON_NAME} version=~${BASED_ON_VERSION}| awk '{ print $1 }' | tail -1)
#IMAGE_UUID="" # or directly specify alexxlabs-base@20240116.1 uuid

UUID="50989332-4197-11ef-84a2-0cc47aabb682" # unique: https://www.guidgenerator.com/online-guid-generator.aspx
#UUID_DISK_QUOTA="15G" # default '15G' is setupped in mibe_lib.sh, if you want to override it - uncomment and setup

ALIAS="pgsql"
PRIORITY="97"
MAC="12:33:40:a9:1d:${PRIORITY}"
RAM=2048 # default is 512

#define FILESYSTEMS <<-EOF
#	{"type": "lofs", "source": "/${DS_PKGSRC}", "target": "${DS_PKGSRC_MOUNTPOINT}"}
#EOF

#	"vfstab":	"storage.alexxlabs.com:/export/data  -  /data  nfs  -  yes  rw,bg,intr",
#
# psql_init_db: if 'yes', then initialize PG Database
# ( see: mi-alexxlabs-pgsql/copy/var/zoneinit/includes/31-postgresql.sh )
#
define CUSTOMER_METADATA <<-FF
	"psql_postgres_pwd":	"${ALEXXLABS_PASS}",
	"psql_init_db":			"no",
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
# and if change 'mountpoints' here, then also fix pathes inside zone definition:
# 	- /tank/mibe/repos/mi-alexxlabs-pgsql/copy/var/zoneinit/includes/31-postgresql.sh
# 	- /tank/mibe/repos/mi-alexxlabs-pgsql/copy/opt/alexxlabs/bin/psql_backup
dataset_pgsql=("tank/pgsql" "300G" "/var/pgsql/data" "no")
dataset_pgsql_backups=("tank/pgsql_backups" "500G" "/var/backups/postgresql" "no")

# names of datasets, defined above, to process on VM operations: /tank/mibe/mibe_vm.sh
# (create, optional setup 'quota', 'mountpoint', 'sharesmb')
datasets_to_process=("dataset_pgsql" "dataset_pgsql_backups")
