#!/bin/bash
set -xe
kubectl label nodes --all openstack-helm-node-class=primary --overwrite
helm dependency update charts/mysqlclient-utility
cd charts
helm  upgrade --install mysqlclient-utility ./mysqlclient-utility  --namespace=utility

#NOTE: Validate Deployment info
kubectl get pods -n utility | grep mysqlclient-utility
