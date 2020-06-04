#!/bin/bash
set -xe
namespace=utility
helm dependency update charts/calicoctl-utility
helm  upgrade --install calicoctl-utility ./charts/calicoctl-utility --namespace=$namespace


# Wait for Deployment
: "${OSH_INFRA_PATH:="../../openstack-helm-infra"}"
cd "${OSH_INFRA_PATH}"
./tools/deployment/common/wait-for-pods.sh $namespace

#NOTE: Validate Deployment info
kubectl get -n $namespace secrets
kubectl get -n $namespace configmaps
kubectl get pods -n $namespace | grep calicoctl-utility