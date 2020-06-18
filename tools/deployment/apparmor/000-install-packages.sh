#!/bin/bash
set -xe
: "${INSTALL_PATH:="../"}"
cd ${INSTALL_PATH}

# Clone dependencies
git clone https://opendev.org/openstack/openstack-helm-infra.git
bash -c "./openstack-helm-infra/tools/deployment/common/000-install-packages.sh"