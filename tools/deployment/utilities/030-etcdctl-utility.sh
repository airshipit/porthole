#!/bin/bash
set -xe
kubectl label nodes --all openstack-helm-node-class=primary --overwrite

helm dependency update charts/etcdctl-utility
cd charts
helm  upgrade --install etcdctl-utility ./etcdctl-utility --namespace=utility

#NOTE: Validate Deployment info
kubectl get -n utility secrets
kubectl get -n utility configmaps
kubectl get pods -n utility | grep etcdctl-utility
