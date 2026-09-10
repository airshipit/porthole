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

# NOTE: Resolve the shared helpers before any cd, so they can be called from
# anywhere in this script.
COMMON_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/common" && pwd)"

# NOTE: Define variables
: ${HELM_CHART_ROOT_PATH:="${PORTHOLE_PATH:="../porthole/charts"}"}
: ${PORTHOLE_VALUES_OVERRIDES_PATH:="../porthole/charts/values_overrides"}
: ${PORTHOLE_EXTRA_HELM_ARGS_CALICOCTL_UTILITY:="$(${COMMON_DIR}/get-values-overrides.sh -p ${PORTHOLE_VALUES_OVERRIDES_PATH} -c calicoctl-utility ${FEATURES})"}
: ${NAMESPACE:=utility}

# NOTE: Deploy calicoctl-utility helm chart
helm upgrade --install calicoctl-utility ./artifacts/calicoctl-utility.tgz \
             --namespace=${NAMESPACE} \
             ${PORTHOLE_EXTRA_HELM_ARGS_CALICOCTL_UTILITY}

# NOTE: Wait for deploy
${COMMON_DIR}/wait-for-pods.sh ${NAMESPACE}

