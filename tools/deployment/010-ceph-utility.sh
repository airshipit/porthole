#!/bin/bash
CURRENT_DIR="$(pwd)"
 : "${OSH_PATH:="../openstack-helm"}"
 : "${OSH_INFRA_PATH:="../openstack-helm-infra"}"

cd "${OSH_PATH}"
bash -c "./tools/deployment/component/ceph/ceph.sh"

namespace="utility"
: ${OSH_EXTRA_HELM_ARGS:=""}

cd "${OSH_INFRA_PATH}"
#Deploy Ceph-provisioners
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
pod:
  mandatory_access_control:
    type: apparmor
    ceph-utility-config-ceph-ns-key-generator :
      ceph-storage-keys-generator: runtime/default
      init: runtime/default
EOF

helm upgrade --install ceph-utility-config ./ceph-provisioners \
  --namespace=$namespace \
  --values=/tmp/ceph-utility-config.yaml \
  ${OSH_EXTRA_HELM_ARGS} \
  ${OSH_INFRA_EXTRA_HELM_ARGS_CEPH_DEPLOY:-$(./tools/deployment/common/get-values-overrides.sh  ceph-provisioners)} \
  ${OSH_EXTRA_HELM_ARGS_CEPH_NS_ACTIVATE}

# Deploy Ceph-Utility
cd ${CURRENT_DIR}
helm dependency update charts/ceph-utility
helm upgrade --install ceph-utility ./charts/ceph-utility --namespace=$namespace

# Wait for Deployment
: "${OSH_INFRA_PATH:="../openstack-helm-infra"}"
cd "${OSH_INFRA_PATH}"
./tools/deployment/common/wait-for-pods.sh $namespace