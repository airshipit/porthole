#!/bin/bash
set -xe

#NOTE: Lint and package chart
: ${OSH_INFRA_PATH:="../../openstack-helm-infra"}

cd charts

make compute-utility

helm  upgrade --install compute-utility ./compute-utility --namespace=utility

#NOTE: Validate Deployment info
kubectl get -n utility jobs
kubectl get -n utility secrets
kubectl get -n utility configmaps
kubectl get -n utility pods
