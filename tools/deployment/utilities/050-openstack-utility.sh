#!/bin/bash
set -xe

kubectl label nodes --all openstack-helm-node-class=primary --overwrite
helm dependency update charts/calicoctl-utility
cd charts
helm  upgrade --install openstack-utility ./openstack-utility --namespace=utility

#NOTE: Validate Deployment info
kubectl get pods --all-namespaces | grep openstack-utility
helm status openstack-utility
export OS_CLOUD=openstack_helm
sleep 30 #NOTE(portdirect): Wait for ingress controller to update rules and restart Nginx
openstack endpoint list
