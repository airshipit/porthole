#!/bin/bash

{{/*
Copyright 2019 The Openstack-Helm Authors.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

   http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/}}

usage() {
  echo "Backup Usage: utilscli rbd_pv [-b <pvc name>] [-n <namespace>] [-d <backup dest> (optional, default: /backup)] [-p <ceph rbd pool> (optional, default: rbd)]"
  echo "Restore Usage: utilscli rbd_pv [-r <restore_file>] [-p <ceph rbd pool> (optional, default: rbd)]"
  echo "Snapshot Usage: utilscli rbd_pv [-b <pvc name>] [-n <namespace>] [-p <ceph rbd pool> (optional, default: rbd] [-s <create|rollback|remove|show> (required) ]"
  exit 1
}

while getopts ":b:p:n:d:r:h:s:" opt; do
  case $opt
  in
    b) pvc_name=${OPTARG};;
    n) nspace=${OPTARG};;
    d) backup_dest=${OPTARG};;
    r) restore_file=${OPTARG};;
    p) rbd_pool=${OPTARG};;
    s) snapshot=${OPTARG};;
    h) usage ;;
  esac
done

if [[ -z "${pvc_name}" || -z "${nspace}" ]]; then
  if [[ -z "${restore_file}" ]]; then
    usage
    echo "ERROR: Missing command line arguement(s)!"
    exit 1
  fi
fi

if [[ -z "${rbd_pool}" ]]; then
  rbd_pool="rbd"
fi

timestamp="$(date +%F_%T)"

if [[ ! -z "${restore_file}" ]]; then
  if [[ -e "${restore_file}" ]]; then
    rbd_image="$(echo "${restore_file}" | rev | awk -v FS='/' '{print $1}' | rev | cut -f 1 -d '.')"
    if (utilscli rbd info "${rbd_pool}"/"${rbd_image}" | grep -q id); then
      utilscli rbd mv ${rbd_pool}/${rbd_image} ${rbd_pool}/${rbd_image}.orig-${timestamp}
      echo "WARNING: Existing PVC/RBD image has been moved to ${rbd_pool}/${rbd_image}.orig-${timestamp}"
    fi
    utilscli rbd import ${restore_file} ${rbd_pool}/${rbd_image}
    echo "INFO: Backup has been restored into ${rbd_pool}/${rbd_image}"
  else
    echo "ERROR: Missing restore file!"
    exit 1
  fi
elif [[ ! -z "${snapshot}" ]]; then
  volume="$(kubectl -n ${nspace} get pvc ${pvc_name} --no-headers | awk '{ print $3 }')"
  rbd_image="$(kubectl get pv "${volume}" -o json | jq -r '.spec.rbd.image')"

  if [[ "x${snapshot}x" == "xcreatex" ]]; then
    snap_name="${pvc_name}-${timestamp}"
    utilscli rbd snap create ${rbd_pool}/${rbd_image}@${snap_name}
    echo "INFO: Snapshot ${rbd_pool}/${rbd_image}@${snap_name} has been created for PVC ${pvc_name}"
  elif [[ "x${snapshot}x" == "xrollback" ]]; then
    snap_name=$(utilscli rbd snap ls ${rbd_pool}/${rbd_image})
    utilscli rbd snap rollback ${rbd_pool}/${rbd_image}@${snap_name}
    echo "WARNING: Rolled back snapshot ${rbd_pool}/${rbd_image}@${snap_name} for ${pvc_name}"
  elif [[ "x${snapshot}x" == "xremovex" ]]; then
    utilscli rbd snap purge ${rbd_pool}/${rbd_image}
    echo "Removed snapshot(s) for ${pvc_name}"
  elif [[ "x${snapshot}x" == "xshowx" ]]; then
    echo "INFO: This PV is mapped to the following RBD Image:"
    echo "${rbd_pool}/${rbd_image}"
    echo -e "\nINFO: Current open sessions to RBD Image:"
    utilscli rbd status ${rbd_pool}/${rbd_image}
    echo -e "\nINFO: RBD Image information:"
    utilscli rbd info ${rbd_pool}/${rbd_image}
    echo -e "\nINFO: RBD Image snapshot details:"
    rbd snap ls ${rbd_pool}/${rbd_image}
    echo -e "\nINFO: RBD Image size details:"
    utilscli rbd du ${rbd_pool}/${rbd_image}
  else
    echo "ERROR: Missing arguement for snapshot option!"
  fi
else
  if [[ -z "${backup_dest}" ]]; then
    backup_dest="/backup"
  fi
  if [[ ! -d "${backup_dest}" ]]; then
    echo "ERROR: Backup destination does not exist, cannot continue with the backup!"
    exit 1
  fi

  echo "INFO: Backing up ${pvc_name} within namespace ${nspace}"
  volume="$(kubectl -n ${nspace} get pvc ${pvc_name} --no-headers | awk '{ print $3 }')"
  rbd_image="$(kubectl get pv "${volume}" -o json | jq -r '.spec.rbd.image')"

  if [[ -z "${volume}" ]] || (! utilscli rbd info "${rbd_pool}"/"${rbd_image}" | grep -q id); then
    echo "ERROR: PVC does not exist or is missing! Cannot continue with backup for ${pvc_name}"
    exit 1
  else
    # Create current snapshot and export to a file
    snap_name="${pvc_name}-${timestamp}"
    backup_name="${rbd_image}.${pvc_name}-${timestamp}"
    utilscli rbd snap create ${rbd_pool}/${rbd_image}@${snap_name}
    utilscli rbd export ${rbd_pool}/${rbd_image}@${snap_name} ${backup_dest}/${backup_name}
    # Remove snapshot otherwise we may see an issue cleaning up the PVC from K8s, and from Ceph.
    utilscli rbd snap rm ${rbd_pool}/${rbd_image}@${snap_name}
    echo "INFO: PV ${pvc_name} saved to:"
    echo "${backup_dest}/${backup_name}"
  fi
fi

exit 0
