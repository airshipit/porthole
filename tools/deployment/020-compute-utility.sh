#!/bin/bash
#
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
namespace="utility"

export HELM_CHART_ROOT_PATH="${HELM_CHART_ROOT_PATH:="${PORTHOLE_PATH:="../porthole/charts"}"}"
: ${PORTHOLE_EXTRA_HELM_ARGS_COMPUTE_UTILITY:="$(./tools/deployment/get-values-overrides.sh compute-utility)"}

helm upgrade --install compute-utility ./artifacts/compute-utility.tgz --namespace=$namespace \
    ${PORTHOLE_EXTRA_HELM_ARGS_COMPUTE_UTILITY}


# Wait for Deployment
: "${OSH_INFRA_PATH:="../openstack-helm-infra"}"
cd "${OSH_INFRA_PATH}"
helm osh wait-for-pods $namespace