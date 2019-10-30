# Calicoctl-utility Container

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
