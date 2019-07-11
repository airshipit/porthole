# MySqlClient Utility Container

## Prerequisites: Deploy OSH-AIO

## Installation

1. Add the below to /etc/sudoers

>root    ALL=(ALL) NOPASSWD: ALL \
ubuntu  ALL=(ALL) NOPASSWD: ALL

2. Install the latest versions of Git, CA Certs bundle & Make if necessary

>sudo apt-get update \
sudo apt-get dist-upgrade -y \
sudo apt-get install --no-install-recommends -y \
ca-certificates \
git \
make \
jq \
nmap \
curl \
uuid-runtime

3. Clone the OpenStack-Helm Repos

>git clone https://git.openstack.org/openstack/openstack-helm-infra.git \
git clone https://git.openstack.org/openstack/openstack-helm.git

4. Proxy Configuration

In order to deploy OpenStack-Helm behind corporate proxy servers (if any)
add the following entries to openstack-helm-infra/tools/gate/devel/local-vars.yaml

>proxy: \
http: http://username:password@host:port \
https: https://username:password@host:port \
noproxy: 127.0.0.1,localhost,172.17.0.1,.svc.cluster.local

Add the address of the Kubernetes API, 172.17.0.1, and .svc.cluster.local to your no_proxy and NO_PROXY environment variables.

>export no_proxy=${no_proxy},172.17.0.1,.svc.cluster.local \
export NO_PROXY=${NO_PROXY},172.17.0.1,.svc.cluster.local


5. Deploy Kubernetes & Helm
- cd openstack-helm
  - ./tools/deployment/developer/common/010-deploy-k8s.sh
- Setup Clients on the host and assemble the charts
  - ./tools/deployment/developer/common/020-setup-client.sh
- Deploy the ingress controller
  - ./tools/deployment/developer/common/030-ingress.sh
- Deploy Ceph
  - ./tools/deployment/developer/ceph/040-ceph.sh
- Activate the  namespace to be able to use Ceph
  - ./tools/deployment/developer/ceph/045-ceph-ns-activate.sh
-. Deploy Keystone
  - ./tools/deployment/developer/ceph/080-keystone.sh
- Deploy Heat
  - ./tools/deployment/developer/ceph/090-heat.sh
- Deploy Horizon
  - ./tools/deployment/developer/ceph/100-horizon.sh
- Deploy Glance
  - ./tools/deployment/developer/ceph/120-glance.sh
- Deploy Cinder
  - ./tools/deployment/developer/ceph/130-cinder.sh
- Deploy LibVirt
  - ./tools/deployment/developer/ceph/150-libvirt.sh
- Deploy Compute Kit (Nova and Neutron)
  - ./tools/deployment/developer/ceph/160-compute-kit.sh
- To run further commands from the CLI manually, execute the following to set up authentication credentials
  - export OS_CLOUD=openstack_helm

6. Clone the Porthole and this utility repo as well.
- $git clone https://review.opendev.org/airship/porthole

7. $cd porthole

**Optionally pull in this PS if it's not ready merged; otherwise, skip step below.**
- $git pull https://review.opendev.org/airship/porthole refs/changes/81/674881/[latest change set]

- **$bash ./install_mysqlclient_utility.sh**
---
<blockquote>

      +../../openstack-helm-infra
      + typeset uc=mysqlclient-utility
      + make mysqlclient-utility

     ===== Processing [mysqlclient-utility] chart =====
     make[1]: Entering directory '/home/ubuntu/osh/openstack-helm/porthole'
     if [ -f mysqlclient-utility/Makefile ]; then make -C mysqlclient-utility; fi
     if [ -f mysqlclient-utility/requirements.yaml ]; then helm dep up mysqlclient-utility; fi
     Hang tight while we grab the latest from your chart repositories...
     ...Successfully got an update from the "local" chart repository
     Update Complete. ⎈Happy Helming!⎈
     Saving 1 charts
     Downloading helm-toolkit from repo http://localhost:8879/charts
     Deleting outdated charts
     if [ -d mysqlclient-utility ]; then helm lint mysqlclient-utility; fi
     ==> Linting mysqlclient-utility
     [INFO] Chart.yaml: icon is recommended

     1 chart(s) linted, no failures
     if [ -d mysqlclient-utility ]; then helm package mysqlclient-utility; fi
     Successfully packaged chart and saved it to: /home/ubuntu/osh/openstack-helm/porthole/mysqlclient-utility-0.1.0.tgz
     make[1]: Leaving directory '/home/ubuntu/osh/openstack-helm/porthole'
     + helm upgrade --install mysqlclient-utility mysqlclient-utility --namespace=utility
     Release "mysqlclient-utility" does not exist. Installing it now.
     NAME:   mysqlclient-utility
     LAST DEPLOYED: Fri Jul 19 01:38:55 2019
     NAMESPACE: utility
     STATUS: DEPLOYED

     RESOURCES:
     ==> v1/ConfigMap
     NAME                           DATA  AGE
     mysqlclient-utility-bin        2     1s
     mysqlclient-utility-bin-utilscli  2     1s
     mysqlclient-utility-etc        2     1s
     mysqlclient-utility-sudoers    1     1s

     ==> v1/Deployment
     NAME                 READY  UP-TO-DATE  AVAILABLE  AGE
     mysqlclient-utility  0/1    1           0          1s

     ==> v1/Pod(related)
     NAME                                  READY  STATUS             RESTARTS  AGE
     mysqlclient-utility-775bf65c97-8z97s  0/1    ContainerCreating  0         1s

     ==> v1/ServiceAccount
     NAME                 SECRETS  AGE
     mysqlclient-utility  1        1s

     ==> v1beta1/ClusterRole
     NAME                 AGE
     mysqlclient-utility  1s

     ==> v1beta1/ClusterRoleBinding
     NAME                 AGE
     mysqlclient-utility  1s

     + ../../openstack-helm-infra/tools/deployment/common/wait-for-pods.sh utility
     + kubectl get pods -n utility
     + grep mysqlclient-utility
     mysqlclient-utility-775bf65c97-8z97s   1/1     Running   0          17s
     + helm status mysqlclient-utility
     LAST DEPLOYED: Fri Jul 19 01:38:55 2019
     NAMESPACE: utility
     STATUS: DEPLOYED

     RESOURCES:
     ==> v1/ConfigMap
     NAME                           DATA  AGE
     mysqlclient-utility-bin        2     18s
     mysqlclient-utility-bin-utilscli  2     18s
     mysqlclient-utility-etc        2     18s
     mysqlclient-utility-sudoers    1     18s

     ==> v1/Deployment
     NAME                 READY  UP-TO-DATE  AVAILABLE  AGE
     mysqlclient-utility  1/1    1           1          18s

     ==> v1/Pod(related)
     NAME                                  READY  STATUS   RESTARTS  AGE
     mysqlclient-utility-775bf65c97-8z97s  1/1    Running  0         18s

     ==> v1/ServiceAccount
     NAME                 SECRETS  AGE
     mysqlclient-utility  1        18s

     ==> v1beta1/ClusterRole
     NAME                 AGE
     mysqlclient-utility  18s

     ==> v1beta1/ClusterRoleBinding
     NAME                 AGE
     mysqlclient-utility  18s

     + helm test mysqlclient-utility --timeout 900
     RUNNING: mysqlclient-utility-check-mysql-client-installation
     PASSED: mysqlclient-utility-check-mysql-client-installation
</blockquote>


## POST-Installation

Validate pods are deployed and running

$ kubectl get pods -n utility
 - NAME                                                  READY   STATUS      RESTARTS   AGE
    - mysqlclient-utility-775bf65c97-8z97s                  1/1     Running     0          8m47s
    - mysqlclient-utility-check-mysql-client-installation   0/1     Completed   0          8m29s


## Usage & Test

Get in to the utility pod using kubectl exec, perform the followings:

### Case 1 - Execute into the pod
  $kubectl exec -it <POD_NAME> -n utility /bin/bash

### Case 2 - Test connectiviy to Mariadb (optional)

 - Find mariadb pod and its corresponding IP
---
   - $kubectl get pods --all-namespaces |grep -i mariadb-server |awk '{print $1,$2}'|while read a b ; do
      kubectl get pod $b -n $a -o wide
  done
---
- An Output should look similar to below

 - NAME               READY   STATUS    RESTARTS   AGE     IP               NODE      NOMINATED NODE   READINESS GATES
   - mariadb-server-0   1/1     Running   0          5h49m   192.168.251.93   mtn13b2   <none>           <none>

 - Now connect to the pod as prescribe in Case 1 by providing the arguements accordingly to CLI, like below.

   - $kubectl exec <POD_NAME> -it -n utility -- mysql -h <IP> -u root -p<PASSWORD> -e 'show databases;'

 It's expected to see an output looks similar to below.

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