#!/bin/bash
set -x

CURRENT_DIR="$(pwd)"
: "${OSH_INFRA_PATH:="../openstack-helm-infra"}"

cd "${OSH_INFRA_PATH}"
bash -c "./tools/deployment/common/005-deploy-k8s.sh"

if [ -d /home/zuul ]
then
    sudo cp -a /root/.kube /home/zuul/
    sudo chown -R zuul /home/zuul/.kube
fi
kubectl create namespace utility
