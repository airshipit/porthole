# Calicoctl-utility Container

This container shall allow access to the Calico pod running on every node.
Operations personnel should be able to get the appropriate data from this
utility container by specifying the node and respective service command
within the local cluster.

## Generic Docker Makefile

This is a generic make and dockerfile for the calicoctl utility container,
which can be used to create docker images using different calico releases.

### Make Syntax

```bash
   make IMAGE_TAG=<calicoctl_version>
```

Example:

Create a docker image for calicoctl release v3.4.0.

```bash
   make IMAGE_TAG=v3.4.0
```

## Using the Utility Container

The utility container for calicoctl shall enable Operations to access the
command set for network APIs together from within a single shell with a
uniform command structure. The access to network-Calico shall be controlled
through an RBAC role assigned to the user.

### Usage

Get into the utility pod using `kubectl exec`.
Execute an operation as in the following example.

```
   kubectl exec -it <POD_NAME> -n utility /bin/bash
```

Example:

```bash
   utilscli calicoctl get nodes
   NAME
   bionic

   utilscli calicoctl version
   Client Version:    v3.4.4
   Git commit:        e3ecd927
```
