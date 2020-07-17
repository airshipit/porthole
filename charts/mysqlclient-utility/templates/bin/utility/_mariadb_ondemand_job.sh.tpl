#!/bin/bash

{{- $envAll := . }}

export MARIADB_POD_NAMESPACE=$1
if [[ $MARIADB_POD_NAMESPACE == "" ]]; then
  echo "No namespace given - cannot spawn ondemand job."
  exit 1
fi

export MARIADB_CONF_SECRET={{ $envAll.Values.conf.mariadb_backup_restore.secrets.conf_secret }}
export MARIADB_IMAGE_NAME=$(kubectl get cronjob -n ${MARIADB_POD_NAMESPACE} mariadb-backup -o yaml -o jsonpath="{range .spec.jobTemplate.spec.template.spec.containers[*]}{.image}{'\n'}{end}" | grep mysqlclient-utility)
export MARIADB_BACKUP_BASE_PATH=$(kubectl get secret -o yaml -n ${MARIADB_POD_NAMESPACE} ${MARIADB_CONF_SECRET} | grep BACKUP_BASE_PATH | awk '{print $2}' | base64 -d)
MARIADB_REMOTE_BACKUP_ENABLED=$(kubectl get secret -o yaml -n ${MARIADB_POD_NAMESPACE} ${MARIADB_CONF_SECRET} | grep REMOTE_BACKUP_ENABLED | awk '{print $2}' | base64 -d)
export MARIADB_REMOTE_BACKUP_ENABLED=$(echo $MARIADB_REMOTE_BACKUP_ENABLED | sed 's/"//g')

if [[ $MARIADB_IMAGE_NAME == "" ]]; then
  echo "Cannot find the utility image for populating MARIADB_IMAGE_NAME variable."
  exit 1
fi

export TMP_FILE=$(mktemp -p /tmp)

cat > $TMP_FILE << EOF
---
apiVersion: batch/v1
kind: Job
metadata:
  name: mariadb-ondemand
  annotations:
    {{ tuple $envAll | include "helm-toolkit.snippets.release_uuid" }}
  labels:
{{ tuple $envAll "mariadb-ondemand" "ondemand" | include "helm-toolkit.snippets.kubernetes_metadata_labels" | indent 4 }}
spec:
  template:
    metadata:
      labels:
{{ tuple $envAll "mariadb-ondemand" "ondemand" | include "helm-toolkit.snippets.kubernetes_metadata_labels" | indent 8 }}
    spec:
{{ dict "envAll" $envAll "application" "mariadb_ondemand" | include "helm-toolkit.snippets.kubernetes_pod_security_context" | indent 6 }}
      restartPolicy: OnFailure
      nodeSelector:
        {{ .Values.labels.utility.node_selector_key }}: {{ .Values.labels.utility.node_selector_value }}
      initContainers:
        - name: ondemand-perms
          image: ${MARIADB_IMAGE_NAME}
{{ tuple $envAll $envAll.Values.pod.resources.jobs.mariadb_ondemand | include "helm-toolkit.snippets.kubernetes_resources" | indent 10 }}
{{ dict "envAll" $envAll "application" "mariadb_ondemand" "container" "ondemand_perms" | include "helm-toolkit.snippets.kubernetes_container_security_context" | indent 10 }}
          command:
            - chown
            - -R
            - "65534:65534"
            - ${MARIADB_BACKUP_BASE_PATH}
          volumeMounts:
            - mountPath: /tmp
              name: pod-tmp
            - mountPath: ${MARIADB_BACKUP_BASE_PATH}
              name: mariadb-backup-dir
      containers:
        - name: mariadb-ondemand
          image: ${MARIADB_IMAGE_NAME}
{{ tuple $envAll $envAll.Values.pod.resources.jobs.mariadb_ondemand | include "helm-toolkit.snippets.kubernetes_resources" | indent 10 }}
{{ dict "envAll" $envAll "application" "mariadb_ondemand" "container" "mariadb_ondemand" | include "helm-toolkit.snippets.kubernetes_container_security_context" | indent 10 }}
          command:
            - /bin/sleep
            - "1000000"
          env:
            - name: MARIADB_BACKUP_BASE_DIR
              valueFrom:
                secretKeyRef:
                  key: BACKUP_BASE_PATH
                  name: ${MARIADB_CONF_SECRET}
            - name: MARIADB_LOCAL_BACKUP_DAYS_TO_KEEP
              valueFrom:
                secretKeyRef:
                  key: LOCAL_DAYS_TO_KEEP
                  name: ${MARIADB_CONF_SECRET}
            - name: REMOTE_BACKUP_ENABLED
              valueFrom:
                secretKeyRef:
                  key: REMOTE_BACKUP_ENABLED
                  name: ${MARIADB_CONF_SECRET}
            - name: MARIADB_REMOTE_BACKUP_DAYS_TO_KEEP
              valueFrom:
                secretKeyRef:
                  key: REMOTE_BACKUP_DAYS_TO_KEEP
                  name: ${MARIADB_CONF_SECRET}
            - name: MARIADB_POD_NAMESPACE
              value: ${MARIADB_POD_NAMESPACE}
            - name: MYSQL_BACKUP_MYSQLDUMP_OPTIONS
              valueFrom:
                secretKeyRef:
                  key: MYSQLDUMP_OPTIONS
                  name: ${MARIADB_CONF_SECRET}
            - name: STORAGE_POLICY
              valueFrom:
                secretKeyRef:
                  key: REMOTE_BACKUP_STORAGE_POLICY
                  name: ${MARIADB_CONF_SECRET}
            - name: CONTAINER_NAME
              valueFrom:
                secretKeyRef:
                  key: REMOTE_BACKUP_CONTAINER
                  name: ${MARIADB_CONF_SECRET}
            - name: OS_IDENTITY_API_VERSION
              value: "3"
EOF

if $MARIADB_REMOTE_BACKUP_ENABLED; then
  export MARIADB_RGW_SECRET={{ $envAll.Values.conf.mariadb_backup_restore.secrets.rgw_secret }}
  cat >> $TMP_FILE << EOF
            - name: OS_AUTH_URL
              valueFrom:
                secretKeyRef:
                  name: ${MARIADB_RGW_SECRET}
                  key: OS_AUTH_URL
            - name: OS_REGION_NAME
              valueFrom:
                secretKeyRef:
                  name: ${MARIADB_RGW_SECRET}
                  key: OS_REGION_NAME
            - name: OS_USERNAME
              valueFrom:
                secretKeyRef:
                  name: ${MARIADB_RGW_SECRET}
                  key: OS_USERNAME
            - name: OS_PROJECT_NAME
              valueFrom:
                secretKeyRef:
                  name: ${MARIADB_RGW_SECRET}
                  key: OS_PROJECT_NAME
            - name: OS_USER_DOMAIN_NAME
              valueFrom:
                secretKeyRef:
                  name: ${MARIADB_RGW_SECRET}
                  key: OS_USER_DOMAIN_NAME
            - name: OS_PROJECT_DOMAIN_NAME
              valueFrom:
                secretKeyRef:
                  name: ${MARIADB_RGW_SECRET}
                  key: OS_PROJECT_DOMAIN_NAME
            - name: OS_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: ${MARIADB_RGW_SECRET}
                  key: OS_PASSWORD
EOF
fi

cat >> $TMP_FILE << EOF
          volumeMounts:
            - name: pod-tmp
              mountPath: /tmp
            - mountPath: /tmp/restore_mariadb.sh
              name: mariadb-bin
              readOnly: true
              subPath: restore_mariadb.sh
            - mountPath: /tmp/restore_main.sh
              name: mariadb-bin
              readOnly: true
              subPath: restore_main.sh
            - mountPath: /tmp/backup_mariadb.sh
              name: mariadb-bin
              readOnly: true
              subPath: backup_mariadb.sh
            - mountPath: /tmp/backup_main.sh
              name: mariadb-bin
              readOnly: true
              subPath: backup_main.sh
            - mountPath: ${MARIADB_BACKUP_BASE_PATH}
              name: mariadb-backup-dir
            - name: mariadb-secrets
              mountPath: /etc/mysql/admin_user.cnf
              subPath: admin_user.cnf
              readOnly: true
      volumes:
        - name: pod-tmp
          emptyDir: {}
        - name: mariadb-secrets
          secret:
            secretName: mariadb-secrets
            defaultMode: 292
        - name: mariadb-bin
          configMap:
            name: mariadb-bin
            defaultMode: 365
        - name: mariadb-backup-dir
          persistentVolumeClaim:
            claimName: mariadb-backup-data
EOF

kubectl create -n $MARIADB_POD_NAMESPACE -f $TMP_FILE
rm -rf $TMP_FILE
