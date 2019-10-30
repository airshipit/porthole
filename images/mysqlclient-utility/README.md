# Mysqlclient-utility Container

This container allows users access to MariaDB pods remotely to perform db
functions.  Authorized users in UCP keystone RBAC will able to run queries
through 'utilscli' helper.

## Usage & Test

Get in to the utility pod using kubectl exec. Then perform the followings:

## Case 1 - Execute into the pod

   - $kubectl exec -it <POD_NAME> -n utility /bin/bash

## Case 2 - Test connectivity to Mariadb (optional)

1. Find mariadb pod and its corresponding IP
---
   - $kubectl get pods --all-namespaces | grep -i mariadb-server | awk '{print $1,$2}' \
     | while read a b ; do kubectl get pod $b -n $a -o wide
done
---

2. Now connect to the pod as described in Case 1 by providing the arguments
   as indicated for the CLI, as shown below

   - $kubectl exec <POD_NAME> -it -n utility -- mysql -h <IP> -u root -p<PASSWORD> \
              -e 'show databases;'

 It's expected to see an output looks similar to below.

>--------------------+\
| Database           |\
|--------------------|\
| cinder             |\
| glance             |\
| heat               |\
| horizon            |\
| information_schema |\
| keystone           |\
| mysql              |\
| neutron            |\
| nova               |\
| nova_api           |\
| nova_cell0         |\
| performance_schema |\
+--------------------+\
