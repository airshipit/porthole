#!/bin/bash

function database_cmd() {
  echo "mysql --defaults-file=/etc/mysql/admin_user.cnf --connect-timeout 10"
}

# Params: <namespace> <pod_name>
function show_databases() {

  SHOW_ARGS=("$@")

  MYSQL_CMD=$(database_cmd)
  DB_ARGS="SHOW DATABASES;"

  # Execute the command in the on-demand pod
  kubectl exec -it -n "${SHOW_ARGS[1]}" "${SHOW_ARGS[2]}" -c mariadb-ondemand -- ${MYSQL_CMD} --execute="$DB_ARGS"
}

# Params: <namespace> <database> <pod_name>
function show_tables() {

  SHOW_ARGS=("$@")

  MYSQL_CMD=$(database_cmd)
  DB_ARGS="USE ${SHOW_ARGS[2]};SHOW TABLES;"

  # Execute the command in the on-demand pod
  kubectl exec -it -n "${SHOW_ARGS[1]}" "${SHOW_ARGS[3]}" -c mariadb-ondemand -- ${MYSQL_CMD} --execute="$DB_ARGS"
}

# Params: <namespace> <database> <table> <pod_name>
function show_rows() {

  SHOW_ARGS=("$@")

  MYSQL_CMD=$(database_cmd)
  DB_ARGS="USE ${SHOW_ARGS[2]};SELECT * FROM ${SHOW_ARGS[3]};"

  # Execute the command in the on-demand pod
  kubectl exec -it -n "${SHOW_ARGS[1]}" "${SHOW_ARGS[4]}" -c mariadb-ondemand -- ${MYSQL_CMD} --execute="$DB_ARGS"
}

# Params: <namespace> <database> <table> <pod_name>
function show_schema() {

  SHOW_ARGS=("$@")

  MYSQL_CMD=$(database_cmd)
  DB_ARGS="USE ${SHOW_ARGS[2]};DESC ${SHOW_ARGS[3]};"

  # Execute the command in the on-demand pod
  kubectl exec -it -n "${SHOW_ARGS[1]}" "${SHOW_ARGS[4]}" -c mariadb-ondemand -- ${MYSQL_CMD} --execute="$DB_ARGS"
}

# Params: <namespace> <pod_name>
function sql_prompt() {

  SHOW_ARGS=("$@")

  MYSQL_CMD=$(database_cmd)

  # Execute the command in the on-demand pod
  kubectl exec -it -n "${SHOW_ARGS[1]}" "${SHOW_ARGS[2]}" -c mariadb-ondemand -- ${MYSQL_CMD}
}

# Params: <namespace> <table> <pod_name>
# Create a table in an existing test database.
#   NOTE: In order for this function to work, create_test_database in
#         values.yaml file needs to be set to true to create a test database
#         at bootstrap time.
function create_table() {

  CREATE_ARGS=("$@")

  MYSQL_CMD=$(database_cmd)
  DB_ARGS="USE $TEST_DB_NAME;CREATE TABLE ${CREATE_ARGS[2]} \
    ( id int(11) NOT NULL AUTO_INCREMENT, name varchar(255) NOT NULL, user_id int(11) DEFAULT 0, PRIMARY KEY (id) );"

  # Execute the command in the on-demand pod
  kubectl exec -it -n "${CREATE_ARGS[1]}" "${CREATE_ARGS[3]}" -c mariadb-ondemand -- ${MYSQL_CMD} --execute="$DB_ARGS"
}

# Params: <namespace> <table> <pod_name>
#   NOTE: In order for this function to work, create_test_database in
#         values.yaml file needs to be set to true to create a test database
#         at bootstrap time.
function create_row() {

  CREATE_ARGS=("$@")

  MYSQL_CMD=$(database_cmd)
  DB_ARGS="USE $TEST_DB_NAME;LOCK TABLES ${CREATE_ARGS[2]} WRITE \
    ;INSERT INTO ${CREATE_ARGS[2]} (name) value ('name') \
    ;UPDATE ${CREATE_ARGS[2]} SET user_id=id,name=CONCAT(name,user_id) WHERE id = LAST_INSERT_ID() \
    ;UNLOCK TABLES;"

  # Execute the command in the on-demand pod
  kubectl exec -it -n "${CREATE_ARGS[1]}" "${CREATE_ARGS[3]}" -c mariadb-ondemand -- ${MYSQL_CMD} --execute="$DB_ARGS"
}

# Params: <namespace> <pod_name>
# Create the grants for test user to access the test database.
#   NOTE: In order for this function to work, create_test_database in
#         values.yaml file needs to be set to true to create a test database
#         at bootstrap time. Otherwise this function cannot properly create
#         the user privileges.
function create_user_grants() {

  CREATE_GRANTS_ARGS=("$@")

  if [[ -n ${TEST_DB_USER} ]]; then
    MYSQL_CMD=$(database_cmd)
    DB_CMD="SELECT user FROM mysql.user WHERE user='${TEST_DB_USER}';"
    USERS=$(kubectl exec -it -n "${CREATE_GRANTS_ARGS[1]}" "${CREATE_GRANTS_ARGS[2]}" -c mariadb-ondemand -- ${MYSQL_CMD} --execute="${DB_CMD}" 2>/dev/null | grep ${TEST_DB_USER} | wc -l)
    if [[ ${USERS} -eq 1 ]]; then
      DB_CMD="GRANT ALL PRIVILEGES ON ${TEST_DB_NAME}.* TO '${TEST_DB_USER}'@'%'; \
              FLUSH PRIVILEGES;"

      # Execute the command in the on-demand pod
      kubectl exec -it -n "${CREATE_GRANTS_ARGS[1]}" "${CREATE_GRANTS_ARGS[2]}" -c mariadb-ondemand -- ${MYSQL_CMD} --execute="${DB_CMD}"
    else
      echo "Test user does not exist in namespace ${NAMESPACE}."
    fi
  else
    echo "Test user was not deployed in namespace ${NAMESPACE}"
  fi
}

# Params: <namespace> <pod_name>
# Query for the test user in the test database.
# Returns a string indicating whether or not the query was successful.
#   NOTE: In order for this function to work, create_test_database in
#         values.yaml file needs to be set to true to create a test user
#         at bootstrap time (or through the use of create_user above).
function query_user() {

  QUERY_ARGS=("$@")

  if [[ -n ${TEST_DB_USER} ]]; then
    MYSQL_CMD=$(database_cmd)

    # Retrieve the test user
    DB_CMD="SELECT user FROM mysql.user WHERE user='${TEST_DB_USER}';"

    # Execute the command in the on-demand pod
    # Result should look like this: (assuming TEST_DB_NAME = test)
    #    +----------------+
    #    | user           |
    #    +----------------+
    #    | test_user      |
    #    +----------------+
    #    1 row in set (0.00 sec)
    USERS=$(kubectl exec -it -n "${QUERY_ARGS[1]}" "${QUERY_ARGS[2]}" -c mariadb-ondemand -- ${MYSQL_CMD} --execute="${DB_CMD}" | grep ${TEST_DB_USER} | wc -l)
    if [[ ${USERS} -ne 1 ]]; then
      # There should only be one user
      echo "${TEST_DB_USER} does not exist"
      return
    fi

    # Retrieve the grants for this test user in the test database
    DB_CMD="SHOW GRANTS FOR '${TEST_DB_USER}'@'%';"

    # Execute the command in the on-demand pod
    # Result should look like this: (assuming TEST_DB_NAME = test)
    #    +---------------------------------------------------------------------------------------------------------------+
    #    | Grants for test_user@%                                                                                        |
    #    +---------------------------------------------------------------------------------------------------------------+
    #    | GRANT USAGE ON *.* TO 'test_user'@'%' IDENTIFIED BY PASSWORD '<redacted>';                                    |
    #    | GRANT ALL PRIVILEGES ON `test`.* TO 'test_user'@'%'                                                           |
    #    +---------------------------------------------------------------------------------------------------------------+
    #    2 rows in set (0.00 sec)
    GRANTS=$(kubectl exec -it -n "${QUERY_ARGS[1]}" "${QUERY_ARGS[2]}" -c mariadb-ondemand -- ${MYSQL_CMD} --execute="${DB_CMD}" | grep "GRANT.*${TEST_DB_USER}" | wc -l)
    if [[ ${GRANTS} -ne 2 ]]; then
      # There should only be 2 GRANT statements for this user
      echo "${TEST_DB_USER} does not have the correct grants"
      return
    fi

    echo "${TEST_DB_USER} exists and has the correct grants."
  else
    echo "Test user was not deployed in namespace ${NAMESPACE}"
  fi
}

# Params: <namespace> <pod_name>
# Delete the test user's grants in the test database.
#   NOTE: In order for this function to work, create_test_database in
#         values.yaml file needs to be set to true to create a test user
#         at bootstrap time. If there is no user, this will fail.
function delete_user_grants() {

  DELETE_GRANTS_ARGS=("$@")

  if [[ -n ${TEST_DB_USER} ]]; then
    MYSQL_CMD=$(database_cmd)
    DB_CMD="SELECT user FROM mysql.user WHERE user='${TEST_DB_USER}';"
    USERS=$(kubectl exec -it -n "${DELETE_GRANTS_ARGS[1]}" "${DELETE_GRANTS_ARGS[2]}" -c mariadb-ondemand -- ${MYSQL_CMD} --execute="${DB_CMD}" 2>/dev/null | grep ${TEST_DB_USER} | wc -l)
    if [[ ${USERS} -eq 1 ]]; then
      DB_CMD="REVOKE ALL PRIVILEGES ON ${TEST_DB_NAME}.* FROM '${TEST_DB_USER}'@'%'; \
              FLUSH PRIVILEGES;"

      # Execute the command in the on-demand pod
      kubectl exec -it -n "${DELETE_GRANTS_ARGS[1]}" "${DELETE_GRANTS_ARGS[2]}" -c mariadb-ondemand -- ${MYSQL_CMD} --execute="${DB_CMD}"
    else
      echo "Test user does not exist in namespace ${NAMESPACE}."
    fi
  else
    echo "Test user was not deployed in namespace ${NAMESPACE}"
  fi
}

# Params: <namespace> <table> <colname> <value> <pod_name>
#   Where: <colname> = <value> is the condition used to find the row to be deleted.
#   NOTE: In order for this function to work, create_test_database in
#         values.yaml file needs to be set to true to create a test database
#         at bootstrap time.
function delete_row() {

  DELETE_ARGS=("$@")

  MYSQL_CMD=$(database_cmd)
  DB_ARGS="USE $TEST_DB_NAME;DELETE FROM ${DELETE_ARGS[2]} WHERE ${DELETE_ARGS[3]} = '${DELETE_ARGS[4]}';"

  # Execute the command in the on-demand pod
  kubectl exec -it -n "${DELETE_ARGS[1]}" "${DELETE_ARGS[5]}" -c mariadb-ondemand -- ${MYSQL_CMD} --execute="$DB_ARGS"
}

# Params: <namespace> <tablename> <pod_name>
#   NOTE: In order for this function to work, create_test_database in
#         values.yaml file needs to be set to true to create a test database
#         at bootstrap time.
function delete_table() {

  DELETE_ARGS=("$@")

  MYSQL_CMD=$(database_cmd)
  DB_ARGS="USE $TEST_DB_NAME;DROP TABLE IF EXISTS ${DELETE_ARGS[2]};"

  # Execute the command in the on-demand pod
  kubectl exec -it -n "${DELETE_ARGS[1]}" "${DELETE_ARGS[3]}" -c mariadb-ondemand -- ${MYSQL_CMD} --execute="$DB_ARGS"
}

# Params: <namespace> <ondemand_pod>
# Delete the backup objects made from the test database, both locally and
# remotely.
function delete_backups() {

  DELETE_ARGS=("$@")
  NAMESPACE=${DELETE_ARGS[1]}
  ONDEMAND_POD=${DELETE_ARGS[2]}

  LOCAL_LIST=$(kubectl exec -i -n "${NAMESPACE}" "${ONDEMAND_POD}" -c mariadb-ondemand -- /tmp/restore_mariadb.sh list_archives | grep ${TEST_DB_NAME})
  if [[ $? -ne 0 ]]; then
    echo "Could not retrieve the list of local test archives."
    # Don't return at this point - best effort to delete all we can
  else
    for ARCHIVE in ${LOCAL_LIST}; do
      kubectl exec -i -n "${NAMESPACE}" "${ONDEMAND_POD}" -c mariadb-ondemand -- /tmp/restore_mariadb.sh delete_archive ${ARCHIVE}
      if [[ $? -ne 0 ]]; then
        echo "Could not delete local test archive ${ARCHIVE}"
      else
        echo "Deleted local test archive ${ARCHIVE}"
      fi
    done
  fi

  REMOTE_LIST=$(kubectl exec -i -n "${NAMESPACE}" "${ONDEMAND_POD}" -c mariadb-ondemand -- /tmp/restore_mariadb.sh list_archives remote | grep ${TEST_DB_NAME})
  if [[ $? -ne 0 ]]; then
    echo "Could not retrieve the list of remote test archives."
  else
    for ARCHIVE in ${REMOTE_LIST}; do
      kubectl exec -i -n "${NAMESPACE}" "${ONDEMAND_POD}" -c mariadb-ondemand -- /tmp/restore_mariadb.sh delete_archive ${ARCHIVE} remote
      if [[ $? -ne 0 ]]; then
        echo "Could not delete remote test archive ${ARCHIVE}"
      else
        echo "Deleted remote test archive ${ARCHIVE}"
      fi
    done
  fi
}

