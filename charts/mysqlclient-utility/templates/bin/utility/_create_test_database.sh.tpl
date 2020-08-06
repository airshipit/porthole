#!/bin/bash

set -e +x

{{- $envAll := . }}
trap cleanup EXIT SIGTERM SIGINT

IFS=', ' read -re -a BACKUP_RESTORE_NAMESPACE_ARRAY <<< "$BACKUP_RESTORE_NAMESPACE_LIST"
ADMIN_USER_CNF=$(mktemp -p /tmp)
CERT_DIR=$(mktemp -d)
TLS_SECRET={{ $envAll.Values.conf.mariadb_backup_restore.secrets.tls_secret }}

function cleanup {
  rm -f "${ADMIN_USER_CNF}"
  rm -rf "${CERT_DIR}"
  echo 'Cleanup Finished.'
}

for NAMESPACE in "${BACKUP_RESTORE_NAMESPACE_ARRAY[@]}";
do
  kubectl -n "$NAMESPACE" get secret mariadb-secrets -o yaml \
          | grep admin_user.cnf | awk '{print $2}' | base64 -d > "${ADMIN_USER_CNF}"
  USER=$(grep user "$ADMIN_USER_CNF" | awk '{print $3}')
  PASSWD=$(grep password "$ADMIN_USER_CNF" | awk '{print $3}')
  PORT=$(grep port "$ADMIN_USER_CNF" | awk '{print $3}')

  if ! kubectl -n "$NAMESPACE" --no-headers=true get secret "$TLS_SECRET" > /dev/null 2>&1 ; then

    MYSQL="mysql \
      -u $USER -p${PASSWD} \
      --host=mariadb.$NAMESPACE.svc.cluster.local \
      --port=$PORT \
      --connect-timeout 10"

  else

    kubectl -n "$NAMESPACE" get secret "$TLS_SECRET" -o yaml \
          | grep " ca.crt: " | awk '{print $2}' | base64 -d > "$CERT_DIR"/ca.crt
    kubectl -n "$NAMESPACE" get secret "$TLS_SECRET" -o yaml \
          | grep " tls.crt: " | awk '{print $2}' | base64 -d > "$CERT_DIR"/tls.crt
    kubectl -n "$NAMESPACE" get secret "$TLS_SECRET" -o yaml \
          | grep " tls.key: " | awk '{print $2}' | base64 -d > "$CERT_DIR"/tls.key

    MYSQL="mysql \
      -u $USER -p${PASSWD} \
      --host=mariadb.$NAMESPACE.svc.cluster.local \
      --port=$PORT \
      --ssl-ca=$CERT_DIR/ca.crt \
      --ssl-key=$CERT_DIR/tls.key \
      --ssl-cert=$CERT_DIR/tls.crt \
      --connect-timeout 10"
  fi

  # Verify if test database exists already
  DB_ARGS="use ${TEST_DB_NAME}"
  if $MYSQL --execute="$DB_ARGS" > /dev/null 2>&1; then
    echo "Test database already exists in namespace $NAMESPACE."
  else

    # Create test database
    DB_ARGS="CREATE DATABASE ${TEST_DB_NAME};"
    $MYSQL --execute="$DB_ARGS"

    # Add a table to the test database
    DB_ARGS="USE ${TEST_DB_NAME};CREATE TABLE test_table1 \
      ( id int(11) NOT NULL AUTO_INCREMENT, name varchar(255) NOT NULL, user_id int(11) DEFAULT 0, PRIMARY KEY (id) );"
    $MYSQL --execute="$DB_ARGS"

    # Add a couple rows to the table of the test database
    DB_ARGS="USE ${TEST_DB_NAME};LOCK TABLES test_table1 WRITE \
      ;INSERT INTO test_table1 (name) value ('name') \
      ;UPDATE test_table1 SET user_id=id,name=CONCAT(name,user_id) WHERE id = LAST_INSERT_ID() \
      ;UNLOCK TABLES;"
    $MYSQL --execute="$DB_ARGS"
    $MYSQL --execute="$DB_ARGS"

    echo "Test database created in namespace $NAMESPACE."
  fi
done
