# PostgreSQL Utility Container

Since this needs postgresql Pods, Deploy postgres pods with Ceph (For Secrets) in osh-infra namespace

## Installation

Install Postgresql Pods in OSH with below steps:

Run this below command from porthole

```
set -xe
: "${OSH_INFRA_PATH:="../openstack-helm-infra"}"

cd "${OSH_INFRA_PATH}"
bash -c "./tools/deployment/osh-infra-logging/020-ceph.sh"
bash -c "./tools/deployment/osh-infra-logging/025-ceph-ns-activate.sh"
bash -c "./tools/deployment/osh-infra-monitoring/130-postgresql.sh"

```

## Testing

Get Hostname/Service for postgresql pods

```
kubectl get services -n osh-infra | grep postgresql

```

Get in to the utility pod using `kubectl exec`.
To perform any operation on the ucp PostgreSQL cluster, use the below example.

Example:

```
utilscli psql -h hostname -U username -d database
psql -h hostaddress -U username -p port --password password

root@ubuntu:~# kubectl exec -it postgresql-655989696f-79246 -n utility /bin/bash
nobody@postgresql-utility-7bc947c85d-gvwpz:/$ utilscli psql -h 10.106.253.127 -p 5432 -U postgres
Password for user postgres:
psql (10.12 (Ubuntu 10.12-0ubuntu0.18.04.1), server 9.5.19)
SSL connection (protocol: TLSv1.2, cipher: ECDHE-RSA-AES256-GCM-SHA384, bits: 256, compression: off)
Type "help" for help.


postgres=# \l
 maasdb    | postgres | UTF8     | en_US.UTF-8 | en_US.UTF-8 | =Tc/postgres         +
           |          |          |             |             | postgres=CTc/postgres+
           |          |          |             |             | maas=CTc/postgres
 postgres  | postgres | UTF8     | en_US.UTF-8 | en_US.UTF-8 |
 template0 | postgres | UTF8     | en_US.UTF-8 | en_US.UTF-8 | =c/postgres          +
           |          |          |             |             | postgres=CTc/postgres
 template1 | postgres | UTF8     | en_US.UTF-8 | en_US.UTF-8 | =c/postgres          +
           |          |          |             |             | postgres=CTc/postgres


postgresdb=#
```
