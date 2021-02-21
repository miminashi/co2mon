# co2mon

![airnorm_mobile](airnorm_mobile.jpg)

Hec-EyeにつながるCO2モニタ

## 必要なハードウェア

- RaspberryPi 4
- [usb_co2](https://github.com/realglobe-Inc/usb_co2)
- [usb_7seg](https://github.com/realglobe-Inc/usb_7seg)
- PIX-MT100
  - セルラー回線（LTE）で使用する場合のみ
- USB接続のGPS受信機
  - 車載の場合など、移動しながら使用する場合のみ
  - [GU-902MGG-USB](https://akizukidenshi.com/catalog/g/gM-14541/)が動作確認済
- モバイルバッテリー
  - 車載の場合など、移動しながら使用する場合のみ

## デプロイ

### RaspberryPiのセットアップ

microSDの書き込みを行う。

```sh
# 自分のssh公開鍵を ssh_keys に書き込んでおく
cat ~/.ssh/id_ed25519.pub >> ssh_keys
# LANの同一セグメントから <ホスト名>.local でアクセスのみ行う場合
./write_sd.sh <ホスト名>
# リバースフォワードサーバを使う場合
./write_sd.sh -p <リバースフォワードで使用するポート> -r <リバースフォワードサーバのIPアドレス> -P <リバースフォワードサーバのsshポート> -u <リバースフォワードサーバに接続するユーザ> -k <リバースフォワードサーバのホスト鍵> <ホスト名>
```

RaspberryPiが起動したらログインする。

```sh
ssh pi@raspberrypi.local
# パスワードは raspberry
```

ログインできたら、RaspberryPiのシェルで以下のコマンドを実行する。
（Ethernetなど、安定した回線で実行するのがおすすめ）

```
/boot/setup/setup_raspberrypi.sh
```

セットアップが完了すると自動的に再起動する。
以降は以下のコマンドでRaspberryPiにシェルログインできる。

```sh
ssh pi@<ホスト名>.local
```

### アプリケーションのデプロイ

- `deploy.sh`を実行すると、ビルド、Dockerイメージの転送、HecEyeとのペアリング、緯度経度の設定が行われる
- `paring_url` はHecEyeでデバイスを追加したときにQRコードの下に表示されるURL
- `target`はssh接続先として有効な文字列
  - `RaspberryPiのセットアップ` で指定したホスト名を用いて、同一セグメントからアクセスする場合: <ホスト名>.local
- `lat`は緯度, `lng` は経度
  - 設置したい場所の`lat`と`lng`を知るには、[地理院地図](https://maps.gsi.go.jp/)や[OpenStreetMap](https://www.openstreetmap.org/)を使うとよい

```sh
brew install pv  # 最初の1回のみ
./deploy.sh <target> <paring_url> <lat> <lng>
```

```sh
# 例
./deploy.sh pi@co2mon.local https://demo.hec-eye.jp/a/625c2d59bXXXXXXXX 35.70161 139.75318
```

## co2monを使用しているプロジェクト

- [Project AIRNORM](https://scrapbox.io/realglobe/Project_AIRNORM)


## 開発

開発者向けの情報は [DEVELOPMENT.md](DEVELOPMENT.md) を見てください
