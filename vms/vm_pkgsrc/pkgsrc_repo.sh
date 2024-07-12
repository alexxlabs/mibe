#!/usr/bin/env bash

readonly MODE=${1:-sandbox}; shift

source ./lib.sh

repo_update() {
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
	git config --global pull.rebase true

	print "Updating repo..."
	cd /data/pkgsrc

	git pull
	git checkout release/trunk   # release/2023Q4, release/2022Q4, etc.
	git submodule update

	mkdir -p /data/pkgsrc/alexxlabs
	mount -F lofs /data/alexxlabs/src /data/pkgsrc/alexxlabs

	touch /data/pkgsrc/.gitignore
	echo "alexxlabs/" > /data/pkgsrc/.gitignore
}

sandbox() {
	# change 'zones/alexxlabs/pkgsrc' mountpoint to /data/packages/SmartOS/trunk/x86_64/All/
	datasets_to_mount=$(mdata-get datasets_to_mount)
	[ -z ${datasets_to_mount} ] || 
	for dataset in "${datasets_to_mount[@]}"; do
		ds_exists=$(zfs list -H -o name| grep "${dataset}")
		[[ "x${ds_exists}" == "x" ]] && die "${dataset} not exist" # this should never happen
		[[ "x${dataset}" == "xzones/alexxlabs/pkgsrc" ]] \
			&& zfs set mountpoint=/data/packages/SmartOS/trunk/x86_64/All ${dataset}
	done
	run-sandbox trunk-x86_64
}

case ${MODE} in
	up)			repo_update ; exit ;;
	sandbox)	sandbox ; exit ;;
	*)			print "uncknown mode: ${MODE}"; exit ;;
esac

# https://github.com/TritonDataCenter/pkgsrc/wiki/pkgdev:building
# ================================================================================================================
# we can go ahead and build the package.
# The output from this will be long, so you may want to tee it to a file for reviewing:
#
# bmake 2>&1 | tee /var/tmp/nmap.log
# ================================================================================================================
#	Assuming that the build completed successfully, you can now call the install target.
#	This installs the software to a temporary DESTDIR directory, and then creates a binary package from that.
#	The binary package is then installed into the real PREFIX using pkg_add:
# bmake install
# ================================================================================================================
# You can now verify it is installed, and test it:
# type nmap
#		nmap is /opt/local/bin/nmap
# nmap -v
#	Starting Nmap 7.95 ( https://nmap.org ) at 2024-07-10 13:10 UTC
#	Read data files from: /opt/local/share/nmap
#	WARNING: No targets were specified, so 0 hosts scanned.
#	Nmap done: 0 IP addresses (0 hosts up) scanned in 0.06 seconds
#		Raw packets sent: 0 (0B) | Rcvd: 0 (0B)
# ================================================================================================================
# Note that the binary package was created under /home/pbulk. This is a temporary directory which is destroyed
# when you exit the sandbox. In order to save the package to a permanent location you need to call the package target.
# Note though that this will overwrite any existing package that may already be stored there.
#
# bmake package
#		=> Bootstrap dependency digest>=20211023: found digest-20220214
#		===> Building binary package for nmap-7.40
#		=> Creating binary package /data/packages/SmartOS/trunk/x86_64/All/nmap-7.40.tgz
# ================================================================================================================
# You can now install the package outside of the sandbox using:
#
# $ pkg_add /data/packages/SmartOS/trunk/x86_64/All/nmap-7.40.tgz
#
# Note that in newer releases pkg_add will by default reject any packages that are not PGP signed in order
# to increase security. This is configured with the VERIFIED_INSTALLATION setting in
# /opt/local/etc/pkg_install.conf. Your choices here are:
# - either to follow the document on setting up signed packages: https://github.com/TritonDataCenter/pkgsrc/wiki/pkgdev:signing
# - modify pkg_install.conf and remove the VERIFIED_INSTALLATION setting
# - temporarily avoid the configuration file completely.
# You can achieve the latter with: $ pkg_add -C /dev/null /path/to/package.tgz
# ================================================================================================================
# Cleanup
# On SmartOS the quickest way to clean up is to simply exit the sandbox.
# This will destroy any non-shared directories and remove the sandbox completely.
#
# If you prefer to just clean up the build artefacts, for example if you are using the sandbox to build more packages
# but do not have a lot of space, you can use the clean and clean-depends targets.
#
# $ bmake clean clean-depends
#
# Sometimes though it's easier (and faster) to just wipe out the build area completely.
# This is configured by the WRKOBJDIR variable, so:
#
# $ bmake show-var VARNAME=WRKOBJDIR
#		/home/pbulk/build
#
# $ rm -rf /home/pbulk/build/*