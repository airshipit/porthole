#!/bin/bash
set -xe

#NOTE: Lint and package chart
: ${OSH_INFRA_PATH:="../../openstack-helm-infra"}

cd charts

make mysqlclient-utility

helm  upgrade --install mysqlclient-utility ./mysqlclient-utility  --namespace=utility

#NOTE: Validate Deployment info
kubectl get pods -n utility |grep mysqlclient-utility
helm status mysqlclient-utility
