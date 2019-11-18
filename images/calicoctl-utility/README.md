# Calicoctl-utility Container

<<<<<<< HEAD
This container shall allow access to calico pod running on every node.
Support personnel should be able to get the appropriate data from this utility container
by specifying the node and respective service command within the local cluster.

## Generic Docker Makefile

This is a generic make and dockerfile for calicoctl utility container, which
can be used to create docker images using different calico releases.

## Usage

make IMAGE_TAG=<calicoctl_version>

Example:

1. Create docker image for calicoctl release v3.4.0

   make IMAGE_TAG=v3.4.0
=======
Utility container for Calicoctl shall enable Operations to trigger the command set for
Network APIs together from within a single shell with a uniform command structure. The
access to network-Calico shall be controlled through RBAC role assigned to the user.

## Usage

 Get in to the utility pod using kubectl exec.
 To perform any operation use the below example.

  - kubectl exec -it <POD_NAME> -n utility /bin/bash

Example:

1. utilscli calicoctl get nodes
   NAME
   bionic

2. utilscli calicoctl version
   Client Version:    v3.4.4
   Git commit:        e3ecd927
