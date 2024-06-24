#!/usr/bin/env bash

# parce parameters:
readonly MODE=${1:-list}; shift

source ./mibe_lib.sh

repo_init -g smartos mi-alexxlabs-empty