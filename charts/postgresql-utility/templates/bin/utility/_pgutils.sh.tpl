#!/bin/bash

function database_cmd() {
  NAMESPACE=$1

  get_postgres_password() {
    PW=$(kubectl get secret -n "$NAMESPACE" postgresql-admin -o yaml  | grep POSTGRES_PASSWORD | awk '{print $2}' | base64 -d)
    echo "$PW"
  }
  POSTGRES_PWD=$(get_postgres_password)
  POSTGRES_CREDS="postgresql://postgres:${POSTGRES_PWD}@postgresql.${NAMESPACE}.svc.cluster.local?sslmode=disable"
  SQL_CMD="psql $POSTGRES_CREDS"

  echo $SQL_CMD
}

# Params: <namespace>
function show_databases() {

  SHOW_ARGS=("$@")

  NAMESPACE=${SHOW_ARGS[1]}

  DB_CMD=$(database_cmd $NAMESPACE)

  ${DB_CMD} -c "\l"
}

# Params: <namespace> <database>
function show_tables() {

  SHOW_ARGS=("$@")

  NAMESPACE=${SHOW_ARGS[1]}
  DATABASE=${SHOW_ARGS[2]}

  DB_CMD=$(database_cmd $NAMESPACE)

  ${DB_CMD} << EOF
    \connect ${DATABASE};
    \dt
EOF
}

# Params: <namespace> <database> <table>
function show_rows() {

  SHOW_ARGS=("$@")

  NAMESPACE=${SHOW_ARGS[1]}
  DATABASE=${SHOW_ARGS[2]}
  TABLE=${SHOW_ARGS[3]}

  DB_CMD=$(database_cmd $NAMESPACE)

  ${DB_CMD} << EOF
    \connect ${DATABASE};
    SELECT * FROM ${TABLE};
EOF
}

# Params: <namespace> <database> <table>
function show_schema() {

  SHOW_ARGS=("$@")

  NAMESPACE=${SHOW_ARGS[1]}
  DATABASE=${SHOW_ARGS[2]}
  TABLE=${SHOW_ARGS[3]}

  DB_CMD=$(database_cmd $NAMESPACE)

  ${DB_CMD} << EOF
    \connect ${DATABASE};
    \d ${TABLE};
EOF
}

# Params: <namespace>
function sql_prompt() {

  SHOW_ARGS=("$@")

  NAMESPACE=${SHOW_ARGS[1]}

  DB_CMD=$(database_cmd $NAMESPACE)

  ${DB_CMD}
}


# Params: <namespace> <database>
#   NOTE: "test_" is automatically prepended before the provided database
#         name, in order to prevent accidental modification/deletion of
#         an application database.
function create_database() {

  CREATE_ARGS=("$@")

  NAMESPACE=${CREATE_ARGS[1]}
  DATABASE="test_"
  DATABASE+=${CREATE_ARGS[2]}
  DB_CMD=$(database_cmd $NAMESPACE)

  ${DB_CMD} -c "CREATE DATABASE ${DATABASE};"
}

# Params: <namespace> <database> <tablename>
#   Column names and types will be hardcoded for now
#   NOTE: "test_" is automatically prepended before the provided database
#         name, in order to prevent accidental modification of
#         an application database.
function create_table() {

  CREATE_ARGS=("$@")

  NAMESPACE=${CREATE_ARGS[1]}
  DATABASE="test_"
  DATABASE+=${CREATE_ARGS[2]}
  TABLENAME=${CREATE_ARGS[3]}

  CREATE_CMD="CREATE TABLE ${TABLENAME} ( name character varying (255), age integer NOT NULL )"

  DB_CMD=$(database_cmd $NAMESPACE)

  $DB_CMD << EOF
    \connect ${DATABASE};
    ${CREATE_CMD};
EOF
}

# Params: <namespace> <database> <table>
#   The row values are hardcoded for now.
#   NOTE: "test_" is automatically prepended before the provided database
#         name, in order to prevent accidental modification of
#         an application database.
function create_row() {

  CREATE_ARGS=("$@")

  NAMESPACE=${CREATE_ARGS[1]}
  DATABASE="test_"
  DATABASE+=${CREATE_ARGS[2]}
  TABLENAME=${CREATE_ARGS[3]}

  DB_CMD=$(database_cmd $NAMESPACE)

  NUMROWS=$(echo '\c '"${DATABASE};"' \\ SELECT count(*) from '"${TABLENAME};" | ${DB_CMD} | sed -n '4p' | awk '{print $1}')
  NAME="name${NUMROWS}"
  AGE="${NUMROWS}"
  INSERT_CMD="INSERT INTO ${TABLENAME} VALUES ( '${NAME}', '${AGE}' )"

  $DB_CMD << EOF
    \connect ${DATABASE};
    ${INSERT_CMD};
EOF
}

# Params: <namespace> <database> <table> <colname> <value>
#   Where: <colname> = <value> is the condition used to find the row to be deleted.
#   NOTE: "test_" is automatically prepended before the provided database
#         name, in order to prevent accidental modification/deletion of
#         an application database.
function delete_row() {

  DELETE_ARGS=("$@")

  NAMESPACE=${DELETE_ARGS[1]}
  DATABASE="test_"
  DATABASE+=${DELETE_ARGS[2]}
  TABLENAME=${DELETE_ARGS[3]}
  COLNAME=${DELETE_ARGS[4]}
  VALUE=${DELETE_ARGS[5]}

  DELETE_CMD="DELETE FROM ${TABLENAME} WHERE ${COLNAME} = '${VALUE}'"

  DB_CMD=$(database_cmd $NAMESPACE)

  ${DB_CMD} << EOF
    \connect ${DATABASE};
    ${DELETE_CMD};
EOF
}

# Params: <namespace> <database> <tablename>
#   NOTE: "test_" is automatically prepended before the provided database
#         name, in order to prevent accidental modification/deletion of
#         an application database.
function delete_table() {

  DELETE_ARGS=("$@")

  NAMESPACE=${DELETE_ARGS[1]}
  DATABASE="test_"
  DATABASE+=${DELETE_ARGS[2]}
  TABLENAME=${DELETE_ARGS[3]}

  DB_CMD=$(database_cmd $NAMESPACE)

  ${DB_CMD} << EOF
    \connect ${DATABASE};
    DROP TABLE IF EXISTS ${TABLENAME};
EOF
}

# Params: <namespace> <database>
#   NOTE: "test_" is automatically prepended before the provided database
#         name, in order to prevent accidental modification/deletion of
#         an application database.
function delete_database() {

  DELETE_ARGS=("$@")

  NAMESPACE=${DELETE_ARGS[1]}
  DATABASE="test_"
  DATABASE+=${DELETE_ARGS[2]}

  DB_CMD=$(database_cmd $NAMESPACE)

  ${DB_CMD} -c "DROP DATABASE IF EXISTS ${DATABASE};"
}
