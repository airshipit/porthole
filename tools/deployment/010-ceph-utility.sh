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
  client_secrets: true
  rgw_keystone_user_and_endpoints: false
bootstrap:
  enabled: false
conf:
  rgw_ks:
    enabled: true
EOF

helm upgrade --install ceph-utility-config ./ceph-provisioners \
  --namespace=$namespace \
  --values=/tmp/ceph-utility-config.yaml \
  ${OSH_EXTRA_HELM_ARGS} \
  ${OSH_EXTRA_HELM_ARGS_CEPH_NS_ACTIVATE}

# Deploy Ceph-Utility
cd ${CURRENT_DIR}
helm dependency update charts/ceph-utility
helm upgrade --install ceph-utility ./charts/ceph-utility --namespace=$namespace

# Wait for Deployment
: "${OSH_INFRA_PATH:="../openstack-helm-infra"}"
cd "${OSH_INFRA_PATH}"
./tools/deployment/common/wait-for-pods.sh $namespace

#Validate Apparmor
ceph_pod=$(kubectl get pods --namespace=$namespace  -o wide | grep ceph |  grep 1/1  | awk '{print $1}')
expected_profile="docker-default (enforce)"
profile=`kubectl -n $namespace exec $ceph_pod -- cat /proc/1/attr/current`
echo "Profile running: $profile"
  if test "$profile" != "$expected_profile"
  then
    if test "$proc_name" == "pause"
    then
      echo "Root process (pause) can run docker-default, it's ok."
    else
      echo "$profile is the WRONG PROFILE!!"
      return 1
    fi
  fi