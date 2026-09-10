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

# NOTE: Resolve the shared helpers before any cd, so they can be called from
# anywhere in this script.
COMMON_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/common" && pwd)"

# NOTE: Define variables
: ${OSH_PATH:="../../openstack/openstack-helm"}

# NOTE: The mariadb server data volume deliberately does not use the "general"
# (Ceph RBD) storage class. That class uses the rbd-nbd mounter, and under the
# write load of mariadb's bootstrap the nbd session desynchronises:
#
#   rbd-nbd: failed to read nbd request data: (33) Numerical argument out of domain
#   block nbd0: Double reply on req ..., cmd_cookie 20, handle cookie 18
#   block nbd0: Dead connection, failed to find a fallback
#
# The device then fails every write, ext4 aborts its journal and remounts read
# only, and mysqld dies mid-bootstrap leaving the cluster stuck in "init".
# The Ceph cluster itself stays HEALTH_OK throughout - this is a client side
# protocol fault, not a storage capacity or cluster problem.
#
# Upstream openstack-helm's own mariadb job avoids this the same way, by
# backing a single pod cluster with a host path instead of a PVC. The volume
# under test here is the backup PVC, not the server data volume, so this does
# not reduce what the mysqlclient-utility test actually covers.
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
  enabled: false
  use_local_path_for_single_pod_cluster:
    enabled: true
EOF

cd "${OSH_PATH}" || exit

# NOTE: Lint and package mariadb helm chart
make mariadb SKIP_CHANGELOG=1

: ${OSH_EXTRA_HELM_ARGS:=""}
: ${OSH_VALUES_OVERRIDES_PATH:="../../openstack/openstack-helm/values_overrides"}
: ${OSH_EXTRA_HELM_ARGS_MARIADB:="$(${COMMON_DIR}/get-values-overrides.sh -p ${OSH_VALUES_OVERRIDES_PATH} -c mariadb ${FEATURES})"}

# NOTE: Deploy mariadb helm chart
helm upgrade --install mariadb ./mariadb \
             --namespace=openstack \
             --values /tmp/mariadb-server-config.yaml \
             --set pod.replicas.server=1 \
             ${OSH_EXTRA_HELM_ARGS} \
             ${OSH_EXTRA_HELM_ARGS_MARIADB}

# NOTE: Wait for deploy
${COMMON_DIR}/wait-for-pods.sh openstack

cd "${CURRENT_DIR}"

# NOTE: Define variables
: ${HELM_CHART_ROOT_PATH:="${PORTHOLE_PATH:="../porthole/charts"}"}
: ${PORTHOLE_VALUES_OVERRIDES_PATH:="../porthole/charts/values_overrides"}
: ${PORTHOLE_EXTRA_HELM_ARGS_MYSQLCLIENT_UTILITY:="$(${COMMON_DIR}/get-values-overrides.sh -p ${PORTHOLE_VALUES_OVERRIDES_PATH} -c mysqlclient-utility ${FEATURES})"}
: ${NAMESPACE:=utility}

# NOTE: Deploy mysqlclient-utility helm chart
helm upgrade --install mysqlclient-utility ./artifacts/mysqlclient-utility.tgz \
             --namespace=${NAMESPACE} \
             --set "conf.mariadb_backup_restore.enabled_namespaces=openstack" \
             ${PORTHOLE_EXTRA_HELM_ARGS_MYSQLCLIENT_UTILITY}

# Wait for deploy
${COMMON_DIR}/wait-for-pods.sh ${NAMESPACE}

