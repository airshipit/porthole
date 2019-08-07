# Ceph Maintenance

This MOP covers Maintenance Activities related to Ceph.

## Table of Contents ##

<!-- TOC depthFrom:1 depthTo:6 withLinks:1 updateOnSave:1 orderedList:0 -->

- Table of Contents
	- 1. Generic commands
	- 2. Replace failed OSD

## 1. Generic Commands  ##

### Check OSD Status
To check the current status of OSDs, execute the following:

```
utilscli osd-maintenance check_osd_status
```

### OSD Removal
To purge OSDs in down state, execute the following:

```
utilscli osd-maintenance osd_remove
```

### OSD Removal By OSD ID
To purge OSDs by OSD ID in down state, execute the following:

```
utilscli osd-maintenance remove_osd_by_id --osd-id <OSDID>
```

### Reweight OSDs
To adjust an OSD’s crush weight in the CRUSH map of a running cluster, execute the following:

```
utilscli osd-maintenance reweight_osds
```

## 2. Replace failed OSD  ##

In the context of a failed drive, Please follow below procedure. Following commands should be run from utility container

Capture the failed OSD ID. Check for status `down`

	utilscli ceph osd tree

Remove the OSD from Cluster. Replace `<OSD_ID>` with above captured failed OSD ID

	utilscli osd-maintenance osd_remove_by_id --osd-id <OSD_ID>

Remove the failed drive and replace it with a new one without bringing down the node.

Once new drive is placed, delete the concern OSD pod in `error` or `CrashLoopBackOff` state. Replace `<pod_name>` with failed OSD pod name.

	kubectl delete pod <pod_name> -n ceph

Once pod is deleted, kubernetes will re-spin a new pod for the OSD. Once Pod is up, the osd is added to ceph cluster with weight equal to `0`. we need to re-weight the osd.

	utilscli osd-maintenance reweight_osds

