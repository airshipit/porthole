#!/bin/bash
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

CURRENT_DIR="$(pwd)"

# NOTE: Resolve the shared helpers before any cd, so they can be called from
# anywhere in this script.
COMMON_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/common" && pwd)"

# NOTE: Define variables
: ${OSH_PATH:="../../openstack/openstack-helm"}
: ${NAMESPACE:=utility}

cd "${OSH_PATH}" || exit

# NOTE: Lint and package ceph helm charts
for CHART in ceph-mon ceph-osd ceph-client ceph-provisioners; do
  make "${CHART}" SKIP_CHANGELOG=1
done

# NOTE: Deploy the ceph charts. This used to be openstack-helm's
# tools/deployment/ceph/ceph.sh, which upstream retired along with the rest of
# tools/deployment; we now carry it in common/. It is still run from the
# openstack-helm directory, since OSH_HELM_REPO and OSH_VALUES_OVERRIDES_PATH
# are relative to that.
"${COMMON_DIR}/ceph.sh"

cd "${OSH_PATH}"

tee /tmp/ceph-utility-config.yaml <<EOF
endpoints:
  identity:
    namespace: openstack
  object_store:
    namespace: ceph
  ceph_mon:
    namespace: ceph
network:
  public: 172.17.0.1/16
  cluster: 172.17.0.1/16
deployment:
  storage_secrets: false
  ceph: false
  rbd_provisioner: false
  cephfs_provisioner: false
  csi_rbd_provisioner: false
  client_secrets: true
  rgw_keystone_user_and_endpoints: false
bootstrap:
  enabled: false
conf:
  rgw_ks:
    enabled: true
EOF

: ${OSH_EXTRA_HELM_ARGS:=""}
: ${OSH_VALUES_OVERRIDES_PATH:="../../openstack/openstack-helm/values_overrides"}
: ${OSH_EXTRA_HELM_ARGS_CEPH_DEPLOY:="$(${COMMON_DIR}/get-values-overrides.sh -p ${OSH_VALUES_OVERRIDES_PATH} -c ceph-provisioners ${FEATURES})"}

# NOTE: Deploy ceph-provisioners helm chart
helm upgrade --install ceph-utility-config ./ceph-provisioners \
             --namespace=${NAMESPACE} \
             --values=/tmp/ceph-utility-config.yaml \
             ${OSH_EXTRA_HELM_ARGS} \
             ${OSH_EXTRA_HELM_ARGS_CEPH_DEPLOY} \
             ${OSH_EXTRA_HELM_ARGS_CEPH_NS_ACTIVATE}

# NOTE: Wait for deploy
${COMMON_DIR}/wait-for-pods.sh ${NAMESPACE}

cd ${CURRENT_DIR}

# NOTE: Define variables
: ${HELM_CHART_ROOT_PATH:="${PORTHOLE_PATH:="../porthole/charts"}"}
: ${PORTHOLE_VALUES_OVERRIDES_PATH:="../porthole/charts/values_overrides"}
: ${PORTHOLE_EXTRA_HELM_ARGS_CEPH_UTILITY:="$(${COMMON_DIR}/get-values-overrides.sh -p ${PORTHOLE_VALUES_OVERRIDES_PATH} -c ceph-utility ${FEATURES})"}

# NOTE: Deploy ceph-utility helm chart
helm upgrade --install ceph-utility ./artifacts/ceph-utility.tgz \
             --namespace=${NAMESPACE} \
             ${PORTHOLE_EXTRA_HELM_ARGS_CEPH_UTILITY}

# NOTE: Wait for deploy
${COMMON_DIR}/wait-for-pods.sh ${NAMESPACE}

