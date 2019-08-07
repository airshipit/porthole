# RBD PVC/PV script

This MOP covers Maintenance Activities related to using the rbd_pv script
to backup and recover PVCs within your kubernetes environment using Ceph.

## Usage
Execute utilscli rbd_pv without arguements to list usage options.

```
utilscli rbd_pv
Backup Usage: utilscli rbd_pv [-b <pvc name>] [-n <namespace>] [-d <backup dest> (optional, default: /tmp/backup)] [-p <ceph rbd pool> (optional, default: rbd)]
Restore Usage: utilscli rbd_pv [-r <restore_file>] [-p <ceph rbd pool> (optional, default: rbd)]
Snapshot Usage: utilscli rbd_pv [-b <pvc name>] [-n <namespace>] [-p <ceph rbd pool> (optional, default: rbd] [-s <create|rollback|remove> (required)]
```

## Backing up a PVC/PV from RBD
To backup a PV, execute the following:

```
utilscli rbd_pv -b mysql-data-mariadb-server-0 -n openstack
```

## Restoring a PVC/PV backup
To restore a PV RBD backup image, execute the following:

```
utilscli rbd_pv -r /backup/kubernetes-dynamic-pvc-ab1f2e8f-21a4-11e9-ab61-ca77944df03c.img
```
NOTE: The original PVC/PV will be renamed and not overwritten.
NOTE: Before restoring, you _must_ ensure it is not mounted!

## Creating a Snapshot for a PVC/PV

```
utilscli rbd_pv -b mysql-data-mariadb-server-0 -n openstack -s create
```

## Rolling back to a Snapshot for a PVC/PV

```
utilscli rbd_pv -b mysql-data-mariadb-server-0 -n openstack -s rollback
```

NOTE: Before rolling back a snapshot, you _must_ ensure the PVC/PV volume is not mounted!!

## Removing a Snapshot for a PVC/PV

```
utilscli rbd_pv -b mysql-data-mariadb-server-0 -n openstack -s remove
```

NOTE: This will remove all snapshots in Ceph associated to this PVC/PV!

## Show Snapshot and Image details for a PVC/PV

```
utilscli rbd_pv -b mysql-data-mariadb-server-0 -n openstack -s show
```
