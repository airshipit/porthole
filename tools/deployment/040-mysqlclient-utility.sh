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
namespace="utility"
helm dependency update charts/mysqlclient-utility
helm upgrade --install mysqlclient-utility ./charts/mysqlclient-utility --namespace=$namespace

# Wait for Deployment
: "${OSH_INFRA_PATH:="../openstack-helm-infra"}"
cd "${OSH_INFRA_PATH}"
./tools/deployment/common/wait-for-pods.sh $namespace

#Validate Apparmor
mysql_pod=$(kubectl get pods --namespace=$namespace  -o wide | grep mysqlclient | awk '{print $1}')
expected_profile="docker-default (enforce)"
profile=`kubectl -n $namespace exec $mysql_pod -- cat /proc/1/attr/current`
echo "Profile running: $profile"
  if test "$profile" != "$expected_profile"
  then
    if test "$proc_name" == "pause"
    then
      echo "Root process (pause) can run docker-default, it's ok."
    else
      echo "$profile is the WRONG PROFILE!!"
      return 1
    fi
  fi