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

# NOTE: Define variables
: ${OSH_PATH:="../../openstack/openstack-helm"}
: ${NAMESPACE:=utility}

cd "${OSH_PATH}" || exit

# NOTE: Lint and package ceph helm charts
for CHART in ceph-mon ceph-osd ceph-client ceph-provisioners; do
  make "${CHART}" SKIP_CHANGELOG=1
done

./tools/deployment/ceph/ceph.sh

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
: ${OSH_EXTRA_HELM_ARGS_CEPH_DEPLOY:="$(helm osh get-values-overrides -p ${OSH_VALUES_OVERRIDES_PATH} -c ceph-provisioners ${FEATURES})"}

# NOTE: Deploy ceph-provisioners helm chart
helm upgrade --install ceph-utility-config ./ceph-provisioners \
             --namespace=${NAMESPACE} \
             --values=/tmp/ceph-utility-config.yaml \
             ${OSH_EXTRA_HELM_ARGS} \
             ${OSH_EXTRA_HELM_ARGS_CEPH_DEPLOY} \
             ${OSH_EXTRA_HELM_ARGS_CEPH_NS_ACTIVATE}

# NOTE: Wait for deploy
helm osh wait-for-pods ${NAMESPACE}

cd ${CURRENT_DIR}

# NOTE: Define variables
: ${HELM_CHART_ROOT_PATH:="${PORTHOLE_PATH:="../porthole/charts"}"}
: ${PORTHOLE_VALUES_OVERRIDES_PATH:="../porthole/charts/values_overrides"}
: ${PORTHOLE_EXTRA_HELM_ARGS_CEPH_UTILITY:="$(helm osh get-values-overrides -p ${PORTHOLE_VALUES_OVERRIDES_PATH} -c ceph-utility ${FEATURES})"}

# NOTE: Deploy ceph-utility helm chart
helm upgrade --install ceph-utility ./artifacts/ceph-utility.tgz \
             --namespace=${NAMESPACE} \
             ${PORTHOLE_EXTRA_HELM_ARGS_CEPH_UTILITY}

# NOTE: Wait for deploy
helm osh wait-for-pods ${NAMESPACE}

