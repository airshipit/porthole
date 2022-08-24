#!/bin/bash

set -ex

./tools/deployment/000-install-packages.sh
./tools/deployment/002-build-helm-toolkit.sh
./tools/deployment/003-deploy-k8s.sh
./tools/deployment/005-calicoctl-utility.sh
./tools/deployment/010-ceph-utility.sh
./tools/deployment/020-compute-utility.sh
./tools/deployment/030-etcdctl-utility.sh
./tools/deployment/040-mysqlclient-utility.sh
./tools/deployment/050-openstack-utility.sh
./tools/deployment/060-postgresql-utility.sh
sleep 30
