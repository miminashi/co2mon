#!/bin/sh

#
# USAGE 使い方:
#   /boot/setup/setup_raspberrypi.sh
#


cmdname=$(basename "${0}")

checkfile() {
  test -s "${1}" || error "${1} が存在しないか空です"
}

error() {
  error_message "${1}"
  exit 1
}

error_handler() {
  error_message "不明なエラー"
}

error_message() {
  printf '\e[31m%s: エラー: %s\e[m\n' "${cmdname}" "${1}" 1>&2
  printf '\e[31m%s: 終了します\e[m\n' "${cmdname}" 1>&2
}

# 1箇所でもエラー終了するコマンドがあればスクリプトを終了する
# その場合, error_handler を実行する
set -eu
trap error_handler EXIT

#
# ↓ここから通常時の処理↓
#

# 環境変数チェック
#: ${GITHUB_USERNAME}
#: ${NEW_HOSTNAME}

# ファイルの存在確認
checkfile /boot/setup/hostname
checkfile /boot/setup/ssh_keys

new_hostname="$(cat /boot/setup/hostname)"

# Docker
curl -fsSL https://get.docker.com -o /tmp/get-docker.sh
sudo sh /tmp/get-docker.sh
sudo usermod -aG docker pi

# ssh鍵認証の設定
mkdir -p /home/pi/.ssh
cp /boot/setup/ssh_keys /home/pi/.ssh/authorized_keys
chmod 600 /home/pi/.ssh/authorized_keys

# sshリバースフォワードの設定
# /boot/setup/ssh_rpfw が存在する場合はリバースフォワードの設定を行う
if [ -d /boot/setup/ssh_rpfw ]; then
  ssh_rpfw_dir="/boot/setup/ssh_rpfw"

  # ファイルの存在確認
  checkfile "${ssh_rpfw_dir}"/id_ed25519
  checkfile "${ssh_rpfw_dir}"/id_ed25519.pub
  checkfile "${ssh_rpfw_dir}"/rpfw_port
  checkfile "${ssh_rpfw_dir}"/rpfw_server
  checkfile "${ssh_rpfw_dir}"/rpfw_server_port
  checkfile "${ssh_rpfw_dir}"/rpfw_server_user
  checkfile "${ssh_rpfw_dir}"/rpfw_server_key

  rpfw_port="$(cat ${ssh_rpfw_dir}/rpfw_port)"
  rpfw_server="$(cat ${ssh_rpfw_dir}/rpfw_server)"
  rpfw_server_port="$(cat ${ssh_rpfw_dir}/rpfw_server_port)"
  rpfw_server_user="$(cat ${ssh_rpfw_dir}/rpfw_server_user)"
  rpfw_server_key="$(cat ${ssh_rpfw_dir}/rpfw_server_key)"

  if [ "${rpfw_server_port}" = "" ]; then
    rpfw_server_port="22"
  fi

  # serviceファイルの作成
  sudo tee /etc/systemd/system/ssh-rpfw.service <<EOF
[Unit]
Description=ssh reverse port forwarding service
After=network.target auditd.service

[Service]
User=pi
Group=pi
WorkingDirectory=/home/pi
ExecStart=/usr/bin/ssh -o ServerAliveInterval=5 -o ServerAliveCountMax=3 -o ExitOnForwardFailure=yes -o TCPKeepAlive=no -N -R ${rpfw_port}:127.0.0.1:22 -i /home/pi/.ssh/id_ed25519 -p ${rpfw_server_port} ${rpfw_server_user}@${rpfw_server}
Restart=always
RestartSec=1
StartLimitBurst=0

[Install]
WantedBy=multi-user.target
EOF

  # サービスの有効化
  sudo systemctl enable ssh-rpfw.service

  # known_hosts ファイルにリバースフォワードサーバの公開鍵を登録する
  if [ "${rpfw_server_port}" = "22" ]; then
    printf '%s %s\n' "${rpfw_server}" "${rpfw_server_key}" | sudo tee /etc/ssh/ssh_known_hosts > /dev/null
  else
    printf '[%s]:%s %s\n' "${rpfw_server}" "${rpfw_server_port}" "${rpfw_server_key}" | sudo tee /etc/ssh/ssh_known_hosts > /dev/null
  fi

  # 鍵ペアのコピー
  cp "${ssh_rpfw_dir}"/id_ed25519 ~/.ssh
  chmod 600 ~/.ssh/id_ed25519
  cp "${ssh_rpfw_dir}"/id_ed25519.pub ~/.ssh
  chmod 644 ~/.ssh/id_ed25519.pub
fi

# ユーティリティのインストール
sudo apt-get -y install bc pax ncompress vim screen

# GNU screen
cat <<'EOF' > /home/pi/.screenrc
startup_message off
vbell off
caption always "  %n %t  $USER@%H"
termcapinfo xterm* ti@:te@
term xterm-color
shell bash
EOF

# sshd
sudo tee /etc/ssh/sshd_config > /dev/null <<'EOF'
#       $OpenBSD: sshd_config,v 1.103 2018/04/09 20:41:22 tj Exp $

# This is the sshd server system-wide configuration file.  See
# sshd_config(5) for more information.

# This sshd was compiled with PATH=/usr/bin:/bin:/usr/sbin:/sbin

# The strategy used for options in the default sshd_config shipped with
# OpenSSH is to specify options with their default value where
# possible, but leave them commented.  Uncommented options override the
# default value.

#Port 22
#AddressFamily any
#ListenAddress 0.0.0.0
#ListenAddress ::

#HostKey /etc/ssh/ssh_host_rsa_key
#HostKey /etc/ssh/ssh_host_ecdsa_key
#HostKey /etc/ssh/ssh_host_ed25519_key

# Ciphers and keying
#RekeyLimit default none

# Logging
#SyslogFacility AUTH
#LogLevel INFO

# Authentication:

#LoginGraceTime 2m
PermitRootLogin no
#StrictModes yes
#MaxAuthTries 6
#MaxSessions 10

#PubkeyAuthentication yes

# Expect .ssh/authorized_keys2 to be disregarded by default in future.
#AuthorizedKeysFile     .ssh/authorized_keys .ssh/authorized_keys2

#AuthorizedPrincipalsFile none

#AuthorizedKeysCommand none
#AuthorizedKeysCommandUser nobody

# For this to work you will also need host keys in /etc/ssh/ssh_known_hosts
#HostbasedAuthentication no
# Change to yes if you don't trust ~/.ssh/known_hosts for
# HostbasedAuthentication
#IgnoreUserKnownHosts no
# Don't read the user's ~/.rhosts and ~/.shosts files
#IgnoreRhosts yes

# To disable tunneled clear text passwords, change to no here!
PasswordAuthentication no
#PermitEmptyPasswords no

# Change to yes to enable challenge-response passwords (beware issues with
# some PAM modules and threads)
ChallengeResponseAuthentication no

# Kerberos options
#KerberosAuthentication no
#KerberosOrLocalPasswd yes
#KerberosTicketCleanup yes
#KerberosGetAFSToken no

# GSSAPI options
#GSSAPIAuthentication no
#GSSAPICleanupCredentials yes
#GSSAPIStrictAcceptorCheck yes
#GSSAPIKeyExchange no

# Set this to 'yes' to enable PAM authentication, account processing,
# and session processing. If this is enabled, PAM authentication will
# be allowed through the ChallengeResponseAuthentication and
# PasswordAuthentication.  Depending on your PAM configuration,
# PAM authentication via ChallengeResponseAuthentication may bypass
# the setting of "PermitRootLogin without-password".
# If you just want the PAM account and session checks to run without
# PAM authentication, then enable this but set PasswordAuthentication
# and ChallengeResponseAuthentication to 'no'.
UsePAM yes

#AllowAgentForwarding yes
#AllowTcpForwarding yes
#GatewayPorts no
X11Forwarding yes
#X11DisplayOffset 10
#X11UseLocalhost yes
#PermitTTY yes
PrintMotd no
#PrintLastLog yes
#TCPKeepAlive yes
#PermitUserEnvironment no
#Compression delayed
#ClientAliveInterval 0
#ClientAliveCountMax 3
#UseDNS no
#PidFile /var/run/sshd.pid
#MaxStartups 10:30:100
#PermitTunnel no
#ChrootDirectory none
#VersionAddendum none

# no default banner path
#Banner none

# Allow client to pass locale environment variables
AcceptEnv LANG LC_*

# override default of no subsystems
Subsystem       sftp    /usr/lib/openssh/sftp-server

# Example of overriding settings on a per-user basis
#Match User anoncvs
#       X11Forwarding no
#       AllowTcpForwarding no
#       PermitTTY no
#       ForceCommand cvs server
EOF

# DHCPクライアントの設定
sudo tee /etc/dhcpcd.conf > /dev/null <<'EOF'
hostname
clientid
persistent
option rapid_commit
option domain_name_servers, domain_name, domain_search, host_name
option interface_mtu
require dhcp_server_identifier
slaac private
noipv6
noipv6rs
static domain_name_servers=8.8.8.8 8.8.4.4
EOF

## config.txt
#sudo tee /boot/config.txt > /dev/null <<'EOF'
## For more options and information see
## http://rpf.io/configtxt
## Some settings may impact device functionality. See link above for details
#
## uncomment if you get no picture on HDMI for a default "safe" mode
##hdmi_safe=1
#
## uncomment this if your display has a black border of unused pixels visible
## and your display can output without overscan
##disable_overscan=1
#
## uncomment the following to adjust overscan. Use positive numbers if console
## goes off screen, and negative if there is too much border
##overscan_left=16
##overscan_right=16
##overscan_top=16
##overscan_bottom=16
#
## uncomment to force a console size. By default it will be display's size minus
## overscan.
##framebuffer_width=1280
##framebuffer_height=720
#
## uncomment if hdmi display is not detected and composite is being output
##hdmi_force_hotplug=1
#
## uncomment to force a specific HDMI mode (this will force VGA)
##hdmi_group=1
##hdmi_mode=1
#
## uncomment to force a HDMI mode rather than DVI. This can make audio work in
## DMT (computer monitor) modes
##hdmi_drive=2
#
## uncomment to increase signal to HDMI, if you have interference, blanking, or
## no display
##config_hdmi_boost=4
#
## uncomment for composite PAL
##sdtv_mode=2
#
##uncomment to overclock the arm. 700 MHz is the default.
##arm_freq=800
#
## Uncomment some or all of these to enable the optional hardware interfaces
##dtparam=i2c_arm=on
##dtparam=i2s=on
##dtparam=spi=on
#
## Uncomment this to enable infrared communication.
##dtoverlay=gpio-ir,gpio_pin=17
##dtoverlay=gpio-ir-tx,gpio_pin=18
#
## Additional overlays and parameters are documented /boot/overlays/README
#
## Enable audio (loads snd_bcm2835)
#dtparam=audio=on
#
## g_ether
#dtoverlay=dwc2
#
#[pi4]
## Enable DRM VC4 V3D driver on top of the dispmanx display stack
#dtoverlay=vc4-fkms-v3d
#max_framebuffers=2
#
#[all]
##dtoverlay=vc4-fkms-v3d
#EOF

## cmdline.txt
#sudo tee /boot/cmdline.txt > /dev/null <<'EOF'
#modules-load=dwc2,g_ether console=serial0,115200 console=tty1 root=PARTUUID=738a4d67-02 rootfstype=ext4 elevator=deadline fsck.repair=yes rootwait
#EOF

# ホスト名の設定
sudo raspi-config nonint do_hostname "${new_hostname}"


#echo ""
#echo "----------------------------"
#echo "${new_hostname} のssh公開鍵:"
#cat ~/.ssh/id_ed25519.pub

echo "セットアップが完了しました。再起動します"
sudo nohup shutdown -r now &

# 異常終了時ハンドラの解除
trap '' EXIT
