#!/bin/bash

CURRENT_DIR="$(pwd)"
: "${PORTHOLE_PATH:="../porthole"}"

cd "${PORTHOLE_PATH}" || exit
sudo echo 127.0.0.1 localhost /etc/hosts

BUILD_DIR=$(mktemp -d)
HELM=${BUILD_DIR}/helm
HELM_PIDFILE=${CURRENT_DIR}/.helm-pid

rm -rf build
rm -f charts/*.tgz
rm -f charts/*/requirements.lock
rm -rf charts/*/charts

./tools/helm_install.sh ${HELM}
./tools/helm_tk.sh ${HELM} ${HELM_PIDFILE}


