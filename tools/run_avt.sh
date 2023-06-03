#!/bin/bash
# Copyright 2020 AT&T Intellectual Property.  All other rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -x
TYPE=$1
VENV=$(mktemp -d)
PLUGINS=kube_utility_container
export KUBECONFIG=${KUBECONFIG:-~/.kube/config}

function setup_venv() {
    sudo  apt-get install libffi-dev libssl-dev python3-dev python3-setuptools python3-venv gcc make build-essential automake autoconf -y
    python3 -m venv ${VENV}
    if [[ -f ${VENV}/bin/activate ]] ;then
      source $VENV/bin/activate
      ${VENV}/bin/pip3 install -r requirements-frozen.txt
      ${VENV}/bin/python3 -m pip list --format=columns
      kubectl get deployment -n utility
      kubectl get nodes -o wide
      kubectl get po --all-namespaces -o wide
      stestr init
    fi
}

function run_avt() {
    setup_venv
    if [[ ${TYPE} == 'unit_tests' ]] ; then
	run_unit_tests
    elif [[ ${TYPE} == 'feature_tests' ]] ; then
	run_feature_tests
    else
	echo "No validating tests performed..skip"
    fi
}

function run_feature_tests() {
      python3 -m unittest discover -s ${PLUGINS}/tests/utility/compute -vv
      python3 -m unittest discover -s ${PLUGINS}/tests/utility/etcd -vv
      python3 -m unittest discover -s ${PLUGINS}/tests/utility/calico -vv
      python3 -m unittest discover -s ${PLUGINS}/tests/utility/ceph -vv
      python3 -m unittest discover -s ${PLUGINS}/tests/utility/openstack -vv
      python3 -m unittest discover -s ${PLUGINS}/tests/utility/postgresql -vv
      python3 -m unittest discover -s ${PLUGINS}/tests/utility/mysqlclient -vv
}

function run_unit_tests() {
      python3 -m unittest discover -s ${PLUGINS}/tests/unit/services -vv
}

run_avt
