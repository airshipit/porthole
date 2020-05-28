#!/bin/bash
set -xe
CURRENT_DIR="$(pwd)"
: "${OSH_INFRA_PATH:="../openstack-helm-infra"}"

cd "${OSH_INFRA_PATH}"
bash -c "./tools/deployment/common/001-setup-apparmor-profiles.sh"