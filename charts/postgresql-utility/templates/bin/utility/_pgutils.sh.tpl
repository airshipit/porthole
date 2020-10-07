#!/bin/bash

TEST_DB_USER="${TEST_DB_NAME}_user"

function database_cmd() {
  NAMESPACE=$1

  get_postgres_password() {
    PW=$(kubectl get secret -n "$NAMESPACE" postgresql-admin -o json  | jq -r .data.POSTGRES_PASSWORD | base64 -d)
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

# Params: <namespace> <tablename>
#   Column names and types will be hardcoded for now
#   NOTE: Database is always a pre-provisioned database
function create_table() {

  CREATE_ARGS=("$@")

  NAMESPACE=${CREATE_ARGS[1]}
  DATABASE=${TEST_DB_NAME}
  TABLENAME=${CREATE_ARGS[2]}

  CREATE_CMD="CREATE TABLE ${TABLENAME} ( name character varying (255), age integer NOT NULL )"

  DB_CMD=$(database_cmd $NAMESPACE)

  $DB_CMD << EOF
    \connect ${DATABASE};
    ${CREATE_CMD};
EOF
}

# Params: <namespace> <table>
#   The row values are hardcoded for now.
#   NOTE: Database is always a pre-provisioned database
function create_row() {

  CREATE_ARGS=("$@")

  NAMESPACE=${CREATE_ARGS[1]}
  DATABASE=${TEST_DB_NAME}
  TABLENAME=${CREATE_ARGS[2]}

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

# Params: <namespace>
# Create the grants for test user in the test database.
#   NOTE: Database is always a pre-provisioned database
#   NOTE: In order for this function to work, create_test_database in
#         values.yaml file needs to be set to true to create a test database
#         at bootstrap time. Otherwise this function cannot properly create
#         the user's grants.
function create_user_grants() {

  CREATE_GRANTS_ARGS=("$@")
  NAMESPACE=${CREATE_GRANTS_ARGS[1]}

  DB_CMD=$(database_cmd ${NAMESPACE})

  # If the test user and grants do not exist already,
  # give the test user privilege to access the test database
  if ${DB_CMD} -tc "SELECT rolname FROM pg_roles WHERE rolname='${TEST_DB_USER}';" | grep ${TEST_DB_USER}; then
    ${DB_CMD} -tc "GRANT ALL PRIVILEGES ON DATABASE ${TEST_DB_NAME} TO ${TEST_DB_USER};"
  else
    echo "Test user does not exist in namespace ${NAMESPACE}"
  fi
}

# Params: <namespace>
# Query for the test user in the test database and query the privileges
# of this user in the test database.
# Returns a string indicating whether or not the query was successful.
#   NOTE: Database is always a pre-provisioned database
#   NOTE: In order for this function to work, create_test_database in
#         values.yaml file needs to be set to true to create a test user
#         at bootstrap time (or through the use of create_user above).
function query_user() {

  QUERY_ARGS=("$@")
  NAMESPACE=${QUERY_ARGS[1]}

  DB_CMD=$(database_cmd ${NAMESPACE})

  # Sub-command to retrieve the test user
  DB_ARGS="\du ${TEST_DB_USER}"

  # Execute the command to query for the test user
  # Result should look like this: (assuming TEST_DB_NAME = test)
  #                   List of roles
  #          Role name        |  Attributes  | Member of
  #  -------------------------+--------------+-----------
  #          test_user        | Cannot login | {}
  USERS=$(${DB_CMD} -tc ${DB_ARGS} | grep ${TEST_DB_USER} | wc -l)
  if [[ ${USERS} -ne 1 ]]; then
    # There should only be one user
    echo "${TEST_DB_USER} does not exist"
    return
  fi

  # Sub-command to retrieve the grants for the test database
  DB_ARGS="\l+ ${TEST_DB_NAME}"

  # Execute the command to query the grants for the test user.
  # Result should look like this: (assuming TEST_DB_NAME = test)
  #                                                                List of databases
  #         Name        |  Owner   | Encoding |  Collate   |   Ctype    |          Access privileges           |  Size   | Tablespace | Description
  # --------------------+----------+----------+------------+------------+--------------------------------------+---------+------------+-------------
  #         test        | postgres | UTF8     | en_US.utf8 | en_US.utf8 | =Tc/postgres                        +| 7087 kB | pg_default |
  #                     |          |          |            |            | postgres=CTc/postgres               +|         |            |
  #                     |          |          |            |            | test_user=CTc/postgres               |         |            |
  GRANTS=$(${DB_CMD} -tc ${DB_ARGS} | grep "${TEST_DB_USER}=CTc" | wc -l)
  if [[ ${GRANTS} -ne 1 ]]; then
    # There should only be 1 GRANT statement for this user
    echo "${TEST_DB_USER} does not have the correct grants"
    return
  fi

  echo "${TEST_DB_USER} exists and has the correct grants."
}

# Params: <namespace>
# Delete the test user's grants in the test database.
#   NOTE: In order for this function to work, create_test_database in
#         values.yaml file needs to be set to true to create a test user
#         at bootstrap time. If there is no user, this will fail.
function delete_user_grants() {

  DELETE_GRANTS_ARGS=("$@")
  NAMESPACE=${DELETE_GRANTS_ARGS[1]}

  DB_CMD=$(database_cmd ${NAMESPACE})

  # Execute the commands to delete the grants.
  if $DB_CMD -tc "SELECT rolname FROM pg_roles WHERE rolname='${TEST_DB_USER}';" | grep ${TEST_DB_USER}; then
    ${DB_CMD} -tc "REVOKE ALL PRIVILEGES ON DATABASE ${TEST_DB_NAME} FROM ${TEST_DB_USER};"
  else
    echo "Test user does not exist in namespace ${NAMESPACE}"
  fi
}

# Params: <namespace> <table> <colname> <value>
#   Where: <colname> = <value> is the condition used to find the row to be deleted.
#   NOTE: Database is always a pre-provisioned database
function delete_row() {

  DELETE_ARGS=("$@")

  NAMESPACE=${DELETE_ARGS[1]}
  DATABASE=${TEST_DB_NAME}
  TABLENAME=${DELETE_ARGS[2]}
  COLNAME=${DELETE_ARGS[3]}
  VALUE=${DELETE_ARGS[4]}

  DELETE_CMD="DELETE FROM ${TABLENAME} WHERE ${COLNAME} = '${VALUE}'"

  DB_CMD=$(database_cmd $NAMESPACE)

  ${DB_CMD} << EOF
    \connect ${DATABASE};
    ${DELETE_CMD};
EOF
}

# Params: <namespace> <tablename>
#   NOTE: Database is always a pre-provisioned database
function delete_table() {

  DELETE_ARGS=("$@")

  NAMESPACE=${DELETE_ARGS[1]}
  DATABASE=${TEST_DB_NAME}
  TABLENAME=${DELETE_ARGS[2]}

  DB_CMD=$(database_cmd $NAMESPACE)

  ${DB_CMD} << EOF
    \connect ${DATABASE};
    DROP TABLE IF EXISTS ${TABLENAME};
EOF
}

# Params: <namespace> <ondemand_pod>
# Delete the backup objects made from the test database, both locally and
# remotely.
function delete_backups() {

  DELETE_ARGS=("$@")
  NAMESPACE=${DELETE_ARGS[1]}
  ONDEMAND_POD=${DELETE_ARGS[2]}

  LOCAL_LIST=$(kubectl exec -i -n "${NAMESPACE}" "${ONDEMAND_POD}" -- /tmp/restore_postgresql.sh list_archives | grep ${TEST_DB_NAME})
  if [[ $? -ne 0 ]]; then
    echo "Could not retrieve the list of local test archives or no local test archives exist."
    # Don't return at this point - best effort to delete all we can
  else
    for ARCHIVE in ${LOCAL_LIST}; do
      kubectl exec -i -n "${NAMESPACE}" "${ONDEMAND_POD}" -- /tmp/restore_postgresql.sh delete_archive ${ARCHIVE}
      if [[ $? -ne 0 ]]; then
        echo "Could not delete local test archive ${ARCHIVE}"
      else
        echo "Deleted local test archive ${ARCHIVE}"
      fi
    done
  fi

  REMOTE_LIST=$(kubectl exec -i -n "${NAMESPACE}" "${ONDEMAND_POD}" -- /tmp/restore_postgresql.sh list_archives remote | grep ${TEST_DB_NAME})
  if [[ $? -ne 0 ]]; then
    echo "Could not retrieve the list of remote test archives or no remote test archives exist."
  else
    for ARCHIVE in ${REMOTE_LIST}; do
      kubectl exec -i -n "${NAMESPACE}" "${ONDEMAND_POD}" -- /tmp/restore_postgresql.sh delete_archive ${ARCHIVE} remote
      if [[ $? -ne 0 ]]; then
        echo "Could not delete remote test archive ${ARCHIVE}"
      else
        echo "Deleted remote test archive ${ARCHIVE}"
      fi
    done
  fi
}


