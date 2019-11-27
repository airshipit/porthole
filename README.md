# Utility Containers

Utility containers give Operations staff an interface to an Airship
environment that enables them to perform routine operations and
troubleshooting activities. Utility containers support Airship
environments without exposing secrets and credentials while at
the same time restricting access to the actual containers.

## Prerequisites

Deploy OSH-AIO.

## System Requirements

The recommended minimum system requirements for a full deployment are:

* 16 GB RAM
* 8 Cores
* 48 GB HDD

## Installation

1. Add the below to `/etc/sudoers`.

        root    ALL=(ALL) NOPASSWD: ALL
        ubuntu  ALL=(ALL) NOPASSWD: ALL

2. Install the latest versions of Git, CA Certs, and Make if necessary.

        sudo apt-get update
        sudo apt-get dist-upgrade -y
        sudo apt-get install --no-install-recommends -y \
            ca-certificates \
            git \
            make \
            jq \
            nmap \
            curl \
            uuid-runtime \
            bc

3. Clone the OpenStack-Helm repositories.

       git clone https://git.openstack.org/openstack/openstack-helm-infra.git
       git clone https://git.openstack.org/openstack/openstack-helm.git

4. Configure proxies.

   In order to deploy OpenStack-Helm behind corporate proxy servers,
   add the following entries to `openstack-helm-infra/tools/gate/devel/local-vars.yaml`.

        proxy:
            http: http://username:password@host:port
            https: https://username:password@host:port
            noproxy: 127.0.0.1,localhost,172.17.0.1,.svc.cluster.local

   Add the address of the Kubernetes API, `172.17.0.1`, and `.svc.cluster.local` to
   your `no_proxy` and `NO_PROXY` environment variables.

        export no_proxy=${no_proxy},172.17.0.1,.svc.cluster.local
        export NO_PROXY=${NO_PROXY},172.17.0.1,.svc.cluster.local

5. Deploy Kubernetes and Helm.

        cd openstack-helm
        ./tools/deployment/developer/common/010-deploy-k8s.sh

   Edit `/etc/resolv.conf` and remove the DNS nameserver entry (`nameserver 10.96.0.10`).
   The Python setup client fails if this nameserver entry is present.

6. Setup clients on the host, and assemble the charts.

        ./tools/deployment/developer/common/020-setup-client.sh

   Re-add DNS nameservers back to `/etc/resolv.conf` so that the Keystone URLs DNS will resolve.

7. Deploy the ingress controller.

        ./tools/deployment/developer/common/030-ingress.sh

8. Deploy Ceph.

        ./tools/deployment/developer/ceph/040-ceph.sh

9. Activate the namespace to be able to use Ceph.

        ./tools/deployment/developer/ceph/045-ceph-ns-activate.sh

10. Deploy Keystone.

        ./tools/deployment/developer/ceph/080-keystone.sh

11. Deploy Heat.

        ./tools/deployment/developer/ceph/090-heat.sh

12. Deploy Horizon.

        ./tools/deployment/developer/ceph/100-horizon.sh

13. Deploy Glance.

        ./tools/deployment/developer/ceph/120-glance.sh

14. Deploy Cinder.

        ./tools/deployment/developer/ceph/130-cinder.sh

15. Deploy LibVirt.

        ./tools/deployment/developer/ceph/150-libvirt.sh

16. Deploy the compute kit (Nova and Neutron).

        ./tools/deployment/developer/ceph/160-compute-kit.sh

17. To run further commands from the CLI manually, execute the following
    to set up authentication credentials.

        export OS_CLOUD=openstack_helm

18. Clone the Porthole repository to the openstack-helm project.

        git clone https://opendev.org/airship/porthole.git

## To deploy utility pods

1. Add and make the chart:

        cd porthole
        helm repo add <chartname> http://localhost:8879/charts
        make all

2. Deploy `Ceph-utility`.

        ./tools/deployment/utilities/010-ceph-utility.sh

3. Deploy `Compute-utility`.

        ./tools/deployment/utilities/020-compute-utility.sh

4. Deploy `Etcdctl-utility`.

        ./tools/deployment/utilities/030-etcdctl-utility.sh

5. Deploy `Mysqlclient-utility`.

        ./tools/deployment/utilities/040-Mysqlclient-utility.sh

6. Deploy `Openstack-utility`.

        ./tools/deployment/utilities/050-openstack-utility.sh

## NOTE

The PostgreSQL utility container is deployed as a part of Airship-in-a-Bottle (AIAB).
To deploy and test `postgresql-utility`, see the
[PostgreSQL README](https://opendev.org/airship/porthole/src/branch/master/images/postgresql-utility/README.md).
