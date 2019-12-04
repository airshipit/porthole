# Jump Host Installation

This procedure installs the Kubernetes client and corresponding dependencies,
enabling remote access to the Kubernetes cluster. The procedure also creates
a generic `kubectl` configuration file having the appropriate attributes.

This revision covers the implementation as described. [k8s-keystone-auth](
https://github.com/kubernetes/cloud-provider-openstack/blob/master/docs/using-keystone-webhook-authenticator-and-authorizer.md#new-kubectl-clients-from-v1110-and-later)

## 1. Prerequisites

* Ubuntu OS version 14.x or higher
* Connectivity to the Internet
* The installer has sudo ability without prompting for password
* Installer's Git profile setup accordingly

## 2. Installation

### 2.1 Clone Porthole Main Project

    $git clone https://review.opendev.org/airship/porthole

### 2.2 Run Setup

    $cd $porthole
    $sudo -s
    $cd jmphost
    $./setup-access.sh "site" "userid" "namespace"

    [Kubectl binary] is not found on this system..
    Checking user[johnSmith] sudo ability
    Looking good. You [johnSmith] are root now
    deb https://apt.kubernetes.io/ kubernetes-xenial main
    OK
    ........................
    ........................
    ........................
    ........................
    Installing [kubectl] dependency required...
    Reading package lists... Done
    Building dependency tree
    Reading state information... Done
    The following package was automatically installed and is no longer required:
    libclamav6
    Use 'apt-get autoremove' to remove it.
    The following NEW packages will be installed:
    kubectl
    0 upgraded, 1 newly installed, 0 to remove and 104 not upgraded.
    Need to get 9,231 kB of archives.
    After this operation, 46.7 MB of additional disk space will be used.
    Fetched 9,231 kB in 12s (732 kB/s)
    Selecting previously unselected package kubectl.
    (Reading database ... 114982 files and directories currently installed.)
    Preparing to unpack .../kubectl_1.16.0-00_amd64.deb ...
    Unpacking kubectl (1.16.0-00) ...
    Setting up kubectl (1.16.0-00) ...
    ........................
    ........................
    W: Duplicate sources.list entry https://apt.kubernetes.io/ kubernetes-xenial/main amd64 Packages (/var/lib/apt/lists/apt.kubernetes.io_dists_kubernetes-xenial_main_binary-amd64_Packages)
    W: Duplicate sources.list entry https://apt.kubernetes.io/ kubernetes-xenial/main i386 Packages (/var/lib/apt/lists/apt.kubernetes.io_dists_kubernetes-xenial_main_binary-i386_Packages)
    ........................
    W: You may want to run apt-get update to correct these problems

    ---
    apiVersion: v1
    namespace: utility
    Authentication via API WebHook Ingress service endpoint
    clusters:
      - cluster:
       server: https://<FQDN-WEBHOOK-APISERVER>
      name: <CLUSTER_NAME>
    contexts:
    - context:
       cluster: <CLUSTER_NAME>
       user: <USERID>
      name: <USERID>@<CLUSTER_NAME>
    current-context: <USERID>@<CLUSTER_NAME>
    kind: Config
    preferences: {}
    users:
    - name: <USERID>
      user:
        exec:
          command: "/usr/local/uc/bin/client-keystone-auth"
          apiVersion: "client.authentication.k8s.io/v1beta1"
       env:
       - name: "OS_DOMAIN_NAME"
         value: default
       - name: "OS_INTERFACE"
         value: public
       - name: "OS_USERNAME"
         value: <USER_ID>
       - name: "OS_PASSWORD"
         value: "<USER-PASSWORD>"
       - name: "OS_PROJECT_NAME"
         value: <admin-project>
       - name: "OS_REGION_NAME"
         value: <SITE>
       - name: "OS_IDENTITY_API_VERSION"
         value: "3"
       args:
       - "--keystone-url=https://<FQDN TO UCP KEYSTONE>/v3"

## 3. Validation

To test, perform these steps.

1. Log out and log back in as the user.

2. Update the configuration file with the user's credentials.

    * Replace *"OS_USERNAME"* and *"OS_PASSWORD"* with UCP Keystone
credentials.

    * Set the *"OS_PROJECT_NAME"* value accordingly.

### 3.1 List Pods

    $kubectl get pods -n utility

    NAME                                                          READY   STATUS      RESTARTS   AGE
    clcp-calicoctl-utility-6457864fc8-zpfxk                       1/1     Running     0          4h27m
    clcp-tenant-ceph-utility-7b8f6d45f8-5q4ts                     1/1     Running     0          99m
    clcp-tenant-ceph-utility-config-ceph-ns-key-generator-hd9rb   0/1     Completed   0          99m
    clcp-ucp-ceph-utility-6f4bbd4569-vrm7c                        1/1     Running     0          4h11m
    clcp-ucp-ceph-utility-config-ceph-ns-key-generator-pvfcl      0/1     Completed   0          4h12m
    clcp-ucp-ceph-utility-config-test                             0/1     Completed   0          4h12m

### 3.2 Execute into the Pod

    $kubectl exec -it [pod-name] -n utility /bin/bash

    rpc error: code = 2 desc = oci runtime error: exec failed: container_linux.go:247: starting container process caused "exec: \"/bin/\": permission denied"

    command terminated with exit code 126

The "permission denied" error is expected in this case because the user ID
entered in the configuration file is not a member in the UCP Keystone
RBAC to execute into the pod.
