#!/bin/bash
set -xe
CURRENT_DIR="$(pwd)"
cd "${CURRENT_DIR}"/charts

make etcdctl-utility
kubectl label nodes --all openstack-helm-node-class=primary --overwrite

helm  upgrade --install etcdctl-utility ./etcdctl-utility --namespace=utility

#NOTE: Validate Deployment info
kubectl get -n utility secrets
kubectl get -n utility configmaps
kubectl get pods -n utility
