#!/bin/bash
set -xe
namespace=utility
helm dependency update charts/postgresql-utility
helm upgrade --install postgresql-utility ./charts/postgresql-utility --namespace=$namespace

# Wait for Deployment
: "${OSH_INFRA_PATH:="../../openstack-helm-infra"}"
cd "${OSH_INFRA_PATH}"
./tools/deployment/common/wait-for-pods.sh $namespace