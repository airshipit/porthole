#!/bin/bash
{{/*
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

set -ex

usage() {

set +ex

echo "General Instruction:"
echo "===================="
echo "Commands must be executed in same format and with same arguments as shown below"
echo "Replace .* with value for the preceding key (i.e. rados --pool  .* ls. Here .* represent poolname)"
echo "For more information, run help on command. (utilscli rados --help or utilscli rbd help)"
echo $'\n'
echo "General Usage:"
echo "=============="
echo "  utilscli <command with argument>"
echo $'\n'

FILTERFILE='/etc/ceph/rootwrap.d/ceph-rootwrap-filter'

awk -F "CommandFilter, " 'NF>1{print $2}' ${FILTERFILE} | awk -F',' '{print $1}' | awk '$0="  utilscli "$0'

COMMANDS=$(awk -F "RegExpFilter" '{print $2}' ${FILTERFILE} |  awk -F ", " '{print $2}' | sort | uniq )

for j in $COMMANDS
do
  awk -F "RegExpFilter, $j, root, " 'NF>1{print $2}' ${FILTERFILE} | sed -e 's/,//g' | awk '$0="  utilscli "$0'
done

  exit 1
}

usage


