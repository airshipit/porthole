#!/bin/bash
set -xe

#NOTE: Lint and package chart
: ${OSH_INFRA_PATH:="../openstack-helm-infra"}

make openstack-utility

helm  upgrade --install openstack-utility openstack-utility --namespace=utility

#NOTE: Wait for deploy
./${OSH_INFRA_PATH}/tools/deployment/common/wait-for-pods.sh utility

#NOTE: Validate Deployment info
kubectl get pods --all-namespaces | grep openstack-utility
helm status openstack-utility
export OS_CLOUD=openstack_helm
sleep 30 #NOTE(portdirect): Wait for ingress controller to update rules and restart Nginx
openstack endpoint list
helm test openstack-utility --timeout 900
