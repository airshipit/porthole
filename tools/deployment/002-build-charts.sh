#!/bin/bash

CURRENT_DIR="$(pwd)"
: "${PORTHOLE_PATH:="../porthole"}"

cd "${PORTHOLE_PATH}" || exit
sudo echo 127.0.0.1 localhost /etc/hosts

mkdir -p artifacts

make lint
make charts

cd charts || exit
for i in $(find  . -maxdepth 1  -name "*.tgz"  -print | sed -e 's/\-[0-9.]*\.tgz//'| cut -d / -f 2 | sort)
do
    find . -name "$i-[0-9.]*.tgz" -print -exec cp -av {} "../artifacts/$i.tgz" \;
done
