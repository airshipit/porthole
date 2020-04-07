#!/bin/bash

set -xe
kubectl label nodes --all openstack-helm-node-class=primary --overwrite
helm dependency update charts/postgresql-utility
cd charts
helm upgrade --install postgresql-utility ./postgresql-utility --namespace=utility
sleep 60

#NOTE: Validate Deployment info
kubectl get pods -n utility | grep postgresql-utility
