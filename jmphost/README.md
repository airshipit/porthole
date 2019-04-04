# Jump host installation

The install will Kubernetes client and the corresponding dependencies in order
to able to connect to K8S cluster remotely.  It will also  create a generic
kubectl configuration file with appropriate attributes required.

This revision covers the implementation as described. [k8s-keystone-auth](
https://github.com/kubernetes/cloud-provider-openstack/blob/master/docs/using-keystone-webhook-authenticator-and-authorizer.md#new-kubectl-clients-from-v1110-and-later)

## 1. Pre-requisites

* Ubuntu OS version 14.x or higher
* Connectivity to the Internet
* The installer has sudo ability without prompting for password
* Installer's Git profile setup accordingly

## 2. Installation

### 2.1 Clone Porthole main project

    $git clone https://review.opendev.org/airship/porthole

     Cloning into 'porthole'...
     remote: Counting objects: 362, done
     remote: Finding sources: 100% (362/362)
     remote: Total 362 (delta 185), reused 311 (delta 185)
     Receiving objects: 100% (362/362), 98.30 KiB | 0 bytes/s, done.
     Resolving deltas: 100% (185/185), done.
     Checking connectivity... done.

### 2.2 Pull PatchSet (optional)

    $cd porthole
    $git pull https://review.opendev.org/airship/porthole refs/changes/92/674892/[latest change set]

    remote: Counting objects: 10, done
    remote: Finding sources: 100% (8/8)
    remote: Total 8 (delta 2), reused 7 (delta 2)
    Unpacking objects: 100% (8/8), done.
    From https://review.opendev.org/airship/porthole
    branch            refs/changes/92/674892/9 -> FETCH_HEAD
    Merge made by the 'recursive' strategy.
    jmphost/README.md           | 130 ++++++++++++++++++++++++++++++++++++++++
    jmphost/funs_uc.sh          |  57 ++++++++++++++++++++++++++++++++++++++++
    jmphost/setup-access.sh     | 132 ++++++++++++++++++++++++++++++++++++++++
    zuul.d/jmphost-utility.yaml |  35 ++++++++++++++++++++++++++++++++++++++++

    4 files changed, 354 insertions(+)
    create mode 100644 jmphost/README.md
    create mode 100755 jmphost/funs_uc.sh
    create mode 100755 jmphost/setup-access.sh
    create mode 100644 zuul.d/jmphost-utility.yaml

### 2.3 Run Setup

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

## Validation

- Now log out and log back in as the user.
- Update the configuration file with user corresponding credentials.

For testing purposes:
- Replacing **"OS_USERNAME"** and **"OS_PASSWORD"** with UCP Keystone credentials
- Set the **"OS_PROJECT_NAME"** value accordingly

### List pods

    $kubectl get pods -n utility

    NAME                                                          READY   STATUS      RESTARTS   AGE
    clcp-calicoctl-utility-6457864fc8-zpfxk                       1/1     Running     0          4h27m
    clcp-ncct-utility-6588ff5566-8mqsb                            1/1     Running     0          4h27m
    clcp-tenant-ceph-utility-7b8f6d45f8-5q4ts                     1/1     Running     0          99m
    clcp-tenant-ceph-utility-config-ceph-ns-key-generator-hd9rb   0/1     Completed   0          99m
    clcp-ucp-ceph-utility-6f4bbd4569-vrm7c                        1/1     Running     0          4h11m
    clcp-ucp-ceph-utility-config-ceph-ns-key-generator-pvfcl      0/1     Completed   0          4h12m
    clcp-ucp-ceph-utility-config-test                             0/1     Completed   0          4h12m

### Execute into the pod

    $kubectl exec -it [pod-name] -n utility /bin/bash

    rpc error: code = 2 desc = oci runtime error: exec failed: container_linux.go:247: starting container process caused "exec: \"/bin/\": permission denied"

    command terminated with exit code 126

Because the user id entered in the configuration file is not a member in UCP keystone
RBAC to execute into the pod, it's expecting to see "permission denied".