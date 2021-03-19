#!/bin/sh

docker build --platform linux/arm/v7 -t co2mon .   # Armのマシンはこちら
#docker build --platform linux/amd64 -t co2mon .   # x86_64のマシンはこちら
