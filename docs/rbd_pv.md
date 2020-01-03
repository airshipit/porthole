# RBD PVC/PV script

This document provides instructions for using the `rbd_pv` script to
perform Ceph maintenance actions such as
backing up and recovering PVCs within your Kubernetes environment.

## Usage

Execute `utilscli rbd_pv` without arguments to list usage options.

```
utilscli rbd_pv
Backup Usage: utilscli rbd_pv [-b <pvc name>] [-n <namespace>] [-d <backup dest> (optional, default: /tmp/backup)] [-p <ceph rbd pool> (optional, default: rbd)]
Restore Usage: utilscli rbd_pv [-r <restore_file>] [-p <ceph rbd pool> (optional, default: rbd)]
Snapshot Usage: utilscli rbd_pv [-b <pvc name>] [-n <namespace>] [-p <ceph rbd pool> (optional, default: rbd] [-s <create|rollback|remove> (required)]
```

## Backing up a PVC/PV from RBD

To backup a PV, execute the following.

```
utilscli rbd_pv -b mysql-data-mariadb-server-0 -n openstack
```

## Restoring a PVC/PV Backup

To restore a PV RBD backup image, execute the following.

```
utilscli rbd_pv -r /backup/kubernetes-dynamic-pvc-ab1f2e8f-21a4-11e9-ab61-ca77944df03c.img
```

**Note:** The original PVC/PV will be renamed, not overwritten.

**Important:** Before restoring, you _must_ ensure the PVC/PV is not mounted!

## Creating a Snapshot for a PVC/PV

```
utilscli rbd_pv -b mysql-data-mariadb-server-0 -n openstack -s create
```

## Rolling Back to a Snapshot for a PVC/PV

```
utilscli rbd_pv -b mysql-data-mariadb-server-0 -n openstack -s rollback
```

**Important:** Before rolling back a snapshot, you _must_ ensure the PVC/PV volume is not mounted!

## Removing a Snapshot for a PVC/PV

**Important:** This command removes all snapshots in Ceph associated with this PVC/PV!

```
utilscli rbd_pv -b mysql-data-mariadb-server-0 -n openstack -s remove
```

## Show Snapshot and Image Details for a PVC/PV

```
utilscli rbd_pv -b mysql-data-mariadb-server-0 -n openstack -s show
```
