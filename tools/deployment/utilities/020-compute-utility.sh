#!/bin/bash
set -xe

kubectl label nodes --all openstack-helm-node-class=primary --overwrite

helm dependency update charts/compute-utility
cd charts
helm  upgrade --install compute-utility ./compute-utility --namespace=utility

#NOTE: Validate Deployment info
kubectl get -n utility jobs
kubectl get -n utility configmaps
kubectl get -n utility pods | grep compute-utility
