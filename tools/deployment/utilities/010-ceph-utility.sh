#!/bin/bash
set -xe

#NOTE: Lint and package chart
: ${OSH_INFRA_PATH:="../../openstack-helm-infra"}
#: ${PORTHOLE_PATH}:=""
make -C ${OSH_INFRA_PATH} ceph-provisioners

#NOTE: Deploy command
: ${OSH_EXTRA_HELM_ARGS:=""}
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
  client_secrets: true
  rgw_keystone_user_and_endpoints: false
bootstrap:
  enabled: false
conf:
  rgw_ks:
    enabled: true
EOF
helm upgrade --install ceph-utility-config ${OSH_INFRA_PATH}/ceph-provisioners \
  --namespace=utility \
  --values=/tmp/ceph-utility-config.yaml \
  ${OSH_EXTRA_HELM_ARGS} \
  ${OSH_EXTRA_HELM_ARGS_CEPH_NS_ACTIVATE}

#NOTE: Wait for deploy
./${OSH_INFRA_PATH}/tools/deployment/common/wait-for-pods.sh utility

cd charts
make ceph-utility
helm upgrade --install ceph-utility ./ceph-utility \
  --namespace=utility

#NOTE: Validate Deployment info
kubectl get -n utility jobs
kubectl get -n utility secrets
kubectl get -n utility configmaps
