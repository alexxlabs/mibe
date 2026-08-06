#!/usr/bin/env bash

# !!! zone customization script
# !!! running from inside the zone by 'make vm customize <vm>'

PATH=":/usr/bin:/usr/sbin:/opt/local/bin:/opt/local/sbin:/data/alexxlabs/sbin"

print() { printf "\n\033[1;32m* [ %s ] %s\033[0m\n" "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" "${1}"; }

die() {
	printf '\033[1;31mERROR:\033[0m %s\n' "$@" >&2  # bold red
	exit 1
}

# if metadata exists, create variable with name as parameter, containing its value, or terminate
mdata-link-to-var() {
	variable=${1:-var1}
	mdata-get ${variable} 1>/dev/null 2>&1 \
		&& printf -v "$variable" "%s" "$(mdata-get ${variable})" \
		|| die "no metadata for: ${variable}"

	# Creating a string variable name from the value of another string
	#CONFIG_OPTION="VENDOR_NAME"
	#CONFIG_VALUE="Default_Vendor"
	#printf -v "$CONFIG_OPTION" "%s" "$CONFIG_VALUE"
	# Don't believe me?
	#echo "$VENDOR_NAME"
}

# Configure root ssh authorized_keys file if available via mdata
if mdata-get root_authorized_keys 1>/dev/null 2>&1; then
	mkdir -p /root/.ssh
	echo "# This file is managed by mdata-get root_authorized_keys" > /root/.ssh/authorized_keys
	# after getting key inside VM replace $ symbol with newlines - so we get correct newlines inside VM
	key=$(mdata-get root_authorized_keys| /usr/bin/tr "$" "\n" || echo "no_key")
	echo ${key} >> /root/.ssh/authorized_keys
	chmod 700 /root/.ssh
	chmod 644 /root/.ssh/authorized_keys
fi
# collect fingerprints for 'root_known_hosts'
if mdata-get root_known_hosts 1>/dev/null 2>&1; then
	home="/root"
	mkdir -p ${home}/.ssh
	echo "# This file is managed by mdata-get root_known_hosts" > ${home}/.ssh/known_hosts
	IFS=":"
	known_hosts=$(mdata-get root_known_hosts)
	for host in ${known_hosts:-router.alexxlabs.com}
	do
		ssh-keyscan -t ed25519 -p 58000 ${host} >> ${home}/.ssh/known_hosts || true
	done
fi
# restart sshd because we copy new 'sshd_config' inside zone
svcadm restart ssh

datasets_to_mount=$(mdata-get datasets_to_mount)
[ -z ${datasets_to_mount} ] || 
for dataset in "${datasets_to_mount[@]}"; do
	# if need to change mountpoint, change it
	ds_mountpoint_to_set=$(zfs get -H -o "value" com.alexxlabs:mountpoint ${dataset})
	[[ "x${ds_mountpoint_to_set}" != "x-" ]] \
		&& [[ "x${ds_mountpoint_to_set}" != "xdefault" ]] \
			&& zfs set mountpoint=${ds_mountpoint_to_set} ${dataset}
done

: ${PKGSRC_SIGNED_MOUNTPOINT:="/data/packages/SmartOS/trunk/x86_64/All"}
if mdata-get PKGSRC_SIGNED_MOUNTPOINT 1>/dev/null 2>&1; then
	PKGSRC_SIGNED_MOUNTPOINT="$(mdata-get PKGSRC_SIGNED_MOUNTPOINT)"
fi

print "* Use the qutic pkgsrc mirror..."
cat > /opt/local/etc/pkgin/repositories.conf <<-EOF_REPO
#
# Pkgin repositories list
# Simply add repositories URIs one below the other
# WARNING: order matters, duplicates will not be added, if two
# repositories hold the same package, it will be fetched from
# the first one listed in this file.
# This file format supports the following macros:
# \$arch to define the machine hardware platform
# \$osrelease to define the release version for the operating system
#
# Remote ftp repository
# ftp://ftp.netbsd.org/pub/pkgsrc/packages/NetBSD/\$arch/5.1/All
#
# Remote http repository
# http://mirror-master.dragonflybsd.org/packages/\$arch/DragonFly-\$osrelease/stable/All
#
# Local repository (must contain a pkg_summary.gz or bz2)
# file:///usr/pkgsrc/packages/All
#
# the rest of PKGSRC_SIGNED_MOUNTPOINT (without /data): https://pkgsrc.qutic.com${PKGSRC_SIGNED_MOUNTPOINT#*/data}

https://pkgsrc.qutic.com/packages/SmartOS/trunk/x86_64/All

EOF_REPO

# !!! add local file repo !!! must contain a pkg_summary.gz or bz2 - prepared by: 'make repo upsum' !!!
FILE="/opt/local/etc/pkgin/repositories.conf"
LINE="file://${PKGSRC_SIGNED_MOUNTPOINT}"
grep -qF -- "${LINE}" "${FILE}" || echo "${LINE}" >> "${FILE}"

STR_ORIG_START_WITH="PKG_PATH="
STR_REPL="PKG_PATH=https://pkgsrc.qutic.com/packages/SmartOS/trunk/x86_64/All"
sed -i.bak "s~^${STR_ORIG_START_WITH}.*~${STR_REPL}~" /opt/local/etc/pkg_install.conf # use '~' as sed separator

print "===> get latest updates..."
pkg_add -u pkg_install pkgin
pkg_admin rebuild
pkgin -f -y update && pkgin -y upgrade

print "===> installing basic packages:"
BASE_PACKAGES="@BASE_PACKAGES@" # replace happens in: 'mibe_vm.sh -> vm_customize()' by 'sed' tool
IFS=' ' # setting space as delimiter
# reading 'BASE_PACKAGES' string as an array of tokens, separated by IFS 
read -ra BASE_PACKAGES_ARR <<<"$BASE_PACKAGES"
for pkg in "${BASE_PACKAGES_ARR[@]}";  # accessing each element of array
do
	/opt/local/sbin/pkg_add -u ${pkg}
done

print "===> installing custom packages:"
CUSTOM_PACKAGES="@CUSTOM_PACKAGES@" # replace happens in: 'mibe_vm.sh -> vm_customize()' by 'sed' tool
for pkg in ${CUSTOM_PACKAGES}; do
	/opt/local/sbin/pkg_add -u ${pkg}
done

# -----------------------------------------------------------------------------------------------
# -----------------------------------------------------------------------------------------------
# -----------------------------------------------------------------------------------------------

print "*** git global configuration..."
# hint: You have divergent branches and need to specify how to reconcile them.
# hint: You can do so by running one of the following commands sometime before
# hint: your next pull:
# hint:
# hint:   git config pull.rebase false  # merge
# hint:   git config pull.rebase true   # rebase
# hint:   git config pull.ff only       # fast-forward only
# hint:
# hint: You can replace "git config" with "git config --global" to set a default
# hint: preference for all repositories. You can also pass --rebase, --no-rebase,
# hint: or --ff-only on the command line to override the configured default per invocation.
#git config --global pull.rebase false	# merge
git config --global pull.rebase true	# rebase
#git config --global pull.ff only		# fast-forward only
#
git config --global user.name "Alexander Kalin"
git config --global user.email alexander.kalin@gmail.com
#
git config --global core.fileMode false	# The default is true (when core.filemode is not specified in the config file).
git config --global core.autocrlf input	# this setting give you CRLF-end on Windows and LF-end on Mac, Linux, and repo

mdata-link-to-var "gz_github_token"
# see details on: https://coolaj86.com/articles/vanilla-devops-git-credentials-cheatsheet/
git config --system url."https://api:${gz_github_token}@github.com/".insteadOf "https://github.com/"
git config --system url."https://ssh:${gz_github_token}@github.com/".insteadOf "ssh://git@github.com/"
git config --system url."https://git:${gz_github_token}@github.com/".insteadOf "git@github.com:"

# -----------------------------------------------------------------------------------------------
# -----------------------------------------------------------------------------------------------
# -----------------------------------------------------------------------------------------------

homedir_rustup="/opt/rustup" && mkdir -p ${homedir_rustup}
homedir_cargo="/opt/cargo" && mkdir -p ${homedir_cargo}
cargo_target_directory="/opt/cargo_tmp" && mkdir -p ${cargo_target_directory}
cargo_install_root="/opt/local" && mkdir -p ${cargo_install_root}

# global cargo config
# https://blog.pnkfx.org/blog/2022/05/12/linking-rust-crates/
#
cat > ${homedir_cargo}/config.toml <<-EOF
[build]
target = "x86_64-unknown-illumos"

[target.x86_64-unknown-illumos]

linker = "gcc"
ar = "gcc-ar"

#linker = "x86_64-sun-solaris2.11-gcc"
#ar = "x86_64-sun-solaris2.11-gcc-ar"

EOF

# add some parameters
FILE="/root/.profile"
if [[ -f ${FILE} ]]; then

	LINE="export PATH=\${PATH}:/data/alexxlabs/sbin" && grep -qF -- "${LINE}" "${FILE}" || echo "${LINE}" >> "${FILE}"

	LINE="export TZ=Europe/Chisinau" && grep -qF -- "${LINE}" "${FILE}" || echo "${LINE}" >> "${FILE}"
	LINE="export LANG=en_US.UTF-8" && grep -qF -- "${LINE}" "${FILE}" || echo "${LINE}" >> "${FILE}"

	LINE="export RUSTUP_HOME=${homedir_rustup}" && grep -qF -- "${LINE}" "${FILE}" || echo "${LINE}" >> "${FILE}"

	# Cargo can also be configured through environment variables in addition to the TOML configuration files.
	# For each configuration key of the form foo.bar the environment variable CARGO_FOO_BAR can also be used
	# to define the value. Keys are converted to uppercase, dots and dashes are converted to underscores.
	# For example the target.x86_64-unknown-linux-gnu.runner key can also be defined by the
	# CARGO_TARGET_X86_64_UNKNOWN_LINUX_GNU_RUNNER environment variable.
	# !!! Environment variables will take precedence over TOML configuration files. 
	#
	LINE="export CARGO_HOME=${homedir_cargo}" && grep -qF -- "${LINE}" "${FILE}" || echo "${LINE}" >> "${FILE}"
	LINE="export CARGO_TARGET_DIR=${cargo_target_directory}" && grep -qF -- "${LINE}" "${FILE}" || echo "${LINE}" >> "${FILE}"
	LINE="export CARGO_INSTALL_ROOT=${cargo_install_root}" && grep -qF -- "${LINE}" "${FILE}" || echo "${LINE}" >> "${FILE}"
	LINE="export CARGO_TARGET_WASM32_UNKNOWN_UNKNOWN_LINKER=lld" && grep -qF -- "${LINE}" "${FILE}" || echo "${LINE}" >> "${FILE}"
	#
	# If this is true, then Cargo will use the git executable to fetch registry indexes and git dependencies.
	# If false, then it uses a built-in git library.
	# Setting this to true can be helpful if you have special authentication requirements that Cargo does not support.
	LINE="export CARGO_NET_GIT_FETCH_WITH_CLI=true" && grep -qF -- "${LINE}" "${FILE}" || echo "${LINE}" >> "${FILE}"

	# and replace existing: REMOTE_PACKAGE_URL
	# with: 	export REMOTE_PACKAGE_URL="https://pkgsrc.qutic.com/packages"
	STR_ORIG_START_WITH="export REMOTE_PACKAGE_URL="
	STR_REPL="export REMOTE_PACKAGE_URL=\"https://pkgsrc.qutic.com/packages\""
	sed -i.bak "s~^${STR_ORIG_START_WITH}.*~${STR_REPL}~" ${FILE} # use '~' as sed separator
else
	echo ">>> file: ${FILE} not found, skipping configuration."
fi

cat > /root/.bashrc <<-'EOBASHRC'
alias cls="clear"
alias ls='ls --color=auto --full-time -la'

ga() {
	git add . --all
}

gs() {
	git status --untracked-files=all
}

gcomm() {
	git add . --all
	git commit -m "${1:-empty-commit}"
	git push
}

# tells us, which apps is using port
inuse() {
	PORT="${1:-443}"
	for PID in /proc/*;
	do
		pfiles \${PID}| grep "port: ${PORT}" \
			&& pfiles \${PID}| head -n 1 \
			&& echo "---------------------------------"
	done
}
# ------------------------------------------------------------------
git_branch() {
	git branch 2> /dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/(\1)/'
}

function set_prompt_line {
	local GREEN="\[\033[0;32m\]"
	local LIGHT_GREEN="\[\033[1;32m\]"
	local DEFAULT="\[\033[0m\]"
	export PS1="$GREEN[\$(uptime| awk -F, '{sub(\".*up \",x,\$1);print \$1}')] \w $LIGHT_GREEN\$(git_branch)$DEFAULT\\$ "
}

set_prompt_line
uname -a

[[ -d /data/alexxlabs ]] && cd /data/alexxlabs

EOBASHRC

: ${PKGSRC_ALEXXLABS_MOUNTPOINT:="/data/pkgsrc/alexxlabs"}
if mdata-get PKGSRC_ALEXXLABS_MOUNTPOINT 1>/dev/null 2>&1; then
	PKGSRC_ALEXXLABS_MOUNTPOINT="$(mdata-get PKGSRC_ALEXXLABS_MOUNTPOINT)"
fi

cat > /root/.gpg_agent_profile <<-EOPROFILE
envfile="\$HOME/.gnupg/gpg-agent.env"
if [[ -e "\$envfile" ]] && kill -0 \$(grep GPG_AGENT_INFO "\$envfile" | cut -d: -f 2) 2>/dev/null; then
    eval "\$(cat \$envfile)"
else
    eval "\$(/opt/local/bin/gpg-agent --daemon --write-env-file "\$envfile")"
fi
export GPG_AGENT_INFO  # the env file does not contain the export statement
export GPG_TTY=\$(tty)  # if it don't find the tty we're the tty (required by zlogin)

EOPROFILE

cat > /root/.bash_profile <<-EOPROFILE
# redefine some pkgbuild.conf variables
export LOFS_RO_MOUNTS="/root/.ssh=/root/.ssh /workspace=/workspace"
export LOFS_RW_MOUNTS="/data=/data /root/.gnupg=/root/.gnupg"
export CMD_GPG="/opt/local/bin/gpg2"
# ------------------------------------------------------------------
echo -n ">>> mounting /data/alexxlabs/src/pkgsrc at ${PKGSRC_ALEXXLABS_MOUNTPOINT} ... "
mkdir -p ${PKGSRC_ALEXXLABS_MOUNTPOINT}
if mount | grep ${PKGSRC_ALEXXLABS_MOUNTPOINT} > /dev/null; then
	echo "mounted."
else
	mount -F lofs /data/alexxlabs/src/pkgsrc ${PKGSRC_ALEXXLABS_MOUNTPOINT}
	echo "ok."
fi
# ------------------------------------------------------------------
[[ -f ~/.gpg_agent_profile ]] && source ~/.gpg_agent_profile || true
[[ -f ~/.profile ]]	&& source ~/.profile || true
[[ -f ~/.bashrc ]]	&& source ~/.bashrc || true

EOPROFILE

# -----------------------------------------------------------------------------------------------
# -----------------------------------------------------------------------------------------------
# -----------------------------------------------------------------------------------------------

mkdir -p /root/.gnupg && chmod 600 /root/.gnupg
print ">>> configure: /root/.gnupg/gpg-agent.conf"
cat > /root/.gnupg/gpg-agent.conf <<-EOF
daemon
use-standard-socket
max-cache-ttl 315360000
default-cache-ttl 315360000
pinentry-program /opt/local/bin/pinentry-tty

EOF

print ">>> configure: /root/.gnupg/gpg.conf"
cat > /root/.gnupg/gpg.conf <<-EOF
lock-never
no-auto-check-trustdb
no-random-seed-file
#no-tty
keyserver hkp://keys.gnupg.net
use-agent

EOF

# Tell the GPG agent to reload configuration:
#gpg-connect-agent reloadagent /bye

# importing manifests (webserv.xml and, maybe, others)
#DIR_MANIFEST="/data/alexxlabs/svc"
#if [[ -d "${DIR_MANIFEST}" ]]; then
#	for xml in ${DIR_MANIFEST}/*.xml; do
#		[[ -r "${xml}" ]] && echo "importing service: ${xml}" && svccfg import ${xml} || true
#	done
#fi
