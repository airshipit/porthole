#!/bin/bash

set -e +x

IFS=', ' read -re -a BACKUP_RESTORE_NAMESPACE_ARRAY <<< "$BACKUP_RESTORE_NAMESPACE_LIST"
TEST_DB_USER="${TEST_DB_NAME}_user"
TEST_TABLE="test_table1"

function database_cmd() {
  NAMESPACE=$1

  POSTGRES_PWD=$(kubectl get secret -n "$NAMESPACE" postgresql-admin -o json | jq -r .data.POSTGRES_PASSWORD | base64 -d)
  POSTGRES_CREDS="postgresql://postgres:${POSTGRES_PWD}@postgresql.${NAMESPACE}.svc.cluster.local?sslmode=disable"
  SQL_CMD="psql $POSTGRES_CREDS"

  echo $SQL_CMD
}

for NAMESPACE in "${BACKUP_RESTORE_NAMESPACE_ARRAY[@]}";
do
  PSQL=$(database_cmd $NAMESPACE)

  # Verify if test database exists already
  DB_CMD="\connect ${TEST_DB_NAME}"
  if $PSQL -tc "$DB_CMD" > /dev/null 2>&1; then
    echo "Test database already exists in namespace $NAMESPACE."
    echo "Dropping the database, then will re-create it."
    $PSQL -tc "DROP DATABASE ${TEST_DB_NAME};"
  fi

  # Create test database
  DB_CMD="CREATE DATABASE ${TEST_DB_NAME};"
  $PSQL -tc "$DB_CMD"

  # Add a table to the test database
  $PSQL << EOF
    \connect ${TEST_DB_NAME};
    CREATE TABLE ${TEST_TABLE}
      ( name character varying (255), age integer NOT NULL );
EOF

  # Add a couple rows to the table of the test database
  $PSQL << EOF
    \connect ${TEST_DB_NAME};
    INSERT INTO ${TEST_TABLE} VALUES ( 'name0', '0' );
    INSERT INTO ${TEST_TABLE} VALUES ( 'name1', '1' );
EOF

  # Create a test user if it has not been created before.
  if ${PSQL} -tc "SELECT rolname FROM pg_roles WHERE rolname='${TEST_DB_USER}';" | grep ${TEST_DB_USER}; then
    echo "Test user already exists in namespace ${NAMESPACE}"
  else
    ${PSQL} -tc "CREATE ROLE ${TEST_DB_USER};"
    echo "Test user created in namespace ${NAMESPACE}."
  fi

  # Note, if the GRANT is already there, the following command will not fail,
  # so no need to check existence first.
  ${PSQL} -tc "GRANT ALL PRIVILEGES ON DATABASE ${TEST_DB_NAME} TO ${TEST_DB_USER};"
  echo "Test user is granted permissions to the test database in namespace ${NAMESPACE}."
done
