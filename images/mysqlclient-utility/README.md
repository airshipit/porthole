# Mysqlclient-utility Container

This utility container allows Operations personnel to access MariaDB pods
remotely to perform database functions. Authorized users in UCP Keystone
RBAC will able to run queries through the `utilscli` helper.

## Usage

Get into the utility pod using `kubectl exec`.

```
        kubectl exec -it <POD_NAME> -n utility /bin/bash
```

## Testing Connectivity to Mariadb (Optional)

1. Find the mariadb pod and its corresponding IP.

```
       kubectl get pods --all-namespaces | grep -i mariadb-server | awk '{print $1,$2}' \
       | while read a b ; do kubectl get pod $b -n $a -o wide
       done
```

2. Connect to the indicated pod by providing the arguments
   specified for the CLI as shown below.

```
       kubectl exec <POD_NAME> -it -n utility -- mysql -h <IP> -u root -p<PASSWORD> \
              -e 'show databases;'
```

The output should resemble the following.

```
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
```
