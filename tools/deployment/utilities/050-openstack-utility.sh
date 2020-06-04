#!/bin/bash
set -xe
namespace=utility
helm dependency update charts/openstack-utility
helm  upgrade --install openstack-utility ./charts/openstack-utility --namespace=$namespace

# Wait for Deployment
: "${OSH_INFRA_PATH:="../openstack-helm-infra"}"
cd "${OSH_INFRA_PATH}"
./tools/deployment/common/wait-for-pods.sh $namespace

#NOTE: Validate Deployment info
helm status openstack-utility
export OS_CLOUD=openstack_helm
sleep 30 #NOTE(portdirect): Wait for ingress controller to update rules and restart Nginx
openstack endpoint list