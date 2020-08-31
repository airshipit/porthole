#!/bin/bash

{{- $envAll := . }}

export ETCD_POD_NAMESPACE=$1
if [[ $ETCD_POD_NAMESPACE == "" ]]; then
  echo "No namespace given - cannot spawn ondemand job."
  exit 1
fi

export ETCD_CONF_SECRET={{ $envAll.Values.conf.etcd_backup_restore.secrets.kube_system.conf_secret }}
export ETCD_IMAGE_NAME=$(kubectl get cronjob -n ${ETCD_POD_NAMESPACE} kubernetes-etcd-backup -o yaml -o jsonpath="{range .spec.jobTemplate.spec.template.spec.containers[*]}{.image}{'\n'}{end}" | grep etcdctl-utility)
export ETCD_BACKUP_BASE_PATH=$(kubectl get secret -o yaml -n ${ETCD_POD_NAMESPACE} ${ETCD_CONF_SECRET} | grep BACKUP_BASE_PATH | awk '{print $2}' | base64 -d)
ETCD_REMOTE_BACKUP_ENABLED=$(kubectl get secret -o yaml -n ${ETCD_POD_NAMESPACE} ${ETCD_CONF_SECRET} | grep REMOTE_BACKUP_ENABLED | awk '{print $2}' | base64 -d)
export ETCD_REMOTE_BACKUP_ENABLED=$(echo $ETCD_REMOTE_BACKUP_ENABLED | sed 's/"//g')

if [[ $NODE == "" ]];then
  echo "Cannot find node to run ondemand job from."
  exit 1
fi

if [[ $ETCD_IMAGE_NAME == "" ]]; then
  echo "Cannot find the utility image for populating ETCD_IMAGE_NAME variable."
  exit 1
fi

export TMP_FILE=$(mktemp -p /tmp)

cat > $TMP_FILE << EOF
---
apiVersion: batch/v1
kind: Job
metadata:
  name: etcd-ondemand
  annotations:
    {{ tuple $envAll | include "helm-toolkit.snippets.release_uuid" }}
  labels:
{{ tuple $envAll "etcd-ondemand" "ondemand" | include "helm-toolkit.snippets.kubernetes_metadata_labels" | indent 4 }}
spec:
  template:
    metadata:
      annotations:
        {{ tuple $envAll | include "helm-toolkit.snippets.release_uuid" }}
{{ dict "envAll" $envAll "podName" "etcd-ondemand" "containerNames" (list  "etcd-ondemand" ) | include "helm-toolkit.snippets.kubernetes_mandatory_access_control_annotation" | indent 8 }}
      labels:
{{ tuple $envAll "etcd-ondemand" "ondemand" | include "helm-toolkit.snippets.kubernetes_metadata_labels" | indent 8 }}
    spec:
{{ dict "envAll" $envAll "application" "etcd_ondemand" | include "helm-toolkit.snippets.kubernetes_pod_security_context" | indent 6 }}
      restartPolicy: OnFailure
      serviceAccountName: kubernetes-etcd-etcd-backup
      nodeName: ${NODE}
      containers:
        - name: etcd-ondemand
          image: ${ETCD_IMAGE_NAME}
{{ tuple $envAll $envAll.Values.pod.resources.jobs.etcd_ondemand | include "helm-toolkit.snippets.kubernetes_resources" | indent 10 }}
{{ dict "envAll" $envAll "application" "etcd_ondemand" "container" "etcd_ondemand" | include "helm-toolkit.snippets.kubernetes_container_security_context" | indent 10 }}
          command:
            - /bin/sleep
            - "1000000"
          env:
            - name: ETCDCTL_API
              value: "{{ .Values.conf.etcd.etcdctl_api }}"
            - name: ETCDCTL_DIAL_TIMEOUT
              value: 10s
            - name: ETCDCTL_CACERT
              value: /etc/etcd/tls/certs/client-ca.pem
            - name: ETCDCTL_CERT
              value: /etc/etcd/tls/certs/anchor-etcd-client.pem
            - name: ETCDCTL_KEY
              value: /etc/etcd/tls/keys/anchor-etcd-client-key.pem
            - name: ETCDCTL_ENDPOINTS
              value: https://{{ .Values.conf.etcd.endpoints }}:{{ .Values.endpoints.etcd.port.client.default }}
            - name: ONDEMAND_JOB
              value: etcd-ondemand
            - name: ARCHIVE_DIR
              value: $ETCD_BACKUP_BASE_PATH/db/$ETCD_POD_NAMESPACE/etcd/archive
            - name: BACKUP_RESTORE_SCOPE
              value: etcd
            - name: BACKUP_RESTORE_NAMESPACE_LIST
              value: $ETCD_POD_NAMESPACE
            - name: ETCD_BACKUP_BASE_DIR
              valueFrom:
                secretKeyRef:
                  key: BACKUP_BASE_PATH
                  name: ${ETCD_CONF_SECRET}
            - name: POD_NAMESPACE
              value: ${ETCD_POD_NAMESPACE}
            - name: REMOTE_BACKUP_ENABLED
              valueFrom:
                secretKeyRef:
                  key: REMOTE_BACKUP_ENABLED
                  name: ${ETCD_CONF_SECRET}
            - name: CONTAINER_NAME
              valueFrom:
                secretKeyRef:
                  key: REMOTE_BACKUP_CONTAINER
                  name: ${ETCD_CONF_SECRET}
            - name: OS_IDENTITY_API_VERSION
              value: "3"
EOF

if $ETCD_REMOTE_BACKUP_ENABLED; then
  export ETCD_RGW_SECRET={{ $envAll.Values.conf.etcd_backup_restore.secrets.kube_system.rgw_secret }}
  cat >> $TMP_FILE << EOF
            - name: OS_AUTH_URL
              valueFrom:
                secretKeyRef:
                  name: ${ETCD_RGW_SECRET}
                  key: OS_AUTH_URL
            - name: OS_REGION_NAME
              valueFrom:
                secretKeyRef:
                  name: ${ETCD_RGW_SECRET}
                  key: OS_REGION_NAME
            - name: OS_USERNAME
              valueFrom:
                secretKeyRef:
                  name: ${ETCD_RGW_SECRET}
                  key: OS_USERNAME
            - name: OS_PROJECT_NAME
              valueFrom:
                secretKeyRef:
                  name: ${ETCD_RGW_SECRET}
                  key: OS_PROJECT_NAME
            - name: OS_USER_DOMAIN_NAME
              valueFrom:
                secretKeyRef:
                  name: ${ETCD_RGW_SECRET}
                  key: OS_USER_DOMAIN_NAME
            - name: OS_PROJECT_DOMAIN_NAME
              valueFrom:
                secretKeyRef:
                  name: ${ETCD_RGW_SECRET}
                  key: OS_PROJECT_DOMAIN_NAME
            - name: OS_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: ${ETCD_RGW_SECRET}
                  key: OS_PASSWORD
EOF
fi

cat >> $TMP_FILE << EOF
          volumeMounts:
            - name: pod-tmp
              mountPath: /tmp
            - name: kubernetes-etcd-certs
              mountPath: /etc/etcd/tls/certs
            - name: kubernetes-etcd-keys
              mountPath: /etc/etcd/tls/keys
            - mountPath: /tmp/restore_etcd.sh
              name: kubernetes-etcd-bin
              readOnly: true
              subPath: restore_etcd.sh
            - mountPath: /tmp/restore_main.sh
              name: kubernetes-etcd-bin
              readOnly: true
              subPath: restore_main.sh
            - mountPath: /tmp/backup_etcd.sh
              name: kubernetes-etcd-bin
              readOnly: true
              subPath: backup_etcd.sh
            - mountPath: /tmp/bin/backup_main.sh
              name: kubernetes-etcd-bin
              readOnly: true
              subPath: backup_main.sh
            - mountPath: {{ .Values.conf.backup.host_backup_path }}
              name: kubernetes-etcd-backup-dir
              subPath: .
            - name: host-etcd
              mountPath: /var/lib/etcd
              subPath: .
      volumes:
        - name: pod-tmp
          emptyDir: {}
        - name: kubernetes-etcd-certs
          configMap:
            name: kubernetes-etcd-certs
            defaultMode: 0444
        - name: kubernetes-etcd-keys
          secret:
            secretName: kubernetes-etcd-keys
            defaultMode: 0444
        - name: kubernetes-etcd-bin
          configMap:
            name: kubernetes-etcd-bin
            defaultMode: 0555
        - name: kubernetes-etcd-backup-dir
          hostPath:
            path: {{ .Values.conf.backup.host_backup_path }}
        - name: host-etcd
          hostPath:
            path: /var/lib/etcd
EOF

kubectl create -n $ETCD_POD_NAMESPACE -f $TMP_FILE
rm -rf $TMP_FILE
