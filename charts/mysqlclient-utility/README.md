# MySqlClient Utility Container

This container allows users access to MariaDB pods remotely to perform db
functions.  Authorized users in UCP keystone RBAC will able to run queries
through 'utilscli' helper.

## Prerequisites

1. Internet access
2. Successfully deploy [Openstack Helm Chart](https://docs.openstack.org/openstack-helm/latest/install/index.html) sandbox
3. Have access to Jump Host where the user k8s profile has already been setup

## Installation

1. Clone the OpenStack-Helm and Porthole repos

       $git clone https://git.openstack.org/openstack/openstack-helm-infra.git
       $git clone https://git.openstack.org/openstack/openstack-helm.git
       $git clone https://review.opendev.org/airship/porthole


2. Pull PatchSet (optional)

       $cd porthole
       $git pull https://review.opendev.org/airship/porthole refs/changes/[patchset number]/[latest change set]

## Validation

Execute into the pod by using **kubectl** command line:

### Case 1 - Execute into the pod

    $kubectl exec -it <POD_NAME> -n utility /bin/bash

It's expected to provide a shell prompt

### Case 2 - Test connectiviy to Mariadb (optional)

Find mariadb pod and its corresponding IP

    kubectl get pods --all-namespaces -o wide |grep -i mariadb-server|awk '{print $1,$2,$7}'

An Output should look similar to below

    openstack mariadb-server-0 192.168.207.19

Now connect to the pod as illustrated in Case 1 by providing CLI arguements accordingly

CLI Syntax

    $kubectl exec <POD_NAME> -it -n utility -- mysql -h <IP> -u root -p<PASSWORD> -e 'show databases;'

It's expected to see an output looks similar to below.

    |--------------------|
    | Database           |
    |--------------------|
    | cinder             |
    | glance             |
    | heat               |
    | horizon            |
    | information_schema |
    | keystone           |
    | mysql              |
    | neutron            |
    | nova               |
    | nova_api           |
    | nova_cell0         |
    | performance_schema |
    +--------------------+