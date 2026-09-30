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

The utility charts, together with the Ceph, MariaDB and PostgreSQL services
they operate on, are deployed by the
`tools/gate/playbooks/deploy-utilities.yaml` playbook. It uses the
`deploy-ceph` and `deploy-charts` roles from
[openstack-helm](https://opendev.org/openstack/openstack-helm) and deploys:

1. `calicoctl-utility`
2. `ceph-utility`
3. `compute-utility`
4. `etcdctl-utility`
5. `mysqlclient-utility`
6. `openstack-utility`
7. `postgresql-utility`

See the `porthole-infra-deploy` job in `zuul.d/base.yaml` for the variables
it expects.

## NOTE

The PostgreSQL utility container needed Postgresql DB  Pods for Testing. Please follow below Link.
`[PostgreSQL README](https://opendev.org/airship/porthole/src/branch/master/images/postgresql-utility/README.md).`

