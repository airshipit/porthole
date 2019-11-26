#!/bin/bash

# Copyright 2017 The Openstack-Helm Authors.
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
kubectl label nodes --all openstack-helm-node-class=primary --overwrite
namespace="utility"

cd /tmp
git clone https://git.openstack.org/openstack/openstack-helm-infra.git || true
cd openstack-helm-infra
git reset --hard 200b5e902b3a176fbfbe669b6a10a254c9b50f5d
make helm-toolkit

cd /home/zuul/src/opendev.org/airship/porthole/charts/openstack-utility/
mkdir charts
cp -r /tmp/openstack-helm-infra/helm-toolkit-0.1.0.tgz /home/zuul/src/opendev.org/airship/porthole/charts/openstack-utility/charts
cd /home/zuul/src/opendev.org/airship/porthole/charts

kubectl get pods --all-namespaces
sleep 120

helm upgrade --install openstack-utility ./openstack-utility --namespace=$namespace \
# NOTE: Validate Deployment and User.

sleep 180
kubectl get pods --namespace=$namespace | grep openstack-utility
ouc_pod=$(kubectl get pods --namespace=$namespace --selector="application=openstack" --no-headers | awk '{ print $1; exit }')
unsorted_process_file="/tmp/unsorted_proc_list"
sorted_process_file="/tmp/proc_list"
expected_profile="docker-default (enforce)"
kubectl describe pod $ouc_pod -n utility

#Below can be used for multiple Processes.Grab the processes (numbered directories) from the /proc directory,
# and then sort them. Highest proc number indicates most recent process.
#kubectl -n $namespace exec $ouc_pod -- ls -1 /proc | grep -e "^[0-9]*$" > $unsorted_process_file
#sort --numeric-sort $unsorted_process_file > $sorted_process_file

# The last/latest process in the list will actually be the "ls" command above,
# which isn't running any more, so remove it.
#sed -i '$ d' $sorted_process_file

#while IFS='' read -r process || [[ -n "$process" ]]; do
  #echo "Process ID: $process"
  #proc_name=`kubectl -n $namespace exec $ouc_pod -- cat /proc/$process/status | grep "Name:" | awk -F' ' '{print $2}'`
  #echo "Process Name: $proc_name"
#  profile=`kubectl -n $namespace exec $ouc_pod -- cat /proc/1/attr/current`
#  echo "Profile running: $profile"
#  if test "$profile" != "$expected_profile"
#  then
#    if test "$proc_name" == "pause"
#    then
#      echo "Root process (pause) can run docker-default, it's ok."
#    else
#      echo "$profile is the WRONG PROFILE!!"
#      return 1
#    fi
#  fi
#done < $sorted_process_file

profile=`kubectl -n $namespace exec $ouc_pod -- cat /proc/1/attr/current`
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
