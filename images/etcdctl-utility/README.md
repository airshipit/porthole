# etcdctl utility Container

## Prerequisites: Deploy Airship in a Bottle(AIAB)

To get started, run the following in a fresh Ubuntu 16.04 VM (minimum 4vCPU/20GB RAM/32GB disk).
This will deploy Airship and Openstack Helm (OSH).

1. Add the below to /etc/sudoers

```
root    ALL=(ALL) NOPASSWD: ALL
ubuntu  ALL=(ALL) NOPASSWD: ALL
```

2. Install the latest versions of Git, CA Certs & bundle & Make if necessary

```
set -xe \
sudo apt-get update \
sudo apt-get install --no-install-recommends -y \
ca-certificates \
git \
make \
jq \
nmap \
curl \
uuid-runtime
```

## Deploy Airship in a Bottle(AIAB)

Deploy AirShip in a Bottle(AIAB) which will deploy etcdctl-utility pod.

```
sudo -i \
mkdir -p root/deploy && cd "$_" \
git clone https://opendev.org/airship/treasuremap \
cd /root/deploy/treasuremap/tools/deployment/aiab \
./airship-in-a-bottle.sh
```

## Usage and Test

Get in to the etcdctl-utility pod using kubectl exec.
To perform any operation use the below example.

```
$kubectl exec -it <POD_NAME> -n utility -- /bin/bash
```

example:

```
utilscli etcdctl member list
utilscli etcdctl endpoint health
utilscli etcdctl endpoint status

nobody@airship-etcdctl-utility-998b4f4d6-65x6d:/$ utilscli etcdctl member list
90d1b75fa1b31b89, started, ubuntu, https://10.0.2.15:2380, https://10.0.2.15:2379
ab1f60375c5ef1d3, started, auxiliary-1, https://10.0.2.15:22380, https://10.0.2.15:22379
d8ed590018245b3c, started, auxiliary-0, https://10.0.2.15:12380, https://10.0.2.15:12379
nobody@airship-etcdctl-utility-998b4f4d6-65x6d:/$ utilscli etcdctl endpoint health
https://kubernetes-etcd.kube-system.svc.cluster.local:2379 is healthy:
successfully committed proposal: took = 1.787714ms
nobody@airship-etcdctl-utility-998b4f4d6-65x6d:/$ utilscli etcdctl alarm list
nobody@airship-etcdctl-utility-998b4f4d6-65x6d:/$ utilscli etcdctl version
etcdctl version: 3.3.12
API version: 3.3
nobody@airship-etcdctl-utility-998b4f4d6-65x6d:/$
```
