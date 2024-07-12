#!/usr/bin/env bash

# set variables 
declare -r TRUE=0
declare -r FALSE=1
declare -r PASSWD_FILE=/etc/passwd

PROGRAM=$(basename "$0")
ME=${0##*/svc-} # get current script name with full path

export TERM=xterm

RED="$(tput setaf 1)"
GREEN="$(tput setaf 2)"
WHITE="$(tput setaf 7)"
CYAN="$(tput setaf 6)"
UNDERLINE="$(tput sgr 0 1)"
BOLD="$(tput bold)"
NOCOLOR="$(tput sgr0)"

function header() { echo -e "$UNDERLINE$CYAN$1$NOCOLOR\n"; }
function error() { echo -e "$UNDERLINE$RED$1$NOCOLOR\n"; }


define(){ IFS='\n' read -r -d '' ${1} || true; } # for heredoc to variable
# define heredoc_var <<-EOL
# EOL

# helper function to log arbitrary messages via syslog
function log() {
    logger -p daemon.notice -t $ME $@
}

##################################################################
# Purpose: Display an error message and die
# Arguments:
#   $1 -> Message
#   $2 -> Exit status (optional)
##################################################################
#function die {
#    local m="$1"	# message
#    local e=${2-1}	# default exit status 1
#   	echo
#    error "$m" 
#    exit $e
#}
##################################################################
# Purpose: Converts a string to lower case
# Arguments:
#   $1 -> String to convert to lower case
##################################################################
function to_lower() {
    local str="$@"
    local output     
    output=$(tr '[A-Z]' '[a-z]'<<<"${str}")
    echo $output
}

##################################################################
# Purpose: Return true if script is executed by the root user
# Arguments: none
# Return: True or False
#
# Example:
#   is_root && echo "You are logged in as root." || echo "You are not logged in as root."
##################################################################
function is_root {
    [ $(id -u) -eq 0 ] && return $TRUE || return $FALSE
}

##################################################################
# Purpose: Return true if $user exits in /etc/passwd
# Arguments: $1 (username) -> Username to check in /etc/passwd
# Return: True or False
#
# Example:
#   is_user_exits "alexx" && echo "user alexx exists." || echo "user alexx NOT exists."
##################################################################
function is_user_exits {
    local u="$1"
    grep -q "^${u}" $PASSWD_FILE && return $TRUE || return $FALSE
}

##################################################################
function load_usbkey_vars {
    ## Load configuration information from USBKey
    . /lib/svc/share/smf_include.sh
    . /lib/sdc/config.sh
    load_sdc_sysinfo
    load_sdc_config
}

# verbose ln, because `ln -v` is not portable
symlink() {
	printf '%55s -> %s\n' "${1/#$HOME/~}" "${2/#$HOME/~}"
	ln -nsf "$@"
}

print() {
    echo -e "\n\033[1m> ${1}\033[0m\n"
}

# print the script name and all arguments to stderr:
#   $0 is the path to the script ;
#   $* are all arguments.
#   >&2 means > redirect stdout to & pipe 2. pipe 1 would be stdout itself.
yell() { error "$0: $*" >&2; }

# does the same as yell, but exits with a non-0 exit status, which means “fail”.
die() { yell "$*"; exit 111; }

# try uses the || (boolean OR), which only evaluates the right side if the left one failed.
#   $@ is all arguments again, but different.
try() { "$@" || die "cannot $*"; }
# Example usage:
# try apt-fast upgrade -y
# try asuser vagrant "echo 'uname -a' >> ~/.profile"

asuser() { sudo su - "$1" -c "${*:2}"; }