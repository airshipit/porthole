#!/bin/bash

{{/*
Copyright 2019 The Openstack-Helm Authors.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

   http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/}}

usage() {
   echo "Usage: utilscli <component> <hostname> <cli options>"
   exit 1
}

COMPONENT=$0;
HOSTNAME=$1; shift
COMMAND=$1; shift
OPTIONS="$@"

if [[ -z "${COMPONENT}" || -z "${HOSTNAME}" || -z "$COMMAND" ]]; then
    echo "ERROR: Missing command line argument(s)!"
    usage
    exit 1
fi

# remove the /tmp, then only search on the first half of the component (second half should be -client)
prefix="/tmp/"
suffix="-client"
COMP1=${COMPONENT#"$prefix"}
COMP=${COMP1%"$suffix"}

# find the pod for the component and hostname
POD=$(kubectl get pod -n openstack -o wide | grep -i $COMP | grep $HOSTNAME | awk '{print $1}')
if [[ -z "${POD}" ]]; then
   echo "ERROR: Could not find matching pod for host $HOSTNAME and component $COMP1"
   usage
   exit 1
fi
# run the command
result=$(kubectl exec -it $POD -n openstack  -- $COMMAND $OPTIONS)

echo "$result"

exit 0
