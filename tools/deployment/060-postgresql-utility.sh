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

# NOTE: Define variables
: ${OSH_PATH:="../openstack-helm"}
: ${OSH_INFRA_PATH:="../openstack-helm-infra"}

cd "${OSH_INFRA_PATH}" || exit

# NOTE: Lint and package postgresql helm chart
make postgresql SKIP_CHANGELOG=1

: ${OSH_INFRA_EXTRA_HELM_ARGS:=""}
: ${OSH_INFRA_VALUES_OVERRIDES_PATH:="../openstack-helm-infra/values_overrides"}
: ${OSH_INFRA_EXTRA_HELM_ARGS_POSTGRESQL:="$(helm osh get-values-overrides -p ${OSH_INFRA_VALUES_OVERRIDES_PATH} -c postgresql ${FEATURES})"}

# NOTE: Deploy postgresql helm chart
helm upgrade --install postgresql ./postgresql \
             --namespace=osh-infra \
             --set monitoring.prometheus.enabled=true \
             --set storage.pvc.size=1Gi \
             --set storage.pvc.enabled=true \
             --set pod.replicas.server=1 \
             ${OSH_INFRA_EXTRA_HELM_ARGS} \
             ${OSH_INFRA_EXTRA_HELM_ARGS_POSTGRESQL}

# NOTE: Wait for deploy
helm osh wait-for-pods osh-infra

cd ${CURRENT_DIR}

# NOTE: Define variables
: ${HELM_CHART_ROOT_PATH:="${PORTHOLE_PATH:="../porthole/charts"}"}
: ${PORTHOLE_VALUES_OVERRIDES_PATH:="../porthole/charts/values_overrides"}
: ${PORTHOLE_EXTRA_HELM_ARGS_POSTGRESQL_UTILITY:="$(helm osh get-values-overrides -p ${PORTHOLE_VALUES_OVERRIDES_PATH} -c postgresql-utility ${FEATURES})"}
: ${NAMESPACE:=utility}

# NOTE: Deploy postgresql-utility helm chart
helm upgrade --install postgresql-utility ./artifacts/postgresql-utility.tgz \
             --namespace=${NAMESPACE} \
             --set "conf.postgresql_backup_restore.enabled_namespaces=osh-infra" \
             ${PORTHOLE_EXTRA_HELM_ARGS_POSTGRESQL_UTILITY}

# Wait for deploy
helm osh wait-for-pods ${NAMESPACE}

