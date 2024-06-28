#!/usr/bin/env bash

readonly MODE=${1:-list}; shift

source ./mibe_lib.sh

create() {
}

case ${MODE} in
	list)		vmadm list -o tags.priority,uuid,state,alias,nics.0.mac -s tags.priority,nics.0.mac; exit ;;
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
