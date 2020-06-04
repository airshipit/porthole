#!/bin/bash
set -xe
namespace=utility
helm dependency update charts/mysqlclient-utility
helm  upgrade --install mysqlclient-utility ./charts/mysqlclient-utility  --namespace=$namespace

# Wait for Deployment
: "${OSH_INFRA_PATH:="../../openstack-helm-infra"}"
cd "${OSH_INFRA_PATH}"
./tools/deployment/common/wait-for-pods.sh $namespace