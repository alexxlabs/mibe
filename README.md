MIBE (Machine Image Build Environment)
===

MIBE is a build environment for SmartOS images.

Joyent uses this internally to build SmartOS images, but it's not an officially supported solution.

SDC customers should see the following for building SmartOS images: [How to Create a SmartOS Image]  (https://docs.joyent.com/sdc7/working-with-images/how-to-create-a-smartos-image).

SmartOS users should use the following process: [Creating a Custom Zone Image]  (http://wiki.smartos.org/display/DOC/Managing+Images#ManagingImages-CreatingaCustomZoneImage)

## Prerequisites
* [Add your SSH key to github](https://help.github.com/articles/generating-ssh-keys)
* [Install SmartOS](http://wiki.smartos.org/display/DOC/Download+SmartOS)
* [Install Pkgsrc](http://wiki.smartos.org/display/DOC/Installing+pkgin)
* Install Git

		# pkgin install git-base

## Installation

		curl https://raw.githubusercontent.com/alexxlabs/mibe/master/mibe_install.sh | bash

defaults variables:

* DS_MIBE="tank/mibe"	(this dataset will be created by installation)
* DS_MIBE_QUOTA="300G"	(dataset quota)

mibe will be installed to:

* MI_HOME=/${DS_MIBE}

if you wish, you may override this by doing:

		echo 'DS_MIBE="newdataset"'| cat - <(curl -s https://raw.githubusercontent.com/alexxlabs/mibe/master/mibe_install.sh)| bash


## Layout

* mi_home/bin - Holds scripts to handle repository operations and build images.

    * bin/repo_cloneall - Clones latest Joyent Machine Image repositories into mi_home/repos.
    * bin/repo_pullall - Pulls latest Joyent Machine Image repositories into mi_home/repos.
    * bin/repo_init - Initializes a new Machine Image repository and populates standard build files.
    * bin/build_smartos - Image builder for SmartOS images.
	* bin/gh - custom github client (use github API to deal with github repositories)

* mi_home/etc - Where configuration files for repositories are kept.

    * etc/repos.conf - Git server repository configuration on where to get Machine Image repos from.
    * etc/repos.list - Git repository list of Joyent Machine Image repositories. This is updated as more images are made public.

* mi_home/lib - Includes directory for mibe.
* mi_home/images - Final image dumps are stored here.
* mi_home/logs - Logging directory for image builds.
* mi_home/repos - Build repositories.

## Defaults configuration

Additional defaults will be loaded from mi_home/.mibecfg and $HOME/.mibecfg.
This configuration needs to be bash sourceable.

Possible configuration options with their current default values:
```
owneruuid="9dce1460-0c4c-4417-ab8b-25ca478c5a78"
ownername="sdc"
urn_cloud_name="sdc"
urn_creator_name="sdc"
compression="gzip"
```

## Usage

Clone the mibe repository in /opt (or wherever has space to store image files):

    # cd /opt
    # git clone https://github.com/joyent/mibe
    # export PATH=$PATH:/opt/mibe/bin

Run repo_cloneall to grab the updated Joyent Machine Image build repositories.  They will be pulled down into mibe_home/repos.

    # repo_cloneall

Create a VM (SmartOS) for building images:

    # cat <<EOF > mibezone1.json
    {
      "brand": "joyent",
      "image_uuid": "9eac5c0c-a941-11e2-a7dc-57a6b041988f",
      "alias": "mibezone1",
      "hostname": "mibezone1",
      "max_physical_memory": 512,
      "quota": 20,
      "nics": [
        {
          "nic_tag": "admin",
          "ip": "dhcp",
          "primary": "true"
        }
      ]
    }
    EOF

Run vmadm create to create it:

    # vmadm create -f mibezone1.json

To build an example image we specify the base image, the vm to use (uuid of mibezone1), and the repository build files:

    # cd /opt/mibe/repos
    # build_smartos base64-13.2.1 629be403-f1e6-4c54-a4fc-dad4c4f25658 mi-example

    build_smartos - version 1.0.0
    Image builder for SmartOS images

    * Sanity checking build files and environment..                       OK.
    * Halting build zone (629be403-f1e6-4c54)..                           OK.
    * Configuring build zone (629be403-f1e6-4c54) to be imaged..          OK.
    * Booting build zone (629be403-f1e6-4c54)..                           OK.
    * Copying in mi-example/copy files..                                  OK.
    * Creating image motd and product file..                              OK.
    * Installing packages list..                                          OK.
    * Executing the customize file..                                      OK.
    * Halting build zone (629be403-f1e6-4c54)..                           OK.
    * Un-configuring build zone (629be403-f1e6-4c54)..                    OK.
    * Creating image file and manifest..                                  OK.

    Image:    /home/mibe/images/example-1.0.0.zfs.gz
    Manifest: /home/mibe/images/example-1.0.0.dsmanifest

The built image will be stored at mi_home/images/example-1.0.0.*
