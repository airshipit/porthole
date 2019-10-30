# Openstack-utility Container

Utility container for Openstack shall enable Operations to trigger the command set for
Compute, Network, Identity, Image, Block Storage, Queueing service APIs together from
within a single shell with a uniform command structure. The access to Openstack shall
be controlled through Openstack RBAC role assigned to the user. User will have to set
the Openstack environment (openrc) in utility container to access the Openstack CLIs.
The generic environment file will be placed in Utility container with common setting except
username, password and project_ID. User needs to pass such parameters through command options.

## Usage

1. Get in to the utility pod using kubectl exec.
   To perform any operation use the below example.
   Please be ready with password for accessing below cli commands.

   - kubectl exec -it <POD_NAME> -n utility /bin/bash

example:

   utilscli openstack server list --os-username <USER_NAME> --os-domain-name <DOMAIN_NAME> \
            --os-project-name <PROJECT_NAME
   utilscli openstack user list --os-username <USER_NAME> --os-domain-name <DOMAIN_NAME> \
            --os-project-name <PROJECT_NAME
