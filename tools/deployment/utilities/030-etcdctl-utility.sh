#!/bin/bash
set -xe
namespace=utility
helm dependency update charts/etcdctl-utility
helm  upgrade --install etcdctl-utility ./charts/etcdctl-utility --namespace=$namespace

# Wait for Deployment
: "${OSH_INFRA_PATH:="../../openstack-helm-infra"}"
cd "${OSH_INFRA_PATH}"
./tools/deployment/common/wait-for-pods.sh $namespace