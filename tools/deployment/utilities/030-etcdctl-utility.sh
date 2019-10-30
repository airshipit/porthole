#!/bin/bash
set -xe

#NOTE: Lint and package chart
: ${OSH_INFRA_PATH:="../../openstack-helm-infra"}

cd charts

make etcdctl-utility

helm  upgrade --install etcdctl-utility ./etcdctl-utility --namespace=utility

#NOTE: Validate Deployment info
kubectl get -n utility secrets
kubectl get -n utility configmaps
kubectl get pods -n utility
