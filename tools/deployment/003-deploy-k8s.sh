#!/bin/bash
set -x

CURRENT_DIR="$(pwd)"
: "${TREASUREMAP_PATH:="../treasuremap"}"

cd "${TREASUREMAP_PATH}" || exit
bash -c "./tools/deployment/airskiff/developer/010-deploy-k8s.sh"

if [ -d /home/zuul ]
then
    sudo cp -a /root/.kube /home/zuul/
    sudo chown -R zuul /home/zuul/.kube
fi
kubectl create namespace utility

cd "${CURRENT_DIR}" || exit