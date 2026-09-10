#!/bin/bash
#    Licensed under the Apache License, Version 2.0 (the "License"); you may
#    not use this file except in compliance with the License. You may obtain
#    a copy of the License at
#
#         http://www.apache.org/licenses/LICENSE-2.0
#
#    Unless required by applicable law or agreed to in writing, software
#    distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
#    WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
#    License for the specific language governing permissions and limitations
#    under the License.

# Wait for every workload in a namespace to settle, using only kubectl: every
# deployment, statefulset and daemonset must reach its desired ready replica
# count, and every Job must be Complete.
#
# This replaces `helm osh wait-for-pods`, which came from the standalone
# openstack-helm-plugin repo. openstack-helm dropped that dependency in
# I0c1c3fe5 ("Wait natively instead of via the openstack-helm plugin") and this
# is the same logic, lifted out of roles/deploy-charts/tasks/_wait.yaml into a
# script so the tools/deployment/* gate scripts can call it directly.
#
# Usage: wait-for-pods.sh <namespace> [timeout-seconds]

# -E so the ERR trap below is inherited by the wait_ready function; without it
# a failure inside a function exits without printing any diagnostics.
set -Eeo pipefail

usage() {
    echo "Usage: $0 <namespace> [timeout]" >&2
    exit 1
}

[ $# -lt 1 ] && usage

ns="$1"
# The plugin defaulted to 900s; keep that so gate timings do not shift.
timeout="${2:-900}"
# Lines of container log to print per container when something fails.
log_tail="${OSH_WAIT_LOG_TAIL:-200}"

# Dump enough state to debug a stuck namespace, mirroring what the plugin
# printed on timeout. current_resource names whatever we were waiting on, so
# the output leads with the thing that actually failed.
current_resource=""

# Re-run a pod's exec probes and show their output.
#
# kubectl only ever reports the first line of a failing probe in the pod
# events, which is rarely enough: a probe like mariadb's health.sh runs a
# dozen checks and the event just says which one tripped, not why. Running the
# same command through exec gives us its full stdout/stderr and exit code.
#
# Only exec probes are handled; there is nothing useful to re-run for httpGet
# or tcpSocket, and those report their own failure reason accurately.
dump_probes() {
    local pod="$1" containers container probe cmd rc
    local -a argv

    containers=$(kubectl get "pod/${pod}" --namespace="${ns}" \
        -o jsonpath='{range .spec.containers[*]}{.name}{"\n"}{end}' 2>/dev/null) || return 0

    for container in ${containers}; do
        for probe in readinessProbe livenessProbe; do
            # One argument per line, so that an argument containing spaces
            # survives the round trip into exec intact.
            cmd=$(kubectl get "pod/${pod}" --namespace="${ns}" -o jsonpath="\
{range .spec.containers[?(@.name=='${container}')].${probe}.exec.command[*]}{@}{'\n'}{end}" \
                2>/dev/null) || continue
            [ -z "${cmd}" ] && continue
            mapfile -t argv <<<"${cmd}"

            echo "--- ${probe} rerun: ${pod}/${container} ---"
            # A non-zero exit is the whole point of running this, so it must
            # not trip the ERR trap.
            rc=0
            kubectl exec "${pod}" --namespace="${ns}" -c "${container}" -- \
                "${argv[@]}" 2>&1 || rc=$?
            echo "(exit ${rc})"
        done
    done
}

dump_debug() {
    echo
    echo "=== DEBUG: ${current_resource:-namespace ${ns}} did not become ready within ${timeout}s ==="
    if [ -n "${current_resource}" ]; then
        kubectl describe "${current_resource}" --namespace="${ns}" || true
        echo
    fi
    echo "=== Workloads ==="
    kubectl get deployment,statefulset,daemonset,job --namespace="${ns}" || true
    echo
    echo "=== Pods ==="
    kubectl get pods --namespace="${ns}" -o wide || true
    echo
    echo "=== Not-ready pods, with detail and logs ==="
    # The READY column ("0/1") rather than status.phase: a pod that is Running
    # but failing its readiness or liveness probe is exactly the case we are
    # usually stuck on, and a phase filter would skip it. kubectl's jsonpath
    # cannot express this directly, since it does not support a filter nested
    # inside a filter expression.
    kubectl get pods --namespace="${ns}" --no-headers 2>/dev/null \
        | awk '$3 != "Completed" {split($2, r, "/"); if (r[1] != r[2]) print $1}' \
        | while read -r pod; do
        [ -z "${pod}" ] && continue
        kubectl describe "pod/${pod}" --namespace="${ns}" || true
        echo
        echo "--- logs: ${pod} ---"
        kubectl logs "${pod}" --namespace="${ns}" --all-containers \
            --tail="${log_tail}" || true
        # A pod that keeps restarting has already discarded the interesting
        # output, so the previous container's log is the one that explains it.
        #
        # This must be done one container at a time. With --all-containers,
        # kubectl fails the whole request if *any* container lacks a previous
        # instance - which is always true of the init containers - so the log
        # we actually want is never printed.
        kubectl get "pod/${pod}" --namespace="${ns}" \
            -o jsonpath='{range .spec.containers[*]}{.name}{"\n"}{end}' \
            2>/dev/null \
            | while read -r c; do
            [ -z "${c}" ] && continue
            echo "--- logs (previous): ${pod}/${c} ---"
            kubectl logs "${pod}" --namespace="${ns}" -c "${c}" \
                --previous --tail="${log_tail}" 2>&1 || true
        done
        echo
        dump_probes "${pod}"
        echo
    done
    echo "=== PVCs (an unbound claim keeps pods Pending) ==="
    kubectl get pvc --namespace="${ns}" || true
    echo
    # Ceph backs the "general" storage class in this gate, so a pod whose
    # volume throws EIO is a cluster problem rather than an application one.
    # Show health and OSD utilisation: a full or near-full OSD is the usual
    # cause, and it is invisible from the workload namespace.
    if kubectl get namespace ceph >/dev/null 2>&1; then
        ceph_pod=$(kubectl get pods --namespace=ceph \
            -l application=ceph,component=mon \
            -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
        if [ -n "${ceph_pod:-}" ]; then
            echo "=== Ceph status ==="
            kubectl exec "${ceph_pod}" --namespace=ceph -- \
                ceph -s 2>&1 || true
            echo
            echo "=== Ceph OSD utilisation ==="
            kubectl exec "${ceph_pod}" --namespace=ceph -- \
                ceph osd df 2>&1 || true
            echo
            echo "=== Ceph pool utilisation ==="
            kubectl exec "${ceph_pod}" --namespace=ceph -- \
                ceph df 2>&1 || true
            echo
        fi
        # A healthy cluster can still hand the node a broken block device:
        # the map can drop, or the filesystem on top of it can go read only.
        # That failure is only visible from the node, and this gate is a
        # single node, so the node is the host running this script.
        echo "=== Storage class ==="
        kubectl get storageclass general -o yaml 2>&1 || true
        echo
        echo "=== Mapped RBD devices ==="
        ls -l /dev/rbd* 2>&1 || true
        grep -E '/dev/rbd' /proc/mounts 2>&1 || true
        echo
        echo "=== Kernel messages (rbd, ceph, filesystem, I/O) ==="
        if command -v dmesg >/dev/null 2>&1; then
            # dmesg is root only on most distros; the gate user has sudo.
            # "nbd" matters as much as "rbd": when an rbd-nbd daemon stops
            # answering, the kernel says so as "block nbd0: Receive control
            # failed" / "shutting down sockets", which no rbd pattern
            # matches. "Out of memory" catches the daemon being OOM killed.
            (sudo dmesg -T 2>/dev/null || dmesg -T 2>/dev/null || true) \
                | grep -iE 'rbd|nbd|libceph|ceph:|EXT4-fs|I/O error|blk_update|Out of memory|oom-kill' \
                | tail -n 120 || true
        fi
        echo
        # The "general" class uses the rbd-nbd mounter, so every I/O on a
        # /dev/nbd* device is served by an rbd-nbd daemon running inside the
        # csi-rbdplugin container. If that daemon dies the kernel has no one
        # to answer, and the device starts returning EIO while the cluster
        # itself stays healthy - exactly the symptom we are chasing. A
        # non-zero restart count on the plugin pod is the thing to look for.
        echo "=== Ceph namespace pods (watch csi-rbdplugin restarts) ==="
        kubectl get pods --namespace=ceph -o wide 2>&1 || true
        echo
        echo "=== csi-rbdplugin logs ==="
        kubectl get pods --namespace=ceph \
            -l application=rbd,component=plugin \
            -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' \
            2>/dev/null \
            | while read -r p; do
            [ -z "${p}" ] && continue
            echo "--- logs: ${p}/csi-rbdplugin ---"
            kubectl logs "${p}" --namespace=ceph -c csi-rbdplugin \
                --tail="${log_tail}" 2>&1 || true
            echo "--- logs (previous): ${p}/csi-rbdplugin ---"
            kubectl logs "${p}" --namespace=ceph -c csi-rbdplugin \
                --previous --tail="${log_tail}" 2>&1 || true
            # The rbd-nbd daemons are children of this container, and they
            # log to files inside it rather than to the container's stdout.
            # If a daemon exited, its own log is the only place that says
            # why, so read it directly.
            echo "--- rbd-nbd processes: ${p} ---"
            kubectl exec "${p}" --namespace=ceph -c csi-rbdplugin -- \
                ps -eo pid,stat,etime,comm,args 2>&1 \
                | grep -E 'rbd-nbd|PID' || true
            echo "--- rbd-nbd mapped devices: ${p} ---"
            kubectl exec "${p}" --namespace=ceph -c csi-rbdplugin -- \
                rbd-nbd list-mapped 2>&1 || true
            echo "--- rbd-nbd logs: ${p} ---"
            kubectl exec "${p}" --namespace=ceph -c csi-rbdplugin -- \
                sh -c 'tail -n 80 /var/log/ceph/rbd-nbd*.log 2>&1' 2>&1 || true
        done
        echo
    fi
    echo "=== Events ==="
    kubectl get events --namespace="${ns}" --sort-by=.lastTimestamp || true
}
trap dump_debug ERR

# Wait until a workload's ready replica count reaches the desired one.
#
# `kubectl rollout status` is not usable here: it refuses any workload whose
# strategy is not RollingUpdate ("error: rollout status is only available for
# RollingUpdate strategy type"), and OSH has both Recreate deployments
# (mariadb-controller, nfs-provisioner, rabbitmq-topology-controller) and
# statefulsets whose update strategy is values-configurable through
# pod.lifecycle.upgrades.statefulsets. Comparing the status counts works for
# every strategy and asserts what we actually care about: every pod ready.
#
# Waiting on the controller rather than on `pod --all` is deliberate: kubectl
# wait snapshots the matching resources when it starts, so pods a controller
# has not created yet would be skipped and the wait would succeed vacuously.
wait_ready() {
    local resource="$1" want_path="$2" got_path="$3" want
    current_resource="${resource}"
    want=$(kubectl get "${resource}" --namespace="${ns}" -o jsonpath="${want_path}")
    # No replicas desired (scaled to zero, or a daemonset whose node selector
    # matches nothing) - nothing to wait for.
    if [ -z "${want}" ] || [ "${want}" -eq 0 ]; then
        echo "${resource}: 0 desired, skipping"
        return 0
    fi
    kubectl wait --for=jsonpath="${got_path}=${want}" "${resource}" \
        --namespace="${ns}" --timeout="${timeout}s"
}

# Assign first: a failing command substitution in a for-loop word list does not
# trip set -e.
workloads=$(kubectl get deployment,statefulset --namespace="${ns}" -o name)
for resource in ${workloads}; do
    wait_ready "${resource}" '{.spec.replicas}' '{.status.readyReplicas}'
done

daemonsets=$(kubectl get daemonset --namespace="${ns}" -o name)
for resource in ${daemonsets}; do
    wait_ready "${resource}" '{.status.desiredNumberScheduled}' \
        '{.status.numberReady}'
done

# kubectl wait --all errors out when nothing matches, so the job names are
# listed first and waited on one at a time.
#
# A Job named by that listing can legitimately be gone by the time we wait for
# it: these namespaces have CronJobs whose Jobs the controller prunes per
# successfulJobsHistoryLimit, and finished Jobs may carry
# ttlSecondsAfterFinished. Walking a large namespace takes long enough for that
# to happen mid-loop, so treat a Job that has disappeared as nothing left to
# wait for. Anything else - notably a real timeout - still fails the script.
jobs=$(kubectl get job --namespace="${ns}" -o name)
for job in ${jobs}; do
    current_resource="${job}"
    if out=$(kubectl wait --for=condition=Complete "${job}" \
               --namespace="${ns}" --timeout="${timeout}s" 2>&1); then
        echo "${out}"
    elif [ "${out}" != "${out#*NotFound}" ]; then
        echo "${job}: no longer exists, skipping"
    else
        echo "${out}" >&2
        exit 1
    fi
done

trap - ERR
echo "All workloads in namespace ${ns} are ready"
