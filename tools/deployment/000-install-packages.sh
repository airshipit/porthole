#!/bin/bash
set -xe
: "${INSTALL_PATH:="../"}"
cd ${INSTALL_PATH}

# Clone dependencies
rm -rf openstack-helm-infra
rm -rf openstack-helm
git clone https://opendev.org/openstack/openstack-helm-infra.git
git clone https://opendev.org/openstack/openstack-helm.git
# Install Packages
bash -c "./openstack-helm-infra/tools/deployment/common/000-install-packages.sh"

sudo apt-get update
sudo apt-get install --no-install-recommends -y \
        lvm2