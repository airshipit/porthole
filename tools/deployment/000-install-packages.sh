#!/bin/bash

# Copyright 2017 The Airship Authors.
# Copyright 2018 AT&T Intellectual Property.  All other rights reserved.
#
#    Licensed under the Apache License, Version 2.0 (the "License"); you may
#    not use this file except in compliance with the License. You may obtain
#    a copy of the License at
#
#         http://www.apache.org/licenses/LICENSE-2.0
#
#    Unless required by applicable law or agreed to in writing, software
#    distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
#    WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
#    License for the specific language governing permissions and limitations
#    under the License.


set -xe

: "${INSTALL_PATH:="../"}"
: "${OSH_COMMIT:="2d9457e34ca4200ed631466bd87569b0214c92e7"}"
: "${OSH_INFRA_COMMIT:="cfff60ec10a6c386f38db79bb9f59a552c2b032f"}"
: "${CLONE_ARMADA:=false}"
: "${CLONE_DECKHAND:=false}"
: "${CLONE_SHIPYARD:=false}"
: "${CLONE_PORTHOLE:=false}"
: "${CLONE_MAAS:=false}"
: "${CLONE_OSH:=true}"

export INSTALL_PATH=${INSTALL_PATH}
export CLONE_ARMADA=${CLONE_ARMADA}
export CLONE_DECKHAND=${CLONE_DECKHAND}
export CLONE_SHIPYARD=${CLONE_SHIPYARD}
export CLONE_PORTHOLE=${CLONE_PORTHOLE}
export CLONE_MAAS=${CLONE_MAAS}
export CLONE_OSH=${CLONE_OSH}

cd "${INSTALL_PATH}"

# Clone dependencies
rm -rf treasuremap
rm -rf openstack-helm-infra
rm -rf openstack-helm
rm -rf maas
git clone https://opendev.org/airship/treasuremap.git
pushd treasuremap
git checkout v1.9


# Install Packages
pwd
bash -c "./tools/deployment/airskiff/developer/000-clone-dependencies.sh"

find .. -maxdepth 1 -type d -print -exec sudo chmod -R o+rwx {} \;

sudo apt-get update
sudo apt-get install --no-install-recommends -y \
        lvm2 \
        ca-certificates \
        python3-certifi