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
  kubectl exec -it -n "${SHOW_ARGS[1]}" "${SHOW_ARGS[2]}" -- ${MYSQL_CMD} --execute="$DB_ARGS"
}

# Params: <namespace> <database> <pod_name>
function show_tables() {

  SHOW_ARGS=("$@")

  MYSQL_CMD=$(database_cmd)
  DB_ARGS="USE ${SHOW_ARGS[2]};SHOW TABLES;"

  # Execute the command in the on-demand pod
  kubectl exec -it -n "${SHOW_ARGS[1]}" "${SHOW_ARGS[3]}" -- ${MYSQL_CMD} --execute="$DB_ARGS"
}

# Params: <namespace> <database> <table> <pod_name>
function show_rows() {

  SHOW_ARGS=("$@")

  MYSQL_CMD=$(database_cmd)
  DB_ARGS="USE ${SHOW_ARGS[2]};SELECT * FROM ${SHOW_ARGS[3]};"

  # Execute the command in the on-demand pod
  kubectl exec -it -n "${SHOW_ARGS[1]}" "${SHOW_ARGS[4]}" -- ${MYSQL_CMD} --execute="$DB_ARGS"
}

# Params: <namespace> <database> <table> <pod_name>
function show_schema() {

  SHOW_ARGS=("$@")

  MYSQL_CMD=$(database_cmd)
  DB_ARGS="USE ${SHOW_ARGS[2]};DESC ${SHOW_ARGS[3]};"

  # Execute the command in the on-demand pod
  kubectl exec -it -n "${SHOW_ARGS[1]}" "${SHOW_ARGS[4]}" -- ${MYSQL_CMD} --execute="$DB_ARGS"
}

# Params: <namespace> <pod_name>
function sql_prompt() {

  SHOW_ARGS=("$@")

  MYSQL_CMD=$(database_cmd)

  # Execute the command in the on-demand pod
  kubectl exec -it -n "${SHOW_ARGS[1]}" "${SHOW_ARGS[2]}" -- ${MYSQL_CMD}
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
  kubectl exec -it -n "${CREATE_ARGS[1]}" "${CREATE_ARGS[3]}" -- ${MYSQL_CMD} --execute="$DB_ARGS"
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
  kubectl exec -it -n "${CREATE_ARGS[1]}" "${CREATE_ARGS[3]}" -- ${MYSQL_CMD} --execute="$DB_ARGS"
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
  kubectl exec -it -n "${DELETE_ARGS[1]}" "${DELETE_ARGS[5]}" -- ${MYSQL_CMD} --execute="$DB_ARGS"
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
  kubectl exec -it -n "${DELETE_ARGS[1]}" "${DELETE_ARGS[3]}" -- ${MYSQL_CMD} --execute="$DB_ARGS"
}
