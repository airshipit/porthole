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

set -x


: "${DISTRO:="ubuntu_focal"}"

env
make images

docker rm registry --force || true
docker run -d -p 5000:5000 --restart=always --name registry registry:2

docker tag quay.io/airshipit/porthole-calicoctl-utility:latest-${DISTRO} localhost:5000/porthole-calicoctl-utility:latest-${DISTRO}
docker tag quay.io/airshipit/porthole-ceph-utility:latest-${DISTRO} localhost:5000/porthole-ceph-utility:latest-${DISTRO}
docker tag quay.io/airshipit/porthole-compute-utility:latest-${DISTRO} localhost:5000/porthole-compute-utility:latest-${DISTRO}
docker tag quay.io/airshipit/porthole-etcdctl-utility:latest-${DISTRO} localhost:5000/porthole-etcdctl-utility:latest-${DISTRO}
docker tag quay.io/airshipit/porthole-mysqlclient-utility:latest-${DISTRO} localhost:5000/porthole-mysqlclient-utility:latest-${DISTRO}
docker tag quay.io/airshipit/porthole-openstack-utility:latest-${DISTRO} localhost:5000/porthole-openstack-utility:latest-${DISTRO}
docker tag quay.io/airshipit/porthole-postgresql-utility:latest-${DISTRO} localhost:5000/porthole-postgresql-utility:latest-${DISTRO}



docker push localhost:5000/porthole-calicoctl-utility:latest-${DISTRO}
docker push localhost:5000/porthole-ceph-utility:latest-${DISTRO}
docker push localhost:5000/porthole-compute-utility:latest-${DISTRO}
docker push localhost:5000/porthole-etcdctl-utility:latest-${DISTRO}
docker push localhost:5000/porthole-mysqlclient-utility:latest-${DISTRO}
docker push localhost:5000/porthole-openstack-utility:latest-${DISTRO}
docker push localhost:5000/porthole-postgresql-utility:latest-${DISTRO}
