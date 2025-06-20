# Compute-utility Container

This container enables Operations personnel to access services running on
the compute nodes. Operations personnel can get the appropriate data from this
utility container by specifying the node and respective service command within
the local cluster.

## Usage

1. Get into the utility pod using `kubectl exec`. Perform an operation as in
the following example.

```
      kubectl exec -it <POD_NAME> -n utility /bin/bash
```

2. Use the following syntax to run commands.

```
      utilscli <client-name> <server-hostname> <command> <options>
```

Example:

```
      utilscli libvirt-client node42 virsh list
```

Accepted client names are:

* libvirt-client
* ovs-client
* ipmi-client
* perccli-client
* numa-client
* sos-client

Commands for each client vary with the client.
