#!/usr/bin/env bash

readonly MODE=${1:-ls}; shift
readonly VM=${1:-test}; shift

source ./mibe_lib.sh

readonly VM_CURR="${VM_HOME}/vm_${VM}.sh"
[[ -f ${VM_CURR} ]] && print "sourcing ${VM_CURR}" && source ${VM_CURR} || die "${VM_CURR} not found..."

print "checking needed definitions."
echo ${IMAGE_UUID:?"variable not set in ${VM_CURR}"}>/dev/null 2>&1
echo ${UUID:?"variable not set in ${VM_CURR}"}>/dev/null 2>&1
echo ${PRIORITY:?"variable not set in ${VM_CURR}"}>/dev/null 2>&1
echo ${ALIAS:?"variable not set in ${VM_CURR}"}>/dev/null 2>&1
echo ${MAC:?"variable not set in ${VM_CURR}"}>/dev/null 2>&1

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
#
# prepare datasets and setup 'datasets_to_mount' for future use (see below)
datasets_to_mount=()
for arrayName in "${datasets_to_process[@]}"; do
	# creates a nameref variable ref whose value is the variable name passed as the first argument
	declare -n array="$arrayName"
	ds="${array[0]}"
	ds_quota="${array[1]:-no}"
	ds_mountpoint="${array[2]:-default}"
	ds_sharesmb="${array[3]:-no}"
	echo -n ">>> processing ${ds} ... "
	ds_exists=$(zfs list -H -o name| grep "${ds}")
	[[ "x${ds_exists}" != "x" ]] && echo "exists." || (echo "not exists, create it." && zfs create ${ds})
	[[ "x${ds_quota}" != "xno" ]] && echo ">>> set quota of ${ds} to ${ds_quota}" && zfs set quota="${ds_quota}" ${ds}
	echo ">>> set xattr of ${ds} to off" && zfs set xattr=off ${ds}
	echo ">>> set atime of ${ds} to off" && zfs set atime=off ${ds}
	echo ">>> set compression of ${ds} to lz4" && zfs set compression=lz4 ${ds}
	# we use 'com.alexxlabs:mountpoint' inside zone in '989-datasets-smbshare.sh' to actually setup 'mountpoint'
	if [[ "x${ds_mountpoint}" != "xdefault" ]]; then
		ds_mountpoint_to_set=$(zfs get -H -o "value" com.alexxlabs:mountpoint ${ds})
		# if com.alexxlabs:mountpoint was previously setupped, do not setup again
		if [[ "x${ds_mountpoint_to_set}" == "x-" ]]; then
			echo ">>> set com.alexxlabs:mountpoint of ${ds} dataset to ${ds_mountpoint}"
			echo ">>> for future setup actual mountpoint inside zone."
			zfs set com.alexxlabs:mountpoint=${ds_mountpoint} ${ds}
		fi
	fi
	# we use 'com.alexxlabs:sharesmb' inside zone in '989-datasets-smbshare.sh' to actually share
	ds_sharesmb_to_set=$(zfs get -H -o "value" com.alexxlabs:sharesmb ${ds})
	# if com.alexxlabs:mountpoint was previously setupped, do not setup again
	if [[ "x${ds_sharesmb_to_set}" == "x-" ]]; then
		echo ">>> set com.alexxlabs:sharesmb of ${ds} dataset to ${ds_sharesmb}"
		echo ">>> for future setup share by smb inside zone."
		zfs set com.alexxlabs:sharesmb=${ds_sharesmb} ${ds}
	fi
	datasets_to_mount+=("${ds}") # add 'ds' to array to pass to 'vm_create_json'
done

define_vm_create_json() {
	# ************* README Notes *****************
	# If you have set the indestructible_zoneroot or indestructible_delegated
	# flags on a VM it *cannot* be deleted until you have unset these flags with something like:
	#   vmadm update UUID indestructible_zoneroot=false
	#   vmadm update UUID indestructible_delegated=false
	# to remove the snapshot and holds.
	# -------------------------------------------------------------------------
	# "maintain_resolvers": true - allows to update resolvers thru vmadm update
	# -------------------------------------------------------------------------
	# to verify New DNS Server(s) use command: dig @10.2.0.1 A
	# -------------------------------------------------------------------------
	# The "limit_priv: +proc_clock_highres" line is important for NTPD,
	# it allows for: higher resolution timers to be used,
	# ntpd to change its niceness, ntpd to change the hw clock.
	#
	# README for manifest parameters: https://blog.brianewell.com/smartos-manifests/
	#
	# !!! putting 'id_rsa_key', 'authorized_keys' into VM metadata and extracting it inside VM breaks newlines
	# so - we replace newlines by $ symbol before putting it into metadata
	#ID_RSA_ALL_PUB=$(/usr/bin/tr '\n' '$' < /usbkey/ssh/config.d/id_ed25519_${ALIAS-:uncknown}.pem.pub || echo "key_not_exist")
	# and after getting it inside VM replace $ symbol with newlines - so we get correct newlines inside VM
	#root_authorized_keys=$(/usr/sbin/mdata-get system:root_authorized_keys| /usr/bin/tr '$' '\n' || echo "no_key")

	# If mdata is set we update the host keys, else we will get the
	# host keys from the filesystem and set the mdata information
	#	"ssh_host_rsa_key":			"private SSH rsa key for the host daemon",
	#	"ssh_host_rsa_key.pub":		"public SSH rsa key for the host daemon",
	#	"ssh_host_dsa_key":			"private SSH dsa key for the host daemon",
	#	"ssh_host_dsa_key.pub":		"public SSH dsa key for the host daemon",
	#	"ssh_host_ed25519_key":		"private SSH ed25519 key for the host daemon",
	#	"ssh_host_ed25519_key.pub":	"public SSH ed25519 key for the host daemon",
	#
	# from nics: "mtu": "${CONFIG_admin_mtu:-1500}"
	define vm_create_json <<-EOL
	{
		"brand": "joyent",
		"image_uuid": "${IMAGE_UUID}",
		"uuid": "${UUID}",
		"autoboot": false,
		"tags" : {"priority": "${PRIORITY}"},
		"alias": "${ALIAS}",
		"hostname": "${ALIAS}.${DNS_DOMAIN}",
		"dns_domain": "${DNS_DOMAIN}",
		"delegate_dataset": "true",
		"indestructible_delegated": true,
		"limit_priv": "${LIMIT_PRIV:-default,+sys_time,+proc_priocntl,+proc_clock_highres}",
		"maintain_resolvers": true,
		"resolvers": ${DNS_RESOLVERS},
		"ram": ${RAM:-512},
		"max_physical_memory": ${RAM:-512},
		"max_swap": ${RAM:-512},
		"nics": [{
			"nic_tag": "admin",
			"interface": "net0",
			"ips": ["dhcp", "addrconf"],
			"primary": true,
			"mac": "${MAC}",
			"allow_ip_spoofing": true
		}],
		"filesystems": [${FILESYSTEMS}],
		"customer_metadata": {
			${CUSTOMER_METADATA}
			"datasets_to_mount":		"${datasets_to_mount[@]}",
			"gz_github_token":			"${gz_github_token}",

			"admin_authorized_keys":	"$(/usr/bin/tr '\n' '$' < /usbkey/ssh/config.d/id_ed25519.pem.pub	|| echo 'key_not_exist')",
			"root_authorized_keys":		"$(/usr/bin/tr '\n' '$' < /usbkey/ssh/config.d/id_ed25519.pem.pub	|| echo 'key_not_exist')",
			"root_ssh_ed25519":			"$(/usr/bin/tr '\n' '$' < /usbkey/ssh/config.d/id_ed25519.pem		|| echo 'key_not_exist')",
			"root_ssh_ed25519_pub":		"$(/usr/bin/tr '\n' '$' < /usbkey/ssh/config.d/id_ed25519.pem.pub	|| echo 'key_not_exist')",

			"mail_smarthost":			"${MTA_HOST}",
			"mail_auth_user":			"${MTA_MAILTO}",
			"mail_auth_pass":			"${ALEXXLABS_PASS}",
			"mail_adminaddr":			"${MTA_MAILTO}",

			"telegramm_bot_token":		"${telegramm_bot_token}",
			"telegramm_chat_id":		"${telegramm_chat_id}"
		}
	}
	EOL
}

zone_state() {
	#local ZONE_STATUS_STR=$(zoneadm -u "${UUID}" list -p || echo "")
	#local ZONE_STATE=$(echo "${ZONE_STATUS_STR}" | cut -d ":" -f 3 || echo "")
	ZONE_STATUS_STR=$(vmadm list -p| grep "${UUID}" || echo "x:x:x:stopped")
	ZONE_STATE=$(echo "${ZONE_STATUS_STR}" | cut -d ":" -f 4 || echo "")
	printf "${ZONE_STATE}"
}

vm_create() {
	[[ $(zone_state) == "running" ]] && die "zone ${UUID} is running. Please, check UUID"
	define_vm_create_json; echo ${vm_create_json}| jq . | vmadm create
	# setup zone space quota, if provided
	[[ "x${UUID_DISK_QUOTA}" != "x" ]] \
		&& print ">>> setup disk quota of ${UUID} to ${UUID_DISK_QUOTA}" \
		&& zfs set quota="${UUID_DISK_QUOTA}" "zones/${UUID}"

	# !!! Now use zonecfg to hand off the dataset to the zone and restart,
	# !!! note that the moment we do this the filesystem will be unmounted from the global zone.
	# !!! zone must exist and be in state 'stopped'
	[[ $(zone_state) != "stopped" ]] && die "zone ${UUID} is not in stopped state"

	# to mount, array of needed datasets MUST be nonempty
	[ -z ${datasets_to_mount} ] || 
	for dataset in "${datasets_to_mount[@]}"; do
		echo -n ">>> processing ${dataset} ... "
		ds_exists=$(zfs list -H -o name| grep "${dataset}")
		[[ "x${ds_exists}" == "x" ]] \
			&& echo "not exist" \
			|| 	echo "exists." \
				&& echo ">>> inherit 'sharenfs' prop of dataset ${dataset}" \
				&& zfs inherit sharenfs ${dataset} \
				&& echo ">>> inherit 'sharesmb' prop of dataset ${dataset}" \
				&& zfs inherit sharesmb ${dataset} \
				\
				&& echo ">>> mount ${dataset} under zone ${UUID}" \
				&& zonecfg -z ${UUID} "add dataset; set name=${dataset}; end; verify; commit"
	done
	#zonecfg -z ${UUID} "info dataset"
	# login to the zone again and you should see your dataset and mount point by running zfs list
}

# Zoned property
# You are probably wondering how to get your data back now, well it's actually quite easy,
# just stop the zone and revert the 'zoned' property on the dataset with
#       zfs inherit zoned {{dataset}}
#   and issue
#       zfs mount -a
#
# Below is a quote from the old Oracle docs that explains how to work with this flag effectively:
#   When a dataset is delegated to a non-global zone, the dataset must be specially marked so that certain properties are not
#   interpreted within the context of the global zone. After a dataset has been delegated to a non-global zone and is under
#   the control of a zone administrator, its contents can no longer be trusted. As with any file system, there might be setuid binaries,
#   symbolic links, or otherwise questionable contents that might adversely affect the security of the global zone.
#   In addition, the mountpoint property cannot be interpreted in the context of the global zone.
#   Otherwise, the zone administrator could affect the global zone's namespace. To address the latter,
#   ZFS uses the 'zoned' property to indicate that a dataset has been delegated to a non-global zone at one point in time.

#   When a dataset is removed from a zone or a zone is destroyed, the 'zoned' property is not automatically cleared.
#   This behavior is due to the inherent security risks associated with these tasks. Because an untrusted user has had
#   complete access to the dataset and its descendents, the mountpoint property might be set to bad values,
#   or setuid binaries might exist on the file systems.
#   To prevent accidental security risks, the 'zoned' property must be manually cleared by the global zone administrator
#   if you want to reuse the dataset in any way. Before setting the 'zoned' property to off, ensure that the mountpoint
#   property for the dataset and all its descendents are set to reasonable values and that no setuid binaries exist,
#   or turn off the setuid property.

#   After you have verified that no security vulnerabilities are left, the 'zoned' property can be turned off by using
#   the zfs set or zfs inherit command. If the 'zoned' property is turned off while a dataset is in use within a zone,
#   the system might behave in unpredictable ways. Only change the property if you are sure the dataset is no longer
#   in use by a non-global zone.
vm_ds_ls() {
	[[ $(zone_state) != "running" ]] && die "!!! we CAN see changes AFTER starting the zone !!!"
	#zfs get zoned ${datasets_to_mount[@]}
	# to list, array of needed datasets MUST be nonempty
	[ -z ${datasets_to_mount} ] || 
	for dataset in "${datasets_to_mount[@]}"; do
		echo -n ">>> processing ${dataset} ... "
		ds_exists=$(zfs list -H -o name| grep "${dataset}")
		[[ "x${ds_exists}" == "x" ]] \
			&& echo "not exist" \
			|| echo "exist" && zfs get -H zoned ${dataset}
	done
}

zrun() {
	local param="${1:-INIT}"

	# get script name to run from GZ
	local script_name="VM_SETUP_FROM_GZ_"${param^^} # caps-lock param
	[[ "x${!script_name}" != "x" ]] \
		&& print "running ${script_name}" \
		&& /bin/bash -c "${!script_name}"

	# get script name to run inside zone
	script_name="VM_SETUP_INSIDE_"${param^^} # caps-lock param
	# get content of value ${script_name} => ${!script_name}
	# and run it inside zone (this works in 'bash' - not in 'sh')
	[[ "x${!script_name}" != "x" ]] \
		&& print "running ${script_name}" \
		&& (zlogin ${UUID} /bin/bash -c "${!script_name}") \
		|| die "${script_name} not defined or is empty"
}

vm_delete() {
	[[ $(zone_state) == "running" ]] && print "stopping VM ${UUID}." && vmadm stop ${UUID}
	#[[ $(zone_state) != "stopped" ]] && die "zone ${UUID} is not in stopped state"
	# to inherit, array of needed datasets MUST be nonempty
	[ -z ${datasets_to_mount} ] || 
	for dataset in "${datasets_to_mount[@]}"; do
		echo -n ">>> processing ${dataset} ... "
		ds_exists=$(zfs list -H -o name| grep "${dataset}")
		[[ "x${ds_exists}" == "x" ]] \
			&& echo "not exist" \
			|| echo "exist" \
				&& echo ">>> inherit 'zoned' prop of dataset ${dataset}" \
				&& zfs inherit zoned ${dataset} \
				&& echo ">>> inherit 'mountpoint' prop of dataset ${dataset}" \
				&& zfs inherit mountpoint ${dataset} \
				&& echo ">>> inherit 'com.alexxlabs:mountpoint' prop of dataset ${dataset}" \
				&& zfs inherit -r com.alexxlabs:mountpoint ${dataset} \
				&& echo ">>> inherit 'com.alexxlabs:sharesmb' prop of dataset ${dataset}" \
				&& zfs inherit -r com.alexxlabs:sharesmb ${dataset} # If the property is not defined in any parent dataset, it is removed entirely.
	done
	zfs mount -a
	print ">>> updating indestructible_delegated=false for VM ${UUID}."
	vmadm update ${UUID} indestructible_delegated=false
	print ">>> deleting VM ${UUID}."
	vmadm delete ${UUID}
}

case ${MODE} in
	create)		vm_create ; exit ;;
	ds_ls)		vm_ds_ls "$@"; exit ;;
	delete)		vm_delete ; exit ;;
	start)		[[ $(zone_state) == "stopped" ]] && vmadm start ${UUID} || print "zone is already running..."; exit ;;
	setup)		[[ $(zone_state) == "running" ]] && zrun "$@" || print "zone is not running..."; exit ;;
	stop)		[[ $(zone_state) == "running" ]] && vmadm stop ${UUID} || print "zone is not running..."; exit ;;
	ls)			define_vm_create_json; echo ${vm_create_json}| jq .; exit ;;
	validate)	define_vm_create_json; echo ${vm_create_json}| jq . | vmadm validate create; exit ;;
	mem)		[[ $(zone_state) == "running" ]] && zonememstat -z ${UUID} || print "zone is not running..."; exit ;;
	log)		cat /zones/${UUID}/logs/platform.log ; exit ;;
	zlogin)		[[ $(zone_state) == "running" ]] && zlogin ${UUID} || print "zone is not running..."; exit ;;
	*)			print "uncknown mode: ${MODE}"; exit ;;
esac
