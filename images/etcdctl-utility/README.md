# Etcdctl Utility Container

## Prerequisites: Deploy Airship in a Bottle (AIAB)

To get started, deploy Airship and OpenStack Helm (OSH).
Execute the following in a fresh Ubuntu 16.04 VM having these minimum requirements:

* 4 vCPU
* 20 GB RAM
* 32 GB disk storage

1. Add the following entries to `/etc/sudoers`.

```
        root    ALL=(ALL) NOPASSWD: ALL
        ubuntu  ALL=(ALL) NOPASSWD: ALL
```

2. Install the latest versions of Git, CA Certs, and Make if necessary.

```bash
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

## Deploy Airship in a Bottle (AIAB)

Deploy Airship in a Bottle (AIAB), which deploys the etcdctl-utility pod.

```bash
        sudo -i \
        mkdir -p root/deploy && cd "$_" \
        git clone https://opendev.org/airship/treasuremap \
        cd /root/deploy/treasuremap/tools/deployment/aiab \
        ./airship-in-a-bottle.sh
```

## Usage and Test

Get into the etcdctl-utility pod using `kubectl exec`.
Perform an operation as in the following example.

```
        kubectl exec -it <POD_NAME> -n utility -- /bin/bash
```

Example:

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
        etcdctl version: 3.4.2
        API version: 3.3
        nobody@airship-etcdctl-utility-998b4f4d6-65x6d:/$
```
