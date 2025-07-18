# Utility Containers

Utility containers give Operations staff an interface to an Airship
environment that enables them to perform routine operations and
troubleshooting activities. Utility containers support Airship
environments without exposing secrets and credentials while at
the same time restricting access to the actual containers.

## Prerequisites

=======

Deploy OSH-AIO.
=======
Deploy the Openstack-Helm All-in-One environment starting from
[here](https://docs.openstack.org/openstack-helm/latest/install/common-requirements.html)
up through the section `Deploy Compute Kit`

The recommended minimum system requirements for a full deployment are:
* 16 GB RAM
* 8 Cores
* 48 GB HDD

=======
1. To run further commands from the CLI manually, execute the following
    to set up authentication credentials

        export OS_CLOUD=openstack_helm

2. Clone the Porthole repo to openstack-helm project

        git clone https://opendev.org/airship/porthole.git

## To deploy utility pods

1. To Deploy Utility containers, Please run required scripts

        cd porthole
2. Deploy `Calico-utility`.
         ./tools/deployment/utilities/005-calicoctl-utility.sh

3. Deploy `Ceph-utility`.

        ./tools/deployment/utilities/010-ceph-utility.sh

4. Deploy `Compute-utility`.

        ./tools/deployment/utilities/020-compute-utility.sh

5. Deploy `Etcdctl-utility`.

        ./tools/deployment/utilities/030-etcdctl-utility.sh

6. Deploy `Mysqlclient-utility`.

        ./tools/deployment/utilities/040-Mysqlclient-utility.sh

7. Deploy `Openstack-utility`.

        ./tools/deployment/utilities/050-openstack-utility.sh

8. Deploy `Postgresql-utility'.
        ./tools/deployment/utilities/060-postgresql-utility.sh

## NOTE

The PostgreSQL utility container needed Postgresql DB  Pods for Testing. Please follow below Link.
`[PostgreSQL README](https://opendev.org/airship/porthole/src/branch/master/images/postgresql-utility/README.md).`

