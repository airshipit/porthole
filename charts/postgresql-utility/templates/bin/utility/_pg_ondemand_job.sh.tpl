#!/bin/bash

{{- $envAll := . }}

export POSTGRESQL_POD_NAMESPACE=$1
if [[ $POSTGRESQL_POD_NAMESPACE == "" ]]; then
  echo "No namespace given - cannot spawn ondemand job."
  exit 1
fi

export POSTGRESQL_CONF_SECRET={{ $envAll.Values.conf.postgresql_backup_restore.secrets.conf_secret }}
export POSTGRESQL_IMAGE_NAME=$(kubectl get cronjob -n ucp postgresql-backup -o yaml -o jsonpath="{range .spec.jobTemplate.spec.template.spec.containers[*]}{.image}{'\n'}{end}" | grep postgresql-utility)
export POSTGRESQL_BACKUP_BASE_PATH=$(kubectl get secret -n ${POSTGRESQL_POD_NAMESPACE} ${POSTGRESQL_CONF_SECRET} -o json | jq -r .data.BACKUP_BASE_PATH | base64 -d)
POSTGRESQL_REMOTE_BACKUP_ENABLED=$(kubectl get secret -n ${POSTGRESQL_POD_NAMESPACE} ${POSTGRESQL_CONF_SECRET} -o json | jq -r .data.REMOTE_BACKUP_ENABLED | base64 -d)
export POSTGRESQL_REMOTE_BACKUP_ENABLED=$(echo $POSTGRESQL_REMOTE_BACKUP_ENABLED | sed 's/"//g')

if [[ $POSTGRESQL_IMAGE_NAME == "" ]]; then
  echo "Cannot find the utility image for populating POSTGRESQL_IMAGE_NAME variable."
  exit 1
fi

export TMP_FILE=$(mktemp -p /tmp)

cat > $TMP_FILE << EOF
---
apiVersion: batch/v1
kind: Job
metadata:
  name: postgresql-ondemand
  annotations:
    {{ tuple $envAll | include "helm-toolkit.snippets.release_uuid" }}
  labels:
{{ tuple $envAll "postgresql-ondemand" "ondemand" | include "helm-toolkit.snippets.kubernetes_metadata_labels" | indent 4 }}
spec:
  template:
    metadata:
      annotations:
        {{ tuple $envAll | include "helm-toolkit.snippets.release_uuid" }}
{{ dict "envAll" $envAll "podName" "postgresql-ondemand" "containerNames" (list  "backup-perms" "postgresql-ondemand") | include "helm-toolkit.snippets.kubernetes_mandatory_access_control_annotation" | indent 8 }}
      labels:
{{ tuple $envAll "postgresql-ondemand" "ondemand" | include "helm-toolkit.snippets.kubernetes_metadata_labels" | indent 8 }}
    spec:
{{ dict "envAll" $envAll "application" "postgresql_ondemand" | include "helm-toolkit.snippets.kubernetes_pod_security_context" | indent 6 }}
      restartPolicy: OnFailure
      nodeSelector:
        {{ .Values.labels.utility.node_selector_key }}: {{ .Values.labels.utility.node_selector_value }}
      initContainers:
        - name: backup-perms
          image: ${POSTGRESQL_IMAGE_NAME}
{{ tuple $envAll $envAll.Values.pod.resources.jobs.postgresql_ondemand | include "helm-toolkit.snippets.kubernetes_resources" | indent 10 }}
{{ dict "envAll" $envAll "application" "postgresql_ondemand" "container" "backup_perms" | include "helm-toolkit.snippets.kubernetes_container_security_context" | indent 10 }}
          command:
            - chown
            - -R
            - "65534:65534"
            - ${POSTGRESQL_BACKUP_BASE_PATH}
          env:
            - name: POSTGRESQL_BACKUP_BASE_DIR
              value: ${POSTGRESQL_BACKUP_BASE_PATH}
          volumeMounts:
            - mountPath: /tmp
              name: pod-tmp
            - mountPath: ${POSTGRESQL_BACKUP_BASE_PATH}
              name: postgresql-backup-dir
      containers:
        - name: postgresql-ondemand
          image: ${POSTGRESQL_IMAGE_NAME}
{{ tuple $envAll $envAll.Values.pod.resources.jobs.postgresql_ondemand | include "helm-toolkit.snippets.kubernetes_resources" | indent 10 }}
{{ dict "envAll" $envAll "application" "postgresql_ondemand" "container" "postgresql_ondemand" | include "helm-toolkit.snippets.kubernetes_container_security_context" | indent 10 }}
          command:
            - /bin/sleep
            - "{{ .Values.conf.postgresql_ondemand.ondemapd_pod_sleep_time }}"
          env:
            - name: POSTGRESQL_ADMIN_USER
              valueFrom:
                secretKeyRef:
                  key: POSTGRES_USER
                  name: postgresql-admin
            - name: POSTGRESQL_BACKUP_BASE_DIR
              valueFrom:
                secretKeyRef:
                  key: BACKUP_BASE_PATH
                  name: ${POSTGRESQL_CONF_SECRET}
            - name: POSTGRESQL_POD_NAMESPACE
              value: ${POSTGRESQL_POD_NAMESPACE}
            - name: REMOTE_BACKUP_ENABLED
              valueFrom:
                secretKeyRef:
                  key: REMOTE_BACKUP_ENABLED
                  name: ${POSTGRESQL_CONF_SECRET}
            - name: POSTGRESQL_LOCAL_BACKUP_DAYS_TO_KEEP
              valueFrom:
                secretKeyRef:
                  key: LOCAL_DAYS_TO_KEEP
                  name: ${POSTGRESQL_CONF_SECRET}
            - name: POSTGRESQL_REMOTE_BACKUP_DAYS_TO_KEEP
              valueFrom:
                secretKeyRef:
                  key: REMOTE_BACKUP_DAYS_TO_KEEP
                  name: ${POSTGRESQL_CONF_SECRET}
            - name: CONTAINER_NAME
              valueFrom:
                secretKeyRef:
                  key: REMOTE_BACKUP_CONTAINER
                  name: ${POSTGRESQL_CONF_SECRET}
            - name: POSTGRESQL_BACKUP_PG_DUMPALL_OPTIONS
              valueFrom:
                secretKeyRef:
                  key: PG_DUMPALL_OPTIONS
                  name: ${POSTGRESQL_CONF_SECRET}
            - name: STORAGE_POLICY
              valueFrom:
                secretKeyRef:
                  key: REMOTE_BACKUP_STORAGE_POLICY
                  name: ${POSTGRESQL_CONF_SECRET}
            - name: OS_IDENTITY_API_VERSION
              value: "3"
            - name: NUMBER_OF_RETRIES_SEND_BACKUP_TO_REMOTE
              valueFrom:
                secretKeyRef:
                  key: REMOTE_BACKUP_RETRIES
                  name: ${POSTGRESQL_CONF_SECRET}
            - name: MIN_DELAY_SEND_BACKUP_TO_REMOTE
              valueFrom:
                secretKeyRef:
                  key: REMOTE_BACKUP_SEND_DELAY_MIN
                  name: ${POSTGRESQL_CONF_SECRET}
            - name: MAX_DELAY_SEND_BACKUP_TO_REMOTE
              valueFrom:
                secretKeyRef:
                  key: REMOTE_BACKUP_SEND_DELAY_MAX
                  name: ${POSTGRESQL_CONF_SECRET}
            - name: THROTTLE_BACKUPS_ENABLED
              valueFrom:
                secretKeyRef:
                  key: THROTTLE_BACKUPS_ENABLED
                  name: ${POSTGRESQL_CONF_SECRET}
            - name: THROTTLE_LIMIT
              valueFrom:
                secretKeyRef:
                  key: THROTTLE_LIMIT
                  name: ${POSTGRESQL_CONF_SECRET}
            - name: THROTTLE_LOCK_EXPIRE_AFTER
              valueFrom:
                secretKeyRef:
                  key: THROTTLE_LOCK_EXPIRE_AFTER
                  name: ${POSTGRESQL_CONF_SECRET}
            - name: THROTTLE_RETRY_AFTER
              valueFrom:
                secretKeyRef:
                  key: THROTTLE_RETRY_AFTER
                  name: ${POSTGRESQL_CONF_SECRET}
            - name: THROTTLE_CONTAINER_NAME
              valueFrom:
                secretKeyRef:
                  key: THROTTLE_CONTAINER_NAME
                  name: ${POSTGRESQL_CONF_SECRET}
EOF

if $POSTGRESQL_REMOTE_BACKUP_ENABLED; then
  export POSTGRESQL_RGW_SECRET={{ $envAll.Values.conf.postgresql_backup_restore.secrets.rgw_secret }}
  cat >> $TMP_FILE << EOF
            - name: OS_AUTH_URL
              valueFrom:
                secretKeyRef:
                  name: ${POSTGRESQL_RGW_SECRET}
                  key: OS_AUTH_URL
            - name: OS_REGION_NAME
              valueFrom:
                secretKeyRef:
                  name: ${POSTGRESQL_RGW_SECRET}
                  key: OS_REGION_NAME
            - name: OS_USERNAME
              valueFrom:
                secretKeyRef:
                  name: ${POSTGRESQL_RGW_SECRET}
                  key: OS_USERNAME
            - name: OS_PROJECT_NAME
              valueFrom:
                secretKeyRef:
                  name: ${POSTGRESQL_RGW_SECRET}
                  key: OS_PROJECT_NAME
            - name: OS_USER_DOMAIN_NAME
              valueFrom:
                secretKeyRef:
                  name: ${POSTGRESQL_RGW_SECRET}
                  key: OS_USER_DOMAIN_NAME
            - name: OS_PROJECT_DOMAIN_NAME
              valueFrom:
                secretKeyRef:
                  name: ${POSTGRESQL_RGW_SECRET}
                  key: OS_PROJECT_DOMAIN_NAME
            - name: OS_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: ${POSTGRESQL_RGW_SECRET}
                  key: OS_PASSWORD
EOF
fi

cat >> $TMP_FILE << EOF
          volumeMounts:
            - name: pod-tmp
              mountPath: /tmp
            - mountPath: /tmp/restore_postgresql.sh
              name: postgresql-bin
              readOnly: true
              subPath: restore_postgresql.sh
            - mountPath: /tmp/restore_main.sh
              name: postgresql-bin
              readOnly: true
              subPath: restore_main.sh
            - mountPath: /tmp/backup_postgresql.sh
              name: postgresql-bin
              readOnly: true
              subPath: backup_postgresql.sh
            - mountPath: /tmp/backup_main.sh
              name: postgresql-bin
              readOnly: true
              subPath: backup_main.sh
            - mountPath: ${POSTGRESQL_BACKUP_BASE_PATH}
              name: postgresql-backup-dir
            - name: postgresql-secrets
              mountPath: /etc/postgresql/admin_user.conf
              subPath: admin_user.conf
              readOnly: true
{{- if .Values.pod.mounts.postgresql_ondemand.container.postgresql_ondemand.volumeMounts }}
{{ .Values.pod.mounts.postgresql_ondemand.container.postgresql_ondemand.volumeMounts | toYaml | indent 12 }}
{{- end }}
      restartPolicy: OnFailure
      volumes:
        - name: pod-tmp
          emptyDir: {}
        - name: postgresql-secrets
          secret:
            secretName: postgresql-secrets
            defaultMode: 292
        - name: postgresql-bin
          secret:
            secretName: postgresql-bin
            defaultMode: 365
        - name: postgresql-backup-dir
          persistentVolumeClaim:
            claimName: postgresql-backup-data
{{- if .Values.pod.mounts.postgresql_ondemand.container.postgresql_ondemand.volumes }}
{{ .Values.pod.mounts.postgresql_ondemand.container.postgresql_ondemand.volumes | toYaml | indent 8 }}
{{- end }}
EOF

kubectl create -n $POSTGRESQL_POD_NAMESPACE -f $TMP_FILE
rm -rf $TMP_FILE
