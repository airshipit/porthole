#!/bin/bash

CURRENT_DIR="$(pwd)"
: "${OSH_INFRA_PATH:="../openstack-helm-infra"}"

cd "${OSH_INFRA_PATH}"
bash -c "./tools/deployment/common/005-deploy-k8s.sh"