#!/bin/bash
set -xe

CURRENT_DIR="$(pwd)"
: "${INSTALL_PATH:="../"}"
: "${OSH_INFRA_COMMIT:="8ba46703ee9fab0115e4b7f62ea43e0798c36872"}"
: "${CLONE_ARMADA:=true}"
: "${CLONE_DECKHAND:=true}"
: "${CLONE_SHIPYARD:=true}"

cd ${INSTALL_PATH}

# Clone Airship projects
if [[ ${CLONE_ARMADA} = true ]] ; then
    git clone https://opendev.org/airship/armada.git
fi
if [[ ${CLONE_DECKHAND} = true ]] ; then
    git clone https://opendev.org/airship/deckhand.git
fi
if [[ ${CLONE_SHIPYARD} = true ]] ; then
    git clone https://opendev.org/airship/shipyard.git
fi

# Clone dependencies
git clone https://opendev.org/openstack/openstack-helm-infra.git

cd openstack-helm-infra
git checkout "${OSH_INFRA_COMMIT}"
