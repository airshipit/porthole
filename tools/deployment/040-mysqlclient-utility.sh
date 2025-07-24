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
: ${OSH_PATH:="../../openstack/openstack-helm"}

tee /tmp/mariadb-server-config.yaml <<EOF
conf:
  backup:
    enabled: true
secrets:
  mariadb:
    backup_restore: mariadb-backup-restore
manifests:
  cron_job_mariadb_backup: true
  secret_backup_restore: true
  pvc_backup: true
EOF

cd "${OSH_PATH}" || exit

# NOTE: Lint and package mariadb helm chart
make mariadb SKIP_CHANGELOG=1

: ${OSH_EXTRA_HELM_ARGS:=""}
: ${OSH_VALUES_OVERRIDES_PATH:="../../openstack/openstack-helm/values_overrides"}
: ${OSH_EXTRA_HELM_ARGS_MARIADB:="$(helm osh get-values-overrides -p ${OSH_VALUES_OVERRIDES_PATH} -c mariadb ${FEATURES})"}

# NOTE: Deploy mariadb helm chart
helm upgrade --install mariadb ./mariadb \
             --namespace=openstack \
             --values /tmp/mariadb-server-config.yaml \
             --set pod.replicas.server=1 \
             ${OSH_EXTRA_HELM_ARGS} \
             ${OSH_EXTRA_HELM_ARGS_MARIADB}

# NOTE: Wait for deploy
helm osh wait-for-pods openstack

cd "${CURRENT_DIR}"

# NOTE: Define variables
: ${HELM_CHART_ROOT_PATH:="${PORTHOLE_PATH:="../porthole/charts"}"}
: ${PORTHOLE_VALUES_OVERRIDES_PATH:="../porthole/charts/values_overrides"}
: ${PORTHOLE_EXTRA_HELM_ARGS_MYSQLCLIENT_UTILITY:="$(helm osh get-values-overrides -p ${PORTHOLE_VALUES_OVERRIDES_PATH} -c mysqlclient-utility ${FEATURES})"}
: ${NAMESPACE:=utility}

# NOTE: Deploy mysqlclient-utility helm chart
helm upgrade --install mysqlclient-utility ./artifacts/mysqlclient-utility.tgz \
             --namespace=${NAMESPACE} \
             --set "conf.mariadb_backup_restore.enabled_namespaces=openstack" \
             ${PORTHOLE_EXTRA_HELM_ARGS_MYSQLCLIENT_UTILITY}

# Wait for deploy
helm osh wait-for-pods ${NAMESPACE}

