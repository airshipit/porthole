# Compute-utility Container

This container shall allow access to services running on the each compute node.
Support personnel should be able to get the appropriate data from this utility container
by specifying the node and respective service command within the local cluster.

## Usage

1. Get in to the utility pod using kubectl exec. To perform any operation use the below example.

   - kubectl exec -it <POD_NAME> -n utility /bin/bash

2. Run the utilscli with commands formatted:

   - utilscli <client-name> <server-hostname> <command> <options>

example:

   - utilscli libvirt-client mtn16r001c002 virsh list


Accepted client-names are:
 libvirt-client
 ovs-client
 ipmi-client
 perccli-client
 numa-client
 sos-client

Commands for each client vary with the client.
