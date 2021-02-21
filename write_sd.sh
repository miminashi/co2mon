#!/bin/sh

set -eu

#image_url="http://downloads.raspberrypi.org/raspios_lite_armhf/images/raspios_lite_armhf-2020-05-28/2020-05-27-raspios-buster-lite-armhf.zip"
torrent_url="http://downloads.raspberrypi.org/raspios_lite_armhf/images/raspios_lite_armhf-2020-05-28/2020-05-27-raspios-buster-lite-armhf.zip.torrent"
archive="./2020-05-27-raspios-buster-lite-armhf.zip"
image="./2020-05-27-raspios-buster-lite-armhf.img"
sha256="f5786604be4b41e292c5b3c711e2efa64b25a5b51869ea8313d58da0b46afc64"

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
FLG_p="FALSE"
FLG_r="FALSE"
FLG_P="FALSE"
FLG_u="FALSE"
FLG_k="FALSE"

cmdname="$(basename "$0")"

while getopts p:r:P:u:k:h OPT; do
  case $OPT in
    "p" ) FLG_p="TRUE"; VALUE_p=${OPTARG} ;;
    "r" ) FLG_r="TRUE"; VALUE_r=${OPTARG} ;;
    "P" ) FLG_P="TRUE"; VALUE_P=${OPTARG} ;;
    "u" ) FLG_u="TRUE"; VALUE_u=${OPTARG} ;;
    "k" ) FLG_k="TRUE"; VALUE_k=${OPTARG} ;;
    "h" ) echo "使い方: ${cmdname} [-p rpfw_port] [-r rpfw_server] [-P rpfw_server_port] [-u rpfw_server_user] [-k rpfw_server_key] hostname"
          echo "        ${cmdname} [-h]"
          echo "    -p rpfw_port        リバースフォワードで使用するポート"
          echo "    -r rpfw_server      リバースフォワードサーバへのssh接続で使用するIPアドレスまたはホスト名"
          echo "    -P rpfw_server_port リバースフォワードサーバへのssh接続で使用するポート番号"
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

if [ "${FLG_p}" = "TRUE" ] || [ "${FLG_r}" = "TRUE" ] || [ "${FLG_P}" = "TRUE" ] || [ "${FLG_u}" = "TRUE" ] || [ "${FLG_k}" = "TRUE" ]; then
  if [ "${FLG_p}" = "TRUE" ] && [ "${FLG_r}" = "TRUE" ] && [ "${FLG_P}" = "TRUE" ] && [ "${FLG_u}" = "TRUE" ] && [ "${FLG_k}" = "TRUE" ]; then
    rpfw_port="${VALUE_p}"
    rpfw_server="${VALUE_r}"
    rpfw_server_port="${VALUE_P}"
    rpfw_server_user="${VALUE_u}"
    rpfw_server_key="${VALUE_k}"
  else
    echo "エラー: -p -r -P -u -k は同時に指定する必要があります" >&2
    exit 1
  fi
fi

# ssh_keys の存在確認
if ! [ -f "./ssh_keys" ]; then
  echo "./ssh_keys が存在しません" >&2
  exit 1
fi

# sudoをいちどキックしておく
echo "microSDに書き込むためにsudoのパスワードを入力してください"
sudo printf ''  

# ディスクイメージがなければダウンロードする
if ! [ -f "${image}" ] ; then
  if ! aria2c -h > /dev/null; then
    echo "aria2c をインストールしてください"
    exit 1
  fi
  aria2c --seed-time=1 "${torrent_url}"
  unzip "${archive}"
fi

while ! diskutil info /dev/disk2 > /dev/null; do
  echo "waiting /dev/disk2 ..."
  sleep 1
done
echo "/dev/disk2 found!"

diskutil unmountDisk /dev/disk2

echo "ディスクイメージを書き込みます..."
dd if="${image}" bs=1m | pv | sudo dd of=/dev/rdisk2 bs=1m

while :; do
  echo "waiting /Volumes/boot ..."
  test -d /Volumes/boot && break
  sleep 1
done
echo "/Volumes/boot found!"

boot_dir="/Volumes/boot"
setup_dir="${boot_dir}/setup"

mkdir -p "${setup_dir}"

# セットアップスクリプトのコピー
cp ./setup_raspberrypi.sh "${setup_dir}"

# ホスト名の設定
echo "${hostname}" > "${setup_dir}"/hostname

# 公開鍵のコピー
cp ./ssh_keys "${setup_dir}"/ssh_keys

# ssh_rpfwの設定
if [ -n "${rpfw_port}" ] && [ -n "${rpfw_server}" ] && [ -n "${rpfw_server_port}" ] && [ -n "${rpfw_server_user}" ] && [ -n "${rpfw_server_key}" ]; then
  echo "リバースフォワードの設定を行います" >&2
  ssh-keygen -t ed25519 -f "${tmp}"/id_ed25519 -N '' -C "pi@${hostname}"
  mkdir "${setup_dir}"/ssh_rpfw
  cp "${tmp}"/id_ed25519 "${setup_dir}"/ssh_rpfw
  cp "${tmp}"/id_ed25519.pub "${setup_dir}"/ssh_rpfw
  echo "${rpfw_port}" > "${setup_dir}"/ssh_rpfw/rpfw_port
  echo "${rpfw_server}" > "${setup_dir}"/ssh_rpfw/rpfw_server
  echo "${rpfw_server_port}" > "${setup_dir}"/ssh_rpfw/rpfw_server_port
  echo "${rpfw_server_user}" > "${setup_dir}"/ssh_rpfw/rpfw_server_user
  echo "${rpfw_server_key}" > "${setup_dir}"/ssh_rpfw/rpfw_server_key
fi

# sshdを有効化
touch /Volumes/boot/ssh

# ディスクの取出
diskutil eject /dev/disk2

# 完了メッセージの表示
echo "ディスクイメージの書き込みが完了しました"
echo ""
echo "----------------------------"
echo "${hostname} が使用するポート: ${rpfw_port}"
printf '%s のssh公開鍵: %s\n' "${hostname}" "$(cat "${tmp}"/id_ed25519.pub)"
echo "----------------------------"
say 'オワッタヨ'


# ここで通常の終了処理
on_exit

# 異常終了時ハンドラの解除
trap '' EXIT
