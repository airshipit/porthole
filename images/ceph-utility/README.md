# Ceph-utility Container

This CEPH utility container will help the Operation user to check the state/stats
of Ceph resources in the K8s Cluster. This utility container will help to perform
restricted admin level activities without exposing credentials/Keyring to user in
utility container.

## Generic Docker Makefile


This is a generic make and dockerfile for ceph utility container.
This can be used to create docker images using different ceph releases and ubuntu releases

## Usage

make CEPH_RELEASE=<release_name> UBUNTU_RELEASE=<release_name>

example:

1. Create docker image for ceph luminous release on ubuntu xenial (16.04)

   make CEPH_RELEASE=luminous UBUNTU_RELEASE=xenial

2. Create docker image for ceph mimic release on ubuntu xenial (16.04)

   make CEPH_RELEASE=mimic UBUNTU_RELEASE=xenial

3. Create docker image for ceph luminous release on ubuntu bionic (18.04)

   make CEPH_RELEASE=luminous UBUNTU_RELEASE=bionic

4. Create docker image for ceph mimic release on ubuntu bionic (18.04)

   make CEPH_RELEASE=mimic UBUNTU_RELEASE=bionic

5. Get in to the utility pod using kubectl exec.
   To perform any operation on the ceph cluster use the below example.

example:
   utilscli ceph osd tree
   utilscli rbd ls
   utilscli rados lspools
