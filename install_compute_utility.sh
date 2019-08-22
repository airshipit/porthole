#!/bin/bash
set -xe

#NOTE: Lint and package chart
: ${OSH_INFRA_PATH:="../../openstack-helm-infra"}

make compute-utility

helm  upgrade --install compute-utility compute-utility --namespace=utility

#NOTE: Wait for deploy
./${OSH_INFRA_PATH}/tools/deployment/common/wait-for-pods.sh utility

#NOTE: Validate Deployment info
kubectl get -n utility jobs
kubectl get -n utility secrets
kubectl get -n utility configmaps
kubectl get -n utility pods
