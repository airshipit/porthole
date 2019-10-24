#!/bin/bash

set -xe
CURRENT_DIR="$(pwd)"
cd "${CURRENT_DIR}"/charts

kubectl label nodes --all openstack-helm-node-class=primary --overwrite

helm upgrade --install postgresql-utility ./postgresql-utility --namespace=utility
sleep 60

#NOTE: Validate Deployment info
kubectl get pods --all-namespaces | grep postgresql-utility