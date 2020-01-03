# OpenStack-utility Container

The utility container for OpenStack shall enable Operations to access the
command set for Compute, Network, Identity, Image, Block Storage, and
Queueing service APIs together from within a single shell with a uniform
command structure. The access to OpenStack shall be controlled through an
OpenStack RBAC role assigned to the user. The user will have to set
the OpenStack environment (openrc) in the utility container to access the
OpenStack CLIs. The generic environment file will be placed in the utility
container with common settings except username, password, and project_ID.
The user needs to specify these parameters using command options.

## Usage

Get into the utility pod using `kubectl exec`.
Perform an operation as in the following example.
Please be ready with your password for accessing the CLI commands.

```
   kubectl exec -it <POD_NAME> -n utility /bin/bash
```

Example:

```bash
   utilscli openstack server list --os-username <USER_NAME> --os-domain-name <DOMAIN_NAME> \
            --os-project-name <PROJECT_NAME
   utilscli openstack user list --os-username <USER_NAME> --os-domain-name <DOMAIN_NAME> \
            --os-project-name <PROJECT_NAME
```
