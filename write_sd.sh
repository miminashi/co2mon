#!/bin/sh

DEFAULT_TARGET_DISK="/dev/disk2"

set -eu

torrent_url="https://downloads.raspberrypi.org/raspios_lite_armhf/images/raspios_lite_armhf-2021-03-25/2021-03-04-raspios-buster-armhf-lite.zip.torrent"
archive="./2021-03-04-raspios-buster-armhf-lite.zip"
image="./2021-03-04-raspios-buster-armhf-lite.img"
sha256="ea92412af99ec145438ddec3c955aa65e72ef88d84f3307cea474da005669d39"

on_exit() {
  rm -rf "${tmp}"
}

error_handler() {
  # エラー時の処理
  on_exit
}

trap error_handler EXIT

# ここから通常の処理

# tmpディレクトリの準備
tmp="$(mktemp -d)"

# 引数を処理する
FLG_R="FALSE"
FLG_p="FALSE"
FLG_r="FALSE"
FLG_P="FALSE"
FLG_u="FALSE"
FLG_k="FALSE"

cmdname="$(basename "$0")"

while getopts Rp:r:P:u:k:h OPT; do
  case $OPT in
    "R" ) FLG_R="TRUE" ;;
    "p" ) FLG_p="TRUE"; VALUE_p=${OPTARG} ;;
    "r" ) FLG_r="TRUE"; VALUE_r=${OPTARG} ;;
    "P" ) FLG_P="TRUE"; VALUE_P=${OPTARG} ;;
    "u" ) FLG_u="TRUE"; VALUE_u=${OPTARG} ;;
    "k" ) FLG_k="TRUE"; VALUE_k=${OPTARG} ;;
    "h" ) echo "使い方: ${cmdname} [-R] [-p rpfw_port] [-r rpfw_server] [-P rpfw_server_port] [-u rpfw_server_user] [-k rpfw_server_key] hostname"
          echo "        ${cmdname} [-h]"
          echo "    -R                  リバースフォワードを使用する"
          echo "    -p rpfw_port        リバースフォワードで使用するポート"
          echo "    -r rpfw_server      リバースフォワードサーバへのssh接続で使用するIPアドレスまたはホスト名"
          echo "    -P rpfw_server_port リバースフォワードサーバへのssh接続で使用するポート番号（デフォルト: 22）"
          echo "    -u rpfw_server_user リバースフォワードサーバへのssh接続で使用するユーザ名"
          echo "    -k rpfw_server_key  リバースフォワードサーバのホスト公開鍵"
          echo "    -h                  このヘルプを表示する"
          exit 0 ;;
    * ) :
  esac
done
shift $(( OPTIND - 1 ))

hostname="${1-}"
if [ -z "${hostname}" ]; then
  echo "エラー: 第1引数にホスト名を指定してください" >&2
  exit 1
fi

if [ "${FLG_R}" = "TRUE" ] ; then
  if [ "${FLG_p}" = "TRUE" ] && [ "${FLG_r}" = "TRUE" ] && [ "${FLG_u}" = "TRUE" ] && [ "${FLG_k}" = "TRUE" ]; then
    rpfw_port="${VALUE_p}"
    rpfw_server="${VALUE_r}"
    rpfw_server_user="${VALUE_u}"
    rpfw_server_key="${VALUE_k}"
  else
    echo "エラー: -R を指定した場合、-p -r -u -k も同時に指定する必要があります" >&2
    exit 1
  fi
  # -P が指定されていた場合
  if [ "${FLG_P}" = "TRUE" ]; then
    rpfw_server_port="${VALUE_P}"
  else
    rpfw_server_port="22"
  fi
fi

# ssh_keys の存在確認
if ! [ -f "./ssh_keys" ]; then
  echo "./ssh_keys が存在しません" >&2
  exit 1
fi

# sudoをいちどキックしておく
if ! sudo -n id > /dev/null 2>&1; then
  echo "microSDへの書込にroot権限が必要です。sudoのパスワードを入力してください"
  sudo id > /dev/null
fi

# ディスクイメージがなければダウンロードする
if ! [ -f "${image}" ] ; then
  if ! aria2c -h > /dev/null; then
    echo "aria2c をインストールしてください"
    exit 1
  fi
  aria2c --seed-time=1 "${torrent_url}"
  unzip "${archive}"
fi

printf 'microSDを接続してください\n'
printf '(microSDを接続しても認識されない場合はいちど抜いて挿し直してください)\n'
while ! diskutil info /dev/disk2 > /dev/null 2>&1; do
  printf '.'
  sleep 1
done
printf '%s が見つかりました\n' "${DEFAULT_TARGET_DISK}"

if ! diskutil unmountDisk /dev/disk2 > /dev/null 2>&1; then
  echo "アンマウントに失敗しました。再度実行してください"
  exit 1
fi

printf '%s にディスクイメージを書き込みます\n' "${DEFAULT_TARGET_DISK}"
dd if="${image}" bs=1m 2>/dev/null | pv | sudo dd of=/dev/rdisk2 bs=1m 2>/dev/null

echo "/Volumes/boot がマウントされるのを待っています"
while :; do
  printf '.'
  test -d /Volumes/boot && break
  sleep 1
done
echo "/Volumes/boot が見つかりました"

echo "/Volumes/boot に初期セットアップに必要な情報を書き込んでいます..."

boot_dir="/Volumes/boot"
setup_dir="${boot_dir}/setup"

mkdir -p "${setup_dir}"

# セットアップスクリプトのコピー
cp ./setup_raspberrypi.sh "${setup_dir}"

# ホスト名の設定
echo "${hostname}" > "${setup_dir}"/hostname

# 公開鍵のコピー
cp ./ssh_keys "${setup_dir}"/ssh_keys

# sshdを有効化
touch /Volumes/boot/ssh

# ssh_rpfwの設定
if [ "${FLG_R}" = "TRUE" ] ; then
  echo "リバースフォワードの設定を行っています..."
  ssh-keygen -t ed25519 -f "${tmp}"/id_ed25519 -N '' -C "pi@${hostname}" > /dev/null 2>&1
  mkdir "${setup_dir}"/ssh_rpfw
  cp "${tmp}"/id_ed25519 "${setup_dir}"/ssh_rpfw
  cp "${tmp}"/id_ed25519.pub "${setup_dir}"/ssh_rpfw
  echo "${rpfw_port}" > "${setup_dir}"/ssh_rpfw/rpfw_port
  echo "${rpfw_server}" > "${setup_dir}"/ssh_rpfw/rpfw_server
  echo "${rpfw_server_port}" > "${setup_dir}"/ssh_rpfw/rpfw_server_port
  echo "${rpfw_server_user}" > "${setup_dir}"/ssh_rpfw/rpfw_server_user
  echo "${rpfw_server_key}" > "${setup_dir}"/ssh_rpfw/rpfw_server_key
fi

# ディスクの取出
echo "${DEFAULT_TARGET_DISK} をアンマウントします..."
diskutil eject /dev/disk2 > /dev/null 2>&1

# 完了メッセージの表示
echo ""
echo "ディスクイメージの書き込みが完了しました"
echo "microSDをRaspberryPiに挿入して電源を接続したら、Macから次のコマンドを実行してセットアップを完了してください。"
echo "(パスワードは raspberry)"
printf '$ '
printf '\e[34mssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no pi@raspberrypi.local /boot/setup/setup_raspberrypi.sh\e[m\n'
if [ "${FLG_R}" = "TRUE" ] ; then
  echo ""
  echo "リバースポートフォワードで使用する情報は次の通りです:"
  printf '%s が使用するポート: \e[34m%s\e[m\n' "${hostname}" "${rpfw_port}"
  printf '%s のssh公開鍵: \e[34m%s\e[m\n' "${hostname}" "$(cat "${tmp}"/id_ed25519.pub)"
  echo ""
  echo "リバースポートフォワードサーバの ~/.ssh/authorized_keys に以下の行を書き込んでください:"
  printf -- '```\n'
  printf '\e[34m'   # 青にする
  cat <<EOF
#permitlisten="${rpfw_port}"
$(cat "${tmp}"/id_ed25519.pub)
EOF
  printf '\e[m' # 戻す
  printf '```\n'
fi
echo ""
echo "ローカルマシンの ~/.ssh/config に以下の行を書き込んでください:"
printf '```\n'
printf '\e[34m'   # 青にする
if [ "${FLG_R}" = "TRUE" ] ; then
  cat <<EOF
Host ${hostname}
  HostName localhost
  Port ${rpfw_port}
  User pi
  ProxyCommand ssh -W %h:%p -o ServerAliveInterval=3 -o ServerAliveCountMax=3 rpfw@l.or6.jp
  UserKnownHostsFile ~/.ssh/known_hosts.d/${hostname}
  ServerAliveInterval 3
  ServerAliveCountMax 3
EOF
fi
cat <<EOF
Host ${hostname}.local
  HostName ${hostname}.local
  User pi
  UserKnownHostsFile ~/.ssh/known_hosts.d/${hostname}
  ServerAliveInterval 3
  ServerAliveCountMax 3
EOF
printf '\e[m' # 戻す
printf '```\n'
echo ""
printf 'セットアップ完了後は、 '
if [ "${FLG_R}" = "TRUE" ] ; then
  printf '\e[34m'   # 青にする
  printf 'ssh %s' "${hostname}"
  printf '\e[m' # 戻す
  printf ' または '
  printf '\e[34m'   # 青にする
  printf 'ssh %s.local' "${hostname}"
  printf '\e[m' # 戻す
else
  printf '\e[34m'   # 青にする
  printf 'ssh %s.local' "${hostname}"
  printf '\e[m' # 戻す
fi
printf ' としてアクセスできます\n'

say 'オワッタヨ'


# ここで通常の終了処理
on_exit

# 異常終了時ハンドラの解除
trap '' EXIT
