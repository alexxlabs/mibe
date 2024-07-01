UUID="cce4bcd0-e191-403d-814f-6c08f8f2d8c6" # unique - generate it with: https://www.guidgenerator.com/online-guid-generator.aspx
#UUID_DISK_QUOTA="15G" # default is 15G, if want more - provide separately

IMAGE_UUID="ffb2e7d1-ba61-44ad-971a-940e4ac3bf15" # based on: alexxlabs-64@20240116

### !!! to simplify, do not use separate var for hostname
# see: dz -> deploy_vm_create() -> vm_create_json -> "hostname": "${ALIAS}.${DNS_DOMAIN}"
ALIAS="test"
PRIORITY="99"
MAC="12:33:40:a9:1d:${PRIORITY}"
RAM=1024

define NICS <<-FF
[{"nic_tag": "admin", "interface": "net0", "ips": ["dhcp", "addrconf"], "primary": true, "mac": "${MAC}"}]
FF

define FILESYSTEMS <<-EOF
{"type": "lofs", "source": "$CONFIG_DIR/lofs", "target": "/opt/mantain"},
EOF

# this private key is needed to access mikrotik by ssh from inside mantainer zone
# put this variable into VM metadata and extract it inside VM breaks newlines
# so - we replace newlines by $ symbol before putting it into metadata
# and after getting it inside VM
# (in overlay/root/vm-customize script, running inside VM during customize)
# replace $ symbol with newlines - so we get correct newlines inside VM
#MIKROT_ID_RSA_KEY=$(tr '\n' '$' < ${CONFIG_mikrot_id_rsa_key} || echo "key_not_exist")
#MIKROT_ID_RSA_PUB=$(tr '\n' '$' < ${CONFIG_mikrot_id_rsa_pub} || echo "key_not_exist")
#
#"system:mikrot_id_rsa_key_encoded" : "$MIKROT_ID_RSA_KEY",
#"system:mikrot_id_rsa_pub_encoded" : "$MIKROT_ID_RSA_PUB",
#
define CUSTOMER_METADATA <<-FF
"export:mikrot_ssh_host" : "${CONFIG_mikrot_ssh_host}",
"export:mikrot_ssh_port" : "${CONFIG_mikrot_ssh_port}",

"export:mikrot_backup_pass" : "${CONFIG_mikrot_backup_pass}",
"export:mikrot_backup_name" : "${CONFIG_mikrot_backup_name}",
"export:mikrot_backup_dir" : "${CONFIG_mikrot_backup_dir}",

"export:telegramm_bot_token" : "${CONFIG_telegramm_bot_token}",
"export:telegramm_chat_id" : "${CONFIG_telegramm_chat_id}",

"export:gz_github_token": "${CONFIG_gz_github_token}",
"export:gz_luadns_api_token": "${CONFIG_gz_luadns_api_token:-no}",
"export:gz_luadns_email": "${CONFIG_gz_luadns_email:-no@mail.com}",

FF

# https://thetooth.name/blog/homelab-2022-part-2-samba-on-smartos-using-delegated-datasets/
# !!! instead of delegate datasets and LOFS - use this mounting inside zone !!!
# The official documentation would lead you to believe that the only step required is setting the delegate_dataset flag.
# But as cautioned in the guide anything we put into this zone will share it's life cycle with the zone itself.
# We won't be using this flag at all and instead I will be delegating an existing dataset in such a way that the zone
# can be deleted at any time while retaining our content for future zones or importing straight into any other ZFS capable
# operating system. A side note on LOFS:
#   If you need multiple zones to access the same dataset concurrently but also cannot use NFS/Samba an alternate option
#   is LOFS. LOFS, works kind of like 'mount --bind', abstracting the calls to perform reads and writes and some simple
#   locking, it is however not an ideal solution. It's possible for a misbehaving zone to lock a file forever and crash,
#   needing a full host power cycle to get things moving again. The performance isn't much better than Samba either,
#   expect a hard cap on IOPs and no more than 100MB/s throughput. And of course it wont work with HVM guests at all.
datasets_to_mount=()
DATASETS_TO_MOUNT="${datasets_to_mount[@]}" # see example of use in zrun_test.sh

# for deploy vm customize:
# --------------------------------------------------------------------------
# tftp-hpa (temporary do not install, because we use mikrotic internal tftp)
# also commented out in: 01_vm_mantainer/overlay/root/vm-01-all
# --------------------------------------------------------------------------
# we use socat to provide mikrotik port knocking in: /etc/ssh/config.d/ssh_router_proxy.sh
