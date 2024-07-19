#!/usr/bin/env bash

readonly MODE=${1:-list}; shift

source ./mibe_lib.sh

create() {
	local REPO=${1:-base}

	# https://www.guidgenerator.com/online-guid-generator.aspx
	BUILD_ZONE_IMAGE_UUID=$(imgadm list -H name=${BASE_IMG_NAME} version=~${BASE_IMG_VERSION}| awk '{ print $1 }' | tail -1)
	BUILD_ZONE_UUID="b765ae6c-4891-4793-941d-01dc24b2d845" # UUID of seed zone
	BUILD_ZONE_MAC="12:33:40:a9:1d:00" # mac address of seed zone to obtain the same IP from DHCP

	# alexxlabs-base:	(must exists) based on BASE_IMG_NAME@BASE_IMG_VERSION
	# others:			(must exists) based on alexxlabs-base@version [BASE_IMG_ALEXXLABS_UUID]
	#
	BASE_IMG_ALEXXLABS_UUID="d8d6cce2-426d-11ef-9986-0cc47aabb682"
	#
	[[ "x${REPO}" != "xbase" ]] \
		&& BUILD_BASE_UUID="${BASE_IMG_ALEXXLABS_UUID}" \
		|| BUILD_BASE_UUID="${BUILD_ZONE_IMAGE_UUID}"

	print "creating ${REPO} image (from mi-alexxlabs-${REPO} repo) based on ${BUILD_BASE_UUID}"

	[[ -d "${CURR_DIR}/repos/mi-alexxlabs-${REPO}" ]] \
		&& cd "${CURR_DIR}/repos" \
		|| die "${CURR_DIR}/repos/mi-alexxlabs-${REPO} not exist..."

	if imgadm get ${BUILD_BASE_UUID} >/dev/null 2>&1; then
		print "base image found, continuing..."
	else
		die "Image ${BUILD_BASE_UUID} not exists. Terminating..."
	fi

	if zoneadm -z ${BUILD_ZONE_UUID} list >/dev/null 2>&1; then
		print "seedz exist, continuing..."
	else
		print "Creating seedz:"
		# resolvers				: List of resolvers to be put into /etc/resolv.conf
		# maintain_resolvers	: Resolvers in /etc/resolv.conf will be updated when updating the 'resolvers' property.
		# "max_physical_memory": 10240,
		vmadm create <<-EOF
		{
			"brand": "joyent",
			"alias": "seedz",
			"hostname": "seedz.${DNS_DOMAIN}",
			"dns_domain": "${DNS_DOMAIN}",
			"image_uuid": "${BUILD_ZONE_IMAGE_UUID}",
			"uuid": "${BUILD_ZONE_UUID}",
			"maintain_resolvers": true,
			"resolvers": ${DNS_RESOLVERS},
			"ram": 10240,
			"max_physical_memory": 10240,
			"max_swap": 10240,
			"nics": [{
				"nic_tag": "admin",
				"interface": "net0",
				"ips": ["dhcp", "addrconf"],
				"primary": true,
				"mac": "${BUILD_ZONE_MAC}"
			}]
		}
		EOF
	fi

	# Usage: build_smartos  BUILD_BASE_UUID BUILD_ZONE_UUID BUILD_REPO
	# Arguments:
	#	BUILD_BASE_UUID	Build image to use for base of the image.
	#					This image must already exist in the ZFS hierarchy.
	#	BUILD_ZONE_UUID	Build zone to use for building out the image.
	#					The UUID of a zone that is already installed and running.
	#	BUILD_REPO		Build repository to use which contains the necessary build files for the image.
	build_smartos "${BUILD_BASE_UUID}" "${BUILD_ZONE_UUID}" "mi-alexxlabs-${REPO}"
	#
	#print "Stopping and deleting seed_zone: ${BUILD_ZONE_UUID}"
	#vmadm stop ${BUILD_ZONE_UUID}
	#vmadm delete ${BUILD_ZONE_UUID}
}

case ${MODE} in
	list)		imgadm list -o uuid,name,version,type,pub,size -s name,version| grep -v docker-layer; exit ;;
	create)		create "$@"; exit ;;
	*)			print "uncknown mode: ${MODE}"; exit ;;
esac
