#!/bin/bash
set -xe
kubectl label nodes --all openstack-helm-node-class=enabled --overwrite

helm dependency update charts/calicoctl-utility
cd charts
helm  upgrade --install calicoctl-utility ./calicoctl-utility --namespace=utility

#NOTE: Validate Deployment info
kubectl get -n utility secrets
kubectl get -n utility configmaps
kubectl get pods -n utility | grep calicoctl-utility
