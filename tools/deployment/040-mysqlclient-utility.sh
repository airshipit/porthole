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
 : "${OSH_PATH:="../openstack-helm"}"

# Deploy mariadb server
cd "${OSH_PATH}"
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
volume:
  class_name: standard
  backup:
    class_name: standard
EOF

export HELM_CHART_ROOT_PATH="${HELM_CHART_ROOT_PATH:="${OSH_INFRA_PATH:="../openstack-helm-infra"}"}"
: ${OSH_EXTRA_HELM_ARGS_MARIADB:="$(./tools/deployment/common/get-values-overrides.sh mariadb)"}

#NOTE: Lint and package chart
make -C "${HELM_CHART_ROOT_PATH}" mariadb

#NOTE: Deploy command
: ${OSH_EXTRA_HELM_ARGS:=""}
helm upgrade --install mariadb ${HELM_CHART_ROOT_PATH}/mariadb \
    --namespace=openstack \
    --values /tmp/mariadb-server-config.yaml \
    --set pod.replicas.server=1 \
    ${OSH_EXTRA_HELM_ARGS} \
    ${OSH_EXTRA_HELM_ARGS_MARIADB}

#NOTE: Wait for deploy
./tools/deployment/common/wait-for-pods.sh openstack

# Deploy mysqlclient-utility
cd "${CURRENT_DIR}"

namespace="utility"

export HELM_CHART_ROOT_PATH="${PORTHOLE_PATH:="../porthole/charts"}"
: ${PORTHOLE_EXTRA_HELM_ARGS_MYSQLCLIENT_UTILITY:="$(./tools/deployment/get-values-overrides.sh mysqlclient-utility)"}

helm upgrade --install mysqlclient-utility ./artifacts/mysqlclient-utility.tgz --namespace=$namespace \
    --set "conf.mariadb_backup_restore.enabled_namespaces=openstack" \
    ${PORTHOLE_EXTRA_HELM_ARGS_MYSQLCLIENT_UTILITY}

# Wait for Deployment
: "${OSH_INFRA_PATH:="../openstack-helm-infra"}"
cd "${OSH_INFRA_PATH}"
./tools/deployment/common/wait-for-pods.sh $namespace
