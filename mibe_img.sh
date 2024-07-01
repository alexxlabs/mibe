#!/usr/bin/env bash

readonly MODE=${1:-list}; shift

source ./mibe_lib.sh

create() {
	local REPO=${1:-base}

	# https://www.guidgenerator.com/online-guid-generator.aspx
	# seed zone always created from current minimal-64 image
	#BUILD_ZONE_IMAGE_UUID="1a45657e-37c9-4b50-b070-c55d90054984" # minimal-64-trunk@20240116 image - must exists
	BUILD_ZONE_IMAGE_UUID=$(imgadm avail name=${BASE_IMG_NAME} version=~${BASE_IMG_VERSION})
	BUILD_ZONE_UUID="b765ae6c-4891-4793-941d-01dc24b2d845" # UUID of seed zone
	BUILD_ZONE_MAC="12:33:40:a9:1d:69" # mac address of seed zone to obtain the same IP from DHCP

	# base:		based on minimal-64-trunk@20240116 image - must exists
	# others:	based on alexxlabs-base@20240116 image - must exists
	[[ "x${REPO}" != "xbase" ]] \
		&& BUILD_BASE_UUID="010ffe0e-3486-11ef-8ac0-0cc47aabb682" \
		|| BUILD_BASE_UUID="${BUILD_ZONE_IMAGE_UUID}"

	[[ -d "${CURR_DIR}/repos/mi-alexxlabs-${REPO}" ]] \
		&& cd "${CURR_DIR}/repos" \
		|| die "${CURR_DIR}/repos/mi-alexxlabs-${REPO} not exist..."

	if imgadm get ${BUILD_BASE_UUID} >/dev/null 2>&1; then
		print "base image found, continuing..."
	else
		die "Image ${BUILD_BASE_UUID} not exists. Terminating..."
	fi
	if zoneadm -z ${BUILD_ZONE_UUID} list >/dev/null 2>&1; then
		print "Build Zone ${BUILD_ZONE_UUID} exist, continuing..."
	else
		print "Creating Build zone:"
		vmadm create <<-EOF
		{
			"brand": "joyent",
			"alias": "buildz",
			"hostname": "buildz.${DNS_DOMAIN}",
			"dns_domain": "${DNS_DOMAIN}",
			"image_uuid": "${BUILD_ZONE_IMAGE_UUID}",
			"uuid": "${BUILD_ZONE_UUID}",
			"max_physical_memory": 512,
			"resolvers": ${DNS_RESOLVERS},
			"customer_metadata": {
				"export:logs_mount" : "${LOGS_MOUNT}"
			},
			"nics": [{
				"nic_tag": "admin",
				"interface": "net0",
				"ips": ["dhcp"],
				"primary": true,
				"mac": "${BUILD_ZONE_MAC}"
			}]
		}
		EOF
	fi
	# Usage: build_smartos  BUILD_BASE BUILD_ZONE BUILD_REPO
	# Arguments:
	#	BUILD_BASE_UUID	Build image to use for base of the image. This image
	#					must already exist in the ZFS hierarchy.
	#					e.g. b23882cc-3d9e-11e3-aa2f-83b8d8746936
	#	BUILD_ZONE_UUID	Build zone to use for building out the image.  The
	#					UUID of a zone that is already installed and running.
	#					e.g. b23882cc-3d9e-11e3-aa2f-83b8d8746936
	#	BUILD_REPO		Build repository to use which contains the necessary
	#					build files for the image.
	#					e.g. mi-alexxlabs-base
	build_smartos "${BUILD_BASE_UUID}" "${BUILD_ZONE_UUID}" "mi-alexxlabs-${REPO}"
	#print "Stopping and deleting seed_zone: ${BUILD_ZONE_UUID}"
	#vmadm stop ${BUILD_ZONE_UUID}
	#vmadm delete ${BUILD_ZONE_UUID}
}

case ${MODE} in
	list)		imgadm list -o uuid,name,version,type,pub,size -s name,version| grep -v docker-layer; exit ;;
	#validate) echo ${bhyve_create_json}| jq . | vmadm validate create; exit ;;
	#create)   echo ${bhyve_create_json}| jq . | vmadm create; exit ;;
	#delete)   vmadm delete ${UUID} ; exit ;;
	#start)    vmadm start ${UUID} ; exit ;;
	#stop)     vmadm stop ${UUID} ; exit ;;
	create)		create "$@"; exit ;;
	#log)      cat /zones/${UUID}/logs/platform.log ; exit ;;
	#console)  vmadm console ${UUID} ; exit ;;
	#zlogin)   zlogin -C ${UUID} ; exit ;;
	*)			print "uncknown mode: ${MODE}"; exit ;;
esac
