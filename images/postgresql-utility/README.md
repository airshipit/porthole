# PostgreSQL Utility Container

## Prerequisites: Deploy Airship in a Bottle(AIAB)

## Installation

1. Add the below to /etc/sudoers

```
root    ALL=(ALL) NOPASSWD: ALL
ubuntu  ALL=(ALL) NOPASSWD: ALL
```

2. Install the latest versions of Git, CA Certs & bundle & Make if necessary

```
set -xe

sudo apt-get update
sudo apt-get install --no-install-recommends -y \
ca-certificates \
git \
make \
jq \
nmap \
curl \
uuid-runtime
```

3. Deploy Porthole

```
git clone https://opendev.org/airship/porthole
```

4. Modify the test case test-postgresqlutility-running.yaml

## Testing

Get in to the utility pod using kubectl exec.
To perform any operation on the ucp PostgreSQL cluster use the below example.

example:

```
utilscli psql -h hostname -U username -d database
psql -h hostaddress -U username -p port --password password

root@ubuntu:~# kubectl exec -it postgresql-655989696f-79246 -n utility /bin/bash
nobody@postgresql-655989696f-79246:/$ utilscli psql -h <hostaddress> -U postgresadmin -p <portnumber> --password <password>
Password for user postgresadmin:
WARNING: psql major version 9.5, server major version 10.
        Some psql features might not work.
Type "help" for help.

postgresdb=# \d
                 List of relations
Schema |       Name       |   Type   |     Owner
--------+------------------+----------+---------------
public | company          | table    | postgresadmin
public | role             | table    | postgresadmin
public | role_role_id_seq | sequence | postgresadmin
public | test             | table    | postgresadmin
(4 rows)

postgresdb=#
```
