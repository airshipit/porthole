# Ceph Maintenance

This document provides procedures for maintaining Ceph OSDs.

## Check OSD Status

To check the current status of OSDs, execute the following.

```
utilscli osd-maintenance check_osd_status
```

## OSD Removal

To purge OSDs that are in the down state, execute the following.

```
utilscli osd-maintenance osd_remove
```

## OSD Removal by OSD ID

To purge down OSDs by specifying OSD ID, execute the following.

```
utilscli osd-maintenance remove_osd_by_id --osd-id <OSDID>
```

## Reweight OSDs

To adjust an OSD’s crush weight in the CRUSH map of a running cluster,
execute the following.

```
utilscli osd-maintenance reweight_osds
```

## Replace a Failed OSD

If a drive fails, follow these steps to replace a failed OSD.

1. Disable the OSD pod on the host to keep it from being rescheduled.

```
    kubectl label nodes --all ceph_maintenance_window=inactive
```

2. Below, replace `<NODE>` with the name of the node where the failed OSD pods exist.

```
    kubectl label nodes <NODE> --overwrite ceph_maintenance_window=active
```

3. Below, replace `<POD_NAME>` with the failed OSD pod name.

```
    kubectl patch -n ceph ds <POD_NAME> -p='{"spec":{"template":{"spec":{"nodeSelector":{"ceph-osd":"enabled","ceph_maintenance_window":"inactive"}}}}}'
```

Complete the recovery by executing the following commands from the Ceph utility container.

1. Capture the failed OSD ID. Check for status `down`.

```
    utilscli ceph osd tree
```

2. Remove the OSD from the cluster. Below, replace
`<OSD_ID>` with the ID of the failed OSD.

```
    utilscli osd-maintenance osd_remove_by_id --osd-id <OSD_ID>
```

3. Remove the failed drive and replace it with a new one without bringing down
the node.

4. Once the new drive is in place, change the label and delete the OSD pod that
is in the `error` or `CrashLoopBackOff` state. Below, replace `<POD_NAME>`
with the failed OSD pod name.

```
    kubectl label nodes <NODE> --overwrite ceph_maintenance_window=inactive
    kubectl delete pod <POD_NAME> -n ceph
```

Once the pod is deleted, Kubernetes will re-spin a new pod for the OSD.
Once the pod is up, the OSD is added to the Ceph cluster with a weight equal
to `0`. Re-weight the OSD.

```
    utilscli osd-maintenance reweight_osds
```
