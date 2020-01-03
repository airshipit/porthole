# Ceph-utility Container

The Ceph utility container enables Operations to check the state/stats
of Ceph resources in the Kubernetes cluster. This utility container enables
Operations to perform restricted administrative activities without exposing
the credentials or keyring.

## Generic Docker Makefile

This is a generic make and dockerfile for the Ceph utility container.
This can be used to create docker images using different Ceph releases and
Ubuntu releases

## Usage

```bash
   make CEPH_RELEASE=<release_name> UBUNTU_RELEASE=<release_name>
```

Example:

1. Create a docker image for the Ceph Luminous release on Ubuntu Xenial (16.04).

```bash
       make CEPH_RELEASE=luminous UBUNTU_RELEASE=xenial
```

2. Create a docker image for the Ceph Mimic release on Ubuntu Xenial (16.04).

```bash
       make CEPH_RELEASE=mimic UBUNTU_RELEASE=xenial
```

3. Create a docker image for the Ceph Luminous release on Ubuntu Bionic (18.04).

```bash
       make CEPH_RELEASE=luminous UBUNTU_RELEASE=bionic
```

4. Create a docker image for the Ceph Mimic release on Ubuntu Bionic (18.04).

```bash
       make CEPH_RELEASE=mimic UBUNTU_RELEASE=bionic
```

5. Get into the utility pod using `kubectl exec`.
   Perform an operation on the Ceph cluster as in the following example.

Example:

```
   utilscli ceph osd tree
   utilscli rbd ls
   utilscli rados lspools
```
