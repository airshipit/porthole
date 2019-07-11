#!/bin/bash
set -xe

#NOTE: Lint and package chart
: ${OSH_INFRA_PATH:="../../openstack-helm-infra"}

typeset uc=mysqlclient-utility

make ${uc}
helm  upgrade --install ${uc} ${uc} --namespace=utility

#NOTE: Wait for deploy
./${OSH_INFRA_PATH}/tools/deployment/common/wait-for-pods.sh utility

#NOTE: Validate Deployment info
kubectl get pods -n utility |grep ${uc}
helm status ${uc}

helm test ${uc} --timeout 900
