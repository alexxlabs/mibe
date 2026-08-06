# to setup newly created pkgsrc zone, do the following:

!!! From global zone ...

## delete previous pkgsrc zone:

 - /tank/mibe (master)# make vm delete pkgsrc

## edit vms/vm_pkgsrc.sh, adjust BASED_ON_NAME="pkgbuild-trunk" and BASED_ON_VERSION="20240116"

## create new pkgsrc zone:

on creation, directory 'lofs' will be lofs mounted inside the zone at '/data/alexxlabs'

 - /tank/mibe (master)# make vm create pkgsrc
 - /tank/mibe (master)# make vm start pkgsrc

## customize newly created zone

this will copy 'overlay' dir inside the zone and execute /root/customize.sh inside the zone

 - /tank/mibe (master)# make vm customize pkgsrc

!!! From now we can ssh into the zone from developer windows PC ...
!!! All next preparations will be done from inside the zone ...

 - ssh pkgsrc
	make repo gpg
	make repo init
	make setup rust
	make repo chroot

# !!! ONLY IF on processing 'make repo keygen' we generate new gpg package signing key, we must rebuild/resign ALL our packages
#
# README: https://www.perkin.org.uk/posts/pkgsrc-on-smartos-creating-new-packages.html
#
[root@pkgsrc /data/alexxlabs]# make repo chroot
	inside sandbox chroot do:
		$ cd /data/pkgsrc/alexxlabs/hitch
			First we need to run a stage-install which will execute make install into a temporary DESTDIR:
		$ bmake stage-install
		this will almost certainly fail as we haven’t configured the PLIST yet,
		so pkgsrc has no idea what will be installed from this package.
		However, now that we have a populated DESTDIR,
		we can use the print-PLIST target to generate it for us:
		$ bmake print-PLIST >PLIST
		Finally, it’s worth doing a full clean and install to ensure everything works as expected.
		$ bmake clean
		$ bmake install <maybe not>
		$ bmake package
			WARNING: do not pay attention on this error message at the end of package building
				pkg_info: unable to verify signature: Signature key id 5c41e902a2176d78 not found
				*** Error code 1
			this is because we install pgp sign key NOT inside sandbox
		$ cd /data/pkgsrc/alexxlabs/varnish
		$ bmake package
		.... recompile/resign ALL custom packages
	after that - exit from sandbox chroot
		$ exit
and regenerate pkg_summary.gz
[root@pkgsrc /data/alexxlabs]# make repo upsum

In this directory, create a pkg_summary.bz2 file, where all packages, dependencies and descriptions will be available:

# cd /usr/pkgsrc/packages/All
# pkg_info -X * | bzip2 > pkg_summary.bz2
# pkg_info -X *.tgz | gzip -9 > pkg_summary.gz

## =============================================================================

# first, setup 'varnish', because it creates '/tmp/varnish.sock', which is needed for 'hitch' starting

 - to install and setup varnish from local repo:
	[root@pkgsrc /data/alexxlabs]# make setup varnish

 - to install and setup hitch from local repo:
	[root@pkgsrc /data/alexxlabs]# make setup hitch

 - to install and setup rust/wasm developer env:
	[root@pkgsrc /data/alexxlabs]# make setup wasm