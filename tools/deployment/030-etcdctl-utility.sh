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

# NOTE: Define variables
: ${HELM_CHART_ROOT_PATH:="${PORTHOLE_PATH:="../porthole/charts"}"}
: ${PORTHOLE_VALUES_OVERRIDES_PATH:="../porthole/charts/values_overrides"}
: ${PORTHOLE_EXTRA_HELM_ARGS_ETCDCTL_UTILITY:="$(helm osh get-values-overrides -p ${PORTHOLE_VALUES_OVERRIDES_PATH} -c etcdctl-utility ${FEATURES})"}
: ${NAMESPACE:=utility}

# NOTE: Deploy etcdctl-utility helm chart
helm upgrade --install etcdctl-utility ./artifacts/etcdctl-utility.tgz \
             --namespace=${NAMESPACE} \
             ${PORTHOLE_EXTRA_HELM_ARGS_ETCDCTL_UTILITY}

# NOTE: Wait for deploy
helm osh wait-for-pods ${NAMESPACE}

