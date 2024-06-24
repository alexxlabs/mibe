#!/usr/bin/env bash

# parce parameters:
readonly REPO=${1:-base}; shift
#readonly PAR_2=${2:-master} # ; shift

source ./mibe_lib.sh

[[ -d "${CONFIG_DIR}/repos/${REPO}" ]] \
	&& cd "${CONFIG_DIR}/repos/${REPO}" \
	|| die "${CONFIG_DIR}/repos/${REPO} not exist..."