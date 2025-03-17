#!/bin/bash
#    Licensed under the Apache License, Version 2.0 (the "License"); you may
#    not use this file except in compliance with the License. You may obtain
#    a copy of the License at
#
#         http://www.apache.org/licenses/LICENSE-2.0
#
#    Unless required by applicable law or agreed to in writing, software
#    distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
#    WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
#    License for the specific language governing permissions and limitations
#    under the License.
set -xe

CURRENT_DIR="$(pwd)"
 : "${OSH_INFRA_PATH:="../openstack-helm-infra"}"

# Deploy postgresql server
cd "${OSH_INFRA_PATH}"
# bash -c "./tools/deployment/common/postgresql.sh"

#NOTE: Lint and package chart
make postgresql SKIP_CHANGELOG=1

#NOTE: Deploy command
: ${OSH_INFRA_EXTRA_HELM_ARGS:=""}
: ${OSH_INFRA_EXTRA_HELM_ARGS_POSTGRESQL:="$(helm osh get-values-overrides -c postgresql)"}

helm upgrade --install postgresql ./postgresql \
    --namespace=osh-infra \
    --set monitoring.prometheus.enabled=true \
    --set storage.pvc.size=1Gi \
    --set storage.pvc.enabled=true \
    --set pod.replicas.server=1 \
    ${OSH_INFRA_EXTRA_HELM_ARGS} \
    ${OSH_INFRA_EXTRA_HELM_ARGS_POSTGRESQL}

#NOTE: Wait for deploy
helm osh wait-for-pods osh-infra

# Deploy postgresql-utility
cd ${CURRENT_DIR}

namespace="utility"

export HELM_CHART_ROOT_PATH="${HELM_CHART_ROOT_PATH:="${PORTHOLE_PATH:="../porthole/charts"}"}"
: ${PORTHOLE_EXTRA_HELM_ARGS_POSTGRESQL_UTILITY:="$(./tools/deployment/get-values-overrides.sh -c postgresql-utility)"}

helm upgrade --install postgresql-utility ./artifacts/postgresql-utility.tgz --namespace=$namespace \
    --set "conf.postgresql_backup_restore.enabled_namespaces=osh-infra" \
    ${PORTHOLE_EXTRA_HELM_ARGS_POSTGRESQL_UTILITY}


# Wait for Deployment
: "${OSH_INFRA_PATH:="../openstack-helm-infra"}"
cd "${OSH_INFRA_PATH}"
helm osh wait-for-pods $namespace
