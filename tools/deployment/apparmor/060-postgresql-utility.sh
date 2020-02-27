#!/bin/bash

# Copyright 2019 The Openstack-Helm Authors.
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
kubectl label nodes --all openstack-helm-node-class=primary --overwrite

helm dependency update charts/postgresql-utility
cd charts
helm upgrade --install postgresql-utility ./postgresql-utility --namespace=$namespace
sleep 180
kubectl get pods --namespace=$namespace

pos_pod=$(kubectl get pods --namespace=$namespace  -o wide | grep postgresql | awk '{print $1}')
expected_profile="docker-default (enforce)"
profile=`kubectl -n $namespace exec $pos_pod -- cat /proc/1/attr/current`
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
