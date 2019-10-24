#!/bin/bash
set -xe
CURRENT_DIR="$(pwd)"
cd "${CURRENT_DIR}"/charts

make compute-utility
kubectl label nodes --all openstack-helm-node-class=primary --overwrite
helm  upgrade --install compute-utility ./compute-utility --namespace=utility

#NOTE: Validate Deployment info
kubectl get -n utility jobs
kubectl get -n utility secrets
kubectl get -n utility configmaps
kubectl get -n utility pods
