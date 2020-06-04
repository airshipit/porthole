#!/bin/bash
set -xe

CURRENT_DIR="$(pwd)"
: "${INSTALL_PATH:="../"}"
: "${OSH_INFRA_COMMIT:="8ba46703ee9fab0115e4b7f62ea43e0798c36872"}"
cd ${INSTALL_PATH}

# Clone dependencies
git clone https://opendev.org/openstack/openstack-helm-infra.git

cd openstack-helm-infra
git checkout "${OSH_INFRA_COMMIT}"