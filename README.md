# Utility Containers

Utility containers provide a component level, consolidated view of
running containers within Network Cloud infrastructure to members
of the Operation team. This allows Operation team members access to
check the state of various services running within the component
pods of Network Cloud.

## Prerequisites

Deploy OSH-AIO

## System Requirements

The recommended minimum system requirements for a full deployment are:

   * 16GB of RAM

   * 8 Cores

   * 48GB HDD

## Installation

1. Add the below to /etc/sudoers

   root    ALL=(ALL) NOPASSWD: ALL
   ubuntu  ALL=(ALL) NOPASSWD: ALL

2. Install the latest versions of Git, CA Certs & Make if necessary

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

3. Clone the OpenStack-Helm Repos

   git clone https://git.openstack.org/openstack/openstack-helm-infra.git
   git clone https://git.openstack.org/openstack/openstack-helm.git


4. Proxy Configuration

   In order to deploy OpenStack-Helm behind corporate proxy servers,
   add the following entries to openstack-helm-infra/tools/gate/devel/local-vars.yaml.

   proxy:
     http: http://username:password@host:port
     https: https://username:password@host:port
     noproxy: 127.0.0.1,localhost,172.17.0.1,.svc.cluster.local

   Add the address of the Kubernetes API, 172.17.0.1, and .svc.cluster.local to
   your no_proxy and NO_PROXY environment variables.

   export no_proxy=${no_proxy},172.17.0.1,.svc.cluster.local
   export NO_PROXY=${NO_PROXY},172.17.0.1,.svc.cluster.local

5. Deploy Kubernetes & Helm

   cd openstack-helm
     ./tools/deployment/developer/common/010-deploy-k8s.sh

   Please remove DNS nameserver (nameserver 10.96.0.10) from /etc/resolv.conf,
   Since python set-up client would fail without it.

6. Setup Clients on the host and assemble the charts
     ./tools/deployment/developer/common/020-setup-client.sh

   Re-add DNS nameservers back in /etc/resolv.conf so that keystone URL's DNS would resolve.

7. Deploy the ingress controller
     ./tools/deployment/developer/common/030-ingress.sh

8. Deploy Ceph
     ./tools/deployment/developer/ceph/040-ceph.sh

9. Activate the namespace to be able to use Ceph
     ./tools/deployment/developer/ceph/045-ceph-ns-activate.sh

10. Deploy Keystone
      ./tools/deployment/developer/ceph/080-keystone.sh

11. Deploy Heat
      ./tools/deployment/developer/ceph/090-heat.sh

12. Deploy Horizon
      ./tools/deployment/developer/ceph/100-horizon.sh

13. Deploy Glance
      ./tools/deployment/developer/ceph/120-glance.sh

14. Deploy Cinder
      ./tools/deployment/developer/ceph/130-cinder.sh

15. Deploy LibVirt
      ./tools/deployment/developer/ceph/150-libvirt.sh

16. Deploy Compute Kit (Nova and Neutron)
      ./tools/deployment/developer/ceph/160-compute-kit.sh

17. To run further commands from the CLI manually, execute the following
    to set up authentication credentials
      export OS_CLOUD=openstack_helm

18. Clone the Porthole repo to openstack-helm project

      git clone https://opendev.org/airship/porthole.git

## To deploy utility pods

1. cd porthole

2. helm repo add <chartname> http://localhost:8879/charts

3. make all

4. Deploy Ceph-utility
     ./tools/deployment/utilities/010-ceph-utility.sh

5. Deploy Compute-utility
     ./tools/deployment/utilities/020-compute-utility.sh

6. Deploy Etcdctl-utility
     ./tools/deployment/utilities/030-etcdctl-utility.sh

7. Deploy Mysqlclient-utility.sh
     ./tools/deployment/utilities/040-Mysqlclient-utility.sh

8. Deploy Openstack-utility.sh
     ./tools/deployment/utilities/050-openstack-utility.sh

## NOTE

For postgresql-utility please refer to below URL as per validation
postgresql-utility is deployed in AIAB

  https://opendev.org/airship/porthole/src/branch/master/images/postgresql-utility/README.md
