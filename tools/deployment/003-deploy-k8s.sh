#!/bin/bash

CURRENT_DIR="$(pwd)"
: "${OSH_INFRA_PATH:="../openstack-helm-infra"}"

./helm serve
curl -i http://localhost:8879/charts/

cd "${OSH_INFRA_PATH}"
bash -c "./tools/deployment/common/005-deploy-k8s.sh"

kubectl create namespace utility


curl -i http://localhost:8879/charts/
