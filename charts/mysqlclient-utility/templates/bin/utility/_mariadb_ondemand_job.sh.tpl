#!/bin/bash

{{- $envAll := . }}

export MARIADB_POD_NAMESPACE=$1
if [[ $MARIADB_POD_NAMESPACE == "" ]]; then
  echo "No namespace given - cannot spawn ondemand job."
  exit 1
fi

export MARIADB_CONF_SECRET={{ $envAll.Values.conf.mariadb_backup_restore.secrets.conf_secret }}
export MYSQLCLIENT_UTILTIY_IMAGE_NAME=$(kubectl get cronjob -n ${MARIADB_POD_NAMESPACE} mariadb-backup -o yaml -o jsonpath="{range .spec.jobTemplate.spec.template.spec.containers[*]}{.image}{'\n'}{end}" | grep mysqlclient-utility)
export MARIADB_BACKUP_BASE_PATH=$(kubectl get secret -n ${MARIADB_POD_NAMESPACE} ${MARIADB_CONF_SECRET} -o json | jq -r .data.BACKUP_BASE_PATH | base64 -d)
MARIADB_REMOTE_BACKUP_ENABLED=$(kubectl get secret -n ${MARIADB_POD_NAMESPACE} ${MARIADB_CONF_SECRET} -o json | jq -r .data.REMOTE_BACKUP_ENABLED | base64 -d)
export MARIADB_REMOTE_BACKUP_ENABLED=$(echo $MARIADB_REMOTE_BACKUP_ENABLED | sed 's/"//g')

if [[ $MYSQLCLIENT_UTILTIY_IMAGE_NAME == "" ]]; then
  echo "Cannot find the utility image for populating MYSQLCLIENT_UTILTIY_IMAGE_NAME variable."
  exit 1
fi

export TMP_FILE=$(mktemp -p /tmp)

if ! kubectl -n ${MARIADB_POD_NAMESPACE} --no-headers=true get secret {{ $envAll.Values.conf.mariadb_backup_restore.secrets.tls_secret }} > /dev/null 2>&1 ; then
  echo "TLS is not enabled in ${MARIADB_POD_NAMESPACE} namespace"
  export TLS_ENABLED="false"
else
  echo "TLS is enabled in ${MARIADB_POD_NAMESPACE} namespace"
  export TLS_ENABLED="true"
fi

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
      annotations:
        {{ tuple $envAll | include "helm-toolkit.snippets.release_uuid" }}
{{ dict "envAll" $envAll "podName" "mariadb-ondemand" "containerNames" (list "ondemand-perms" "mariadb-ondemand" ) | include "helm-toolkit.snippets.kubernetes_mandatory_access_control_annotation" | indent 8 }}
      labels:
{{ tuple $envAll "mariadb-ondemand" "ondemand" | include "helm-toolkit.snippets.kubernetes_metadata_labels" | indent 8 }}
    spec:
{{ dict "envAll" $envAll "application" "mariadb_ondemand" | include "helm-toolkit.snippets.kubernetes_pod_security_context" | indent 6 }}
      restartPolicy: OnFailure
      nodeSelector:
        {{ .Values.labels.utility.node_selector_key }}: {{ .Values.labels.utility.node_selector_value }}
      initContainers:
        - name: ondemand-perms
          image: ${MYSQLCLIENT_UTILTIY_IMAGE_NAME}
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
        - name: verify-perms
          image: ${MYSQLCLIENT_UTILTIY_IMAGE_NAME}
{{ tuple $envAll $envAll.Values.pod.resources.jobs.mariadb_ondemand | include "helm-toolkit.snippets.kubernetes_resources" | indent 10 }}
{{ dict "envAll" $envAll "application" "mariadb_ondemand" "container" "verify_perms" | include "helm-toolkit.snippets.kubernetes_container_security_context" | indent 10 }}
          command:
            - chown
            - -R
            - "65534:65534"
            - /var/lib/mysql
          volumeMounts:
            - mountPath: /tmp
              name: pod-tmp
            - mountPath: /var/lib/mysql
              name: mysql-data
      containers:
        - name: mariadb-ondemand
          image: ${MYSQLCLIENT_UTILTIY_IMAGE_NAME}
{{ tuple $envAll $envAll.Values.pod.resources.jobs.mariadb_ondemand | include "helm-toolkit.snippets.kubernetes_resources" | indent 10 }}
{{ dict "envAll" $envAll "application" "mariadb_ondemand" "container" "mariadb_ondemand" | include "helm-toolkit.snippets.kubernetes_container_security_context" | indent 10 }}
          command:
            - /bin/sh
          args:
            - -c
            - ( /tmp/start_verification_server.sh ) & /bin/sleep {{ .Values.conf.mariadb_ondemand.ondemapd_pod_sleep_time }}
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
            - name: NUMBER_OF_RETRIES_SEND_BACKUP_TO_REMOTE
              valueFrom:
                secretKeyRef:
                  key: REMOTE_BACKUP_RETRIES
                  name: ${MARIADB_CONF_SECRET}
            - name: MIN_DELAY_SEND_BACKUP_TO_REMOTE
              valueFrom:
                secretKeyRef:
                  key: REMOTE_BACKUP_SEND_DELAY_MIN
                  name: ${MARIADB_CONF_SECRET}
            - name: MAX_DELAY_SEND_BACKUP_TO_REMOTE
              valueFrom:
                secretKeyRef:
                  key: REMOTE_BACKUP_SEND_DELAY_MAX
                  name: ${MARIADB_CONF_SECRET}
            - name: THROTTLE_BACKUPS_ENABLED
              valueFrom:
                secretKeyRef:
                  key: THROTTLE_BACKUPS_ENABLED
                  name: ${MARIADB_CONF_SECRET}
            - name: THROTTLE_LIMIT
              valueFrom:
                secretKeyRef:
                  key: THROTTLE_LIMIT
                  name: ${MARIADB_CONF_SECRET}
            - name: THROTTLE_LOCK_EXPIRE_AFTER
              valueFrom:
                secretKeyRef:
                  key: THROTTLE_LOCK_EXPIRE_AFTER
                  name: ${MARIADB_CONF_SECRET}
            - name: THROTTLE_RETRY_AFTER
              valueFrom:
                secretKeyRef:
                  key: THROTTLE_RETRY_AFTER
                  name: ${MARIADB_CONF_SECRET}
            - name: THROTTLE_CONTAINER_NAME
              valueFrom:
                secretKeyRef:
                  key: THROTTLE_CONTAINER_NAME
                  name: ${MARIADB_CONF_SECRET}
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

if $TLS_ENABLED; then
  export TLS_SECRET={{ $envAll.Values.conf.mariadb_backup_restore.secrets.tls_secret }}
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
            - name: mariadb-tls-secret
              mountPath: /etc/mysql/certs/tls.crt
              subPath: tls.crt
              readOnly: true
            - name: mariadb-tls-secret
              mountPath: /etc/mysql/certs/tls.key
              subPath: tls.key
              readOnly: true
            - name: mariadb-tls-secret
              mountPath: /etc/mysql/certs/ca.crt
              subPath: ca.crt
              readOnly: true
            - name: mysql-data
              mountPath: /var/lib/mysql
            - name: mariadb-bin
              mountPath: /tmp/start_verification_server.sh
              subPath: start_verification_server.sh
              readOnly: true
            - name: var-run
              mountPath: /run/mysqld
{{- if .Values.pod.mounts.mariadb_ondemand.container.mariadb_ondemand.volumeMounts }}
{{ .Values.pod.mounts.mariadb_ondemand.container.mariadb_ondemand.volumeMounts | toYaml | indent 12 }}
{{- end }}
      volumes:
        - name: pod-tmp
          emptyDir: {}
        - name: mycnfd
          emptyDir: {}
        - name: var-run
          emptyDir: {}
        - name: mariadb-etc
          configMap:
            name: mariadb-etc
            defaultMode: 0444
        - name: mysql-data
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
        - name: mariadb-tls-secret
          secret:
            secretName: ${TLS_SECRET}
            defaultMode: 292
{{- if .Values.pod.mounts.mariadb_ondemand.container.mariadb_ondemand.volumes }}
{{ .Values.pod.mounts.mariadb_ondemand.container.mariadb_ondemand.volumes | toYaml | indent 8 }}
{{- end }}
EOF
else
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
            - name: mysql-data
              mountPath: /var/lib/mysql
            - name: mariadb-bin
              mountPath: /tmp/start_verification_server.sh
              subPath: start_verification_server.sh
              readOnly: true
            - name: var-run
              mountPath: /run/mysqld
{{- if .Values.pod.mounts.mariadb_ondemand.container.mariadb_ondemand.volumeMounts }}
{{ .Values.pod.mounts.mariadb_ondemand.container.mariadb_ondemand.volumeMounts | toYaml | indent 12 }}
{{- end }}
      volumes:
        - name: pod-tmp
          emptyDir: {}
        - name: mycnfd
          emptyDir: {}
        - name: var-run
          emptyDir: {}
        - name: mariadb-etc
          configMap:
            name: mariadb-etc
            defaultMode: 0444
        - name: mysql-data
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
{{- if .Values.pod.mounts.mariadb_ondemand.container.mariadb_ondemand.volumes }}
{{ .Values.pod.mounts.mariadb_ondemand.container.mariadb_ondemand.volumes | toYaml | indent 8 }}
{{- end }}
EOF
fi

kubectl create -n $MARIADB_POD_NAMESPACE -f $TMP_FILE
rm -rf $TMP_FILE
