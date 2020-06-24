#!/bin/bash

# This file contains database utility scripts which a user can execute
# to perform database specific tasks such as backup, restore, and showing
# tables.
#
# The user can execute this script by calling:
#   dbutils
#
#     No arguments required. However the script will require the
#     following variables to be exported:
#
#       export BACKUP_RESTORE_NAMESPACE_LIST  A comma deliminated list of the namespaces the databases can be found in the respective utility yaml

trap do_trap SIGINT SIGTERM

ARGS=("$@")

function setup() {

  source /tmp/mysqlutils.sh
  if [[ $? -ne 0 ]]; then
    echo "ERROR: source /tmp/mysqlutils.sh failed. Cannot continue. Exiting..."
    exit 1
  fi

  if [[ -z "$BACKUP_RESTORE_NAMESPACE_LIST" ]]; then
    echo "ERROR: Namespaces are not defined. Exiting..."
    exit 1
  fi

  export ONDEMAND_JOB="mariadb-ondemand"

  IFS=', ' read -re -a NAMESPACE_ARRAY <<< "$BACKUP_RESTORE_NAMESPACE_LIST"
}

function check_args() {

  # There should always be 3 parameters
  if [[ -z "$3" ]]; then
    echo "ERROR: Incorrect number of parameters provided (requires three). Exiting..."
    exit 1
  fi

  ARGS=$1[@]
  ARGS_ARRAY=("${!ARGS}")
  ARGS_MIN=$2+1
  ARGS_MAX=$3+1
  ARGS_COUNT="${#ARGS_ARRAY[@]}"

  # Confirm that there is a correct number of arguments passed to the command.
  if [[ $ARGS_COUNT -lt $ARGS_MIN ]]; then
    echo "ERROR: not enough arguments"
    help
    return 1
  elif [[ $ARGS_COUNT -gt $ARGS_MAX ]]; then
    echo "ERROR: too many arguments"
    help
    return 1
  fi

  # Check if the first parameter is the remote flag.
  if [[ "${ARGS_ARRAY[1]}" == "-r" ]]; then
    export LOC_STRING="remote RGW"
    export LOCATION="remote"
    NAMESPACE_POS=2
  else
    export LOC_STRING="local"
    export LOCATION=""
    NAMESPACE_POS=1
  fi

  setup_namespace "${ARGS_ARRAY[$NAMESPACE_POS]}"
  if [[ "$?" -ne 0 ]]; then
    return 1
  fi

  return 0
}

# Ensure that the ondemand pod is running
function ensure_ondemand_pod_exists() {
  POD_LISTING=$(kubectl get pod -n "$NAMESPACE" | grep "$ONDEMAND_JOB")
  if [[ ! -z "$POD_LISTING" ]]; then
    STATUS=$(echo "$POD_LISTING" | awk '{print $3}')
    CONTAINERS=$(echo "$POD_LISTING" | awk '{print $2}')
    # There should only ever be one ondemand pod existing at any time, so if
    #    we find any which are not ready remove them, even if completed.
    if [[ $STATUS != "Running" || $CONTAINERS != "1/1" ]]; then
      echo "Found an old on-demand pod; removing it."
      remove_job "$NAMESPACE" "$ONDEMAND_JOB"
      if [[ $? -ne 0 ]]; then
        echo "ERROR: Failed to remove old on-demand pod. Exiting..."
        exit 1
      fi
    else
      # Pod is already running and ready
      ONDEMAND_POD=$(kubectl get pod -n "$NAMESPACE" | grep "$ONDEMAND_JOB" | awk '{print $1}')
    fi
  fi

  # If we reached this point with no ONDEMAND_POD, then we need to create
  #   a new on-demand job.
  if [[ -z "$ONDEMAND_POD" ]]; then
    echo "Creating new on-demand job in the $NAMESPACE namespace..."
    /tmp/mariadb-ondemand-job.sh "$NAMESPACE"
    if [[ $? -ne 0 ]]; then
      echo "ERROR: Failed to execute: /tmp/mariadb-ondemand-job.sh $NAMESPACE. Exiting..."
      exit 1
    fi

    ONDEMAND_POD=$(kubectl get pod -n "$NAMESPACE" | grep "$ONDEMAND_JOB" | awk '{print $1}')
    kubectl wait --for condition=ready --timeout=300s -n "$NAMESPACE" "pod/${ONDEMAND_POD}"
    if [[ $? -ne 0 ]]; then
      echo "ERROR: Failed to create a new on-demand pod. Exiting..."
      exit 1
    fi
  fi

  export ONDEMAND_POD
}

# Params: ArrayToSearch StringToSearchFor
function in_array() {

  ARGS=$1[@]
  ARGS_ARRAY=("${!ARGS}")

  local i
  for i in "${ARGS_ARRAY[@]}"; do [[ "$i" == "$2" ]] && return 0; done

  return 1
}

# Setup the NAMESPACE env, confirm that the entered NAMESPACE is valid
function setup_namespace() {

  if [[ -z "$1" ]]; then
    if [[ "${#NAMESPACE_ARRAY[@]}" -gt 1 ]]; then
      echo "ERROR: Namespace is required since there are multiple namespaces: ${NAMESPACE_ARRAY[*]}"
      return 1
    else
      export NAMESPACE="${NAMESPACE_ARRAY[0]}"
    fi
  else
    if [[ "${#NAMESPACE_ARRAY[@]}" -gt 1 ]]; then
      in_array NAMESPACE_ARRAY "$1"
      if [[ "$?" -eq 0 ]]; then
        export NAMESPACE="$1"
        unset ONDEMAND_POD
      else
        echo "ERROR: Namespace $1 is not valid"
        return 1
      fi
    else
      export NAMESPACE="${NAMESPACE_ARRAY[0]}"
    fi
  fi

  if [[ ! "$USED_NAMESPACES" =~ $NAMESPACE ]]; then
    export USED_NAMESPACES="$USED_NAMESPACES $NAMESPACE"
  fi

  return 0
}

# Params: <namespace> <job>
function remove_job() {

  NAMESPACE=$1
  JOB=$2

  # Cleanup the last attempted job if there is one, wait for the pod to be deleted.
  kubectl get job -n "$NAMESPACE" "$JOB"
  if [[ $? -eq 0 ]]; then
    echo "Removing on-demand job $NAMESPACE $JOB"
    ONDEMAND_POD=$(kubectl get pod -n "$NAMESPACE" | grep "$JOB" | awk '{print $1}')
    kubectl delete job --ignore-not-found -n "$NAMESPACE" "$JOB"
    kubectl wait --for=delete --timeout=300s -n "$NAMESPACE" pod/"${ONDEMAND_POD}" &>/dev/null
    if [[ $? -ne 0 ]]; then
      echo "ERROR: could not destroy the $NAMESPACE $JOB job. Exiting..."
      exit 1
    fi
  fi
}

# Params: <namespace>
function do_backup() {

  BACKUP_ARGS=("$@")

  check_args BACKUP_ARGS 1 1
  if [[ $? -ne 0 ]]; then
    return 1
  fi

  # Be sure that an ondemand pod is ready (start if not started)
  ensure_ondemand_pod_exists

  # Execute the command in the on-demand pod
  kubectl exec -i -n "$NAMESPACE" "$ONDEMAND_POD" -- /tmp/backup_mariadb.sh
}

# Params: [-r] <namespace>
function do_list_archives() {

  LIST_ARGS=("$@")

  check_args LIST_ARGS 1 2
  if [[ $? -ne 0 ]]; then
    return 1
  fi

  # Be sure that an ondemand pod is ready (start if not started)
  ensure_ondemand_pod_exists

  # Execute the command in the on-demand pod
  kubectl exec -i -n "$NAMESPACE" "$ONDEMAND_POD" -- /tmp/restore_mariadb.sh list_archives "$LOCATION"
}

# Params: [-r] <archive>
function do_list_databases() {

  # Determine which argument is the ARCHIVE in order to detect the NAMESPACE
  LIST_ARGS=("$@")
  if [[ "${LIST_ARGS[1]}" =~ .tar.gz ]]; then
    ARCHIVE="${LIST_ARGS[1]}"
    ARCHIVE_POS=1
  elif [[ "${LIST_ARGS[2]}" =~ .tar.gz ]]; then
    ARCHIVE="${LIST_ARGS[2]}"
    ARCHIVE_POS=2
  else
    echo "ERROR: Archive file not found in 1st or 2nd argument position."
    return 1
  fi

  NAMESPACE="$(echo "$ARCHIVE" | awk -F '.' '{print $2}')"
  LIST_ARGS=("${LIST_ARGS[@]:0:$ARCHIVE_POS}" "$NAMESPACE" "${LIST_ARGS[@]:$ARCHIVE_POS}")

  # NAMESPACE is pulled from the ARCHIVE name, and is inserted into LIST_ARGS increases max arguments by 1
  check_args LIST_ARGS 1 3
  if [[ $? -ne 0 ]]; then
    return 1
  fi

  # Be sure that an ondemand pod is ready (start if not started)
  ensure_ondemand_pod_exists

  # Execute the command in the on-demand pod
  kubectl exec -i -n "$NAMESPACE" "$ONDEMAND_POD" -- /tmp/restore_mariadb.sh list_databases "$ARCHIVE" "$LOCATION"
}

# Params: [-r] <archive> <database>
function do_list_tables() {

  # Determine which argument is the ARCHIVE in order to detect the NAMESPACE
  LIST_ARGS=("$@")
  if [[ "${LIST_ARGS[1]}" =~ .tar.gz ]]; then
    ARCHIVE="${LIST_ARGS[1]}"
    ARCHIVE_POS=1
  elif [[ "${LIST_ARGS[2]}" =~ .tar.gz ]]; then
    ARCHIVE="${LIST_ARGS[2]}"
    ARCHIVE_POS=2
  else
    echo "ERROR: Archive file not found in 1st or 2nd argument position."
    return 1
  fi

  NAMESPACE="$(echo "$ARCHIVE" | awk -F '.' '{print $2}')"
  LIST_ARGS=("${LIST_ARGS[@]:0:$ARCHIVE_POS}" "$NAMESPACE" "${LIST_ARGS[@]:$ARCHIVE_POS}")

  # NAMESPACE is pulled from the ARCHIVE name, and is inserted into LIST_ARGS increases max arguments by 1
  check_args LIST_ARGS 2 4
  if [[ $? -ne 0 ]]; then
    return 1
  fi

  DATABASE=${LIST_ARGS[$ARCHIVE_POS+2]}

  # Be sure that an ondemand pod is ready (start if not started)
  ensure_ondemand_pod_exists

  # Execute the command in the on-demand pod
  kubectl exec -i -n "$NAMESPACE" "$ONDEMAND_POD" -- /tmp/restore_mariadb.sh list_tables "$ARCHIVE" "$DATABASE" "$LOCATION"
}

# Params: [-r] <archive> <database> <table>
function do_list_rows() {

  # Determine which argument is the ARCHIVE in order to detect the NAMESPACE
  LIST_ARGS=("$@")
  if [[ "${LIST_ARGS[1]}" =~ .tar.gz ]]; then
    ARCHIVE="${LIST_ARGS[1]}"
    ARCHIVE_POS=1
  elif [[ "${LIST_ARGS[2]}" =~ .tar.gz ]]; then
    ARCHIVE="${LIST_ARGS[2]}"
    ARCHIVE_POS=2
  else
    echo "ERROR: Archive file not found in 1st or 2nd argument position."
    return 1
  fi

  NAMESPACE="$(echo "$ARCHIVE" | awk -F '.' '{print $2}')"
  LIST_ARGS=("${LIST_ARGS[@]:0:$ARCHIVE_POS}" "$NAMESPACE" "${LIST_ARGS[@]:$ARCHIVE_POS}")

  check_args LIST_ARGS 3 5
  if [[ $? -ne 0 ]]; then
    return 1
  fi

  DATABASE=${LIST_ARGS[$ARCHIVE_POS+2]}
  TABLE=${LIST_ARGS[$ARCHIVE_POS+3]}

  # Be sure that an ondemand pod is ready (start if not started)
  ensure_ondemand_pod_exists

  # Execute the command in the on-demand pod
  kubectl exec -i -n "$NAMESPACE" "$ONDEMAND_POD" -- /tmp/restore_mariadb.sh list_rows "$ARCHIVE" "$DATABASE" "$TABLE" "$LOCATION"
}

# Params: [-r] <archive> <database> <table>
function do_list_schema() {

  # Determine which argument is the ARCHIVE in order to detect the NAMESPACE
  LIST_ARGS=("$@")
  if [[ "${LIST_ARGS[1]}" =~ .tar.gz ]]; then
    ARCHIVE="${LIST_ARGS[1]}"
    ARCHIVE_POS=1
  elif [[ "${LIST_ARGS[2]}" =~ .tar.gz ]]; then
    ARCHIVE="${LIST_ARGS[2]}"
    ARCHIVE_POS=2
  else
    echo "ERROR: Archive file not found in 1st or 2nd argument position."
    return 1
  fi

  NAMESPACE="$(echo "$ARCHIVE" | awk -F '.' '{print $2}')"
  LIST_ARGS=("${LIST_ARGS[@]:0:$ARCHIVE_POS}" "$NAMESPACE" "${LIST_ARGS[@]:$ARCHIVE_POS}")

  check_args LIST_ARGS 3 5
  if [[ $? -ne 0 ]]; then
    return 1
  fi

  DATABASE=${LIST_ARGS[$ARCHIVE_POS+2]}
  TABLE=${LIST_ARGS[$ARCHIVE_POS+3]}

  # Be sure that an ondemand pod is ready (start if not started)
  ensure_ondemand_pod_exists

  # Execute the command in the on-demand pod
  kubectl exec -i -n "$NAMESPACE" "$ONDEMAND_POD" -- /tmp/restore_mariadb.sh list_schema "$ARCHIVE" "$DATABASE" "$TABLE" "$LOCATION"
}

# Params: <namespace>
function do_show_databases() {

  SHOW_ARGS=("$@")

  check_args SHOW_ARGS 1 1
  if [[ $? -ne 0 ]]; then
    return 1
  fi

  # Be sure that an ondemand pod is ready (start if not started)
  ensure_ondemand_pod_exists
  SHOW_ARGS[2]=$ONDEMAND_POD

  show_databases "${SHOW_ARGS[@]}"
  if [[ $? -ne 0 ]]; then
    return 1
  fi
}

# Params: <namespace> <database>
function do_show_tables() {

  SHOW_ARGS=("$@")

  check_args SHOW_ARGS 2 2
  if [[ $? -ne 0 ]]; then
    return 1
  fi

  # Be sure that an ondemand pod is ready (start if not started)
  ensure_ondemand_pod_exists
  SHOW_ARGS[3]=$ONDEMAND_POD

  show_tables "${SHOW_ARGS[@]}"
  if [[ $? -ne 0 ]]; then
    return 1
  fi
}

# Params: <namespace> <database> <table>
function do_show_rows() {

  SHOW_ARGS=("$@")

  check_args SHOW_ARGS 3 3
  if [[ $? -ne 0 ]]; then
    return 1
  fi

  # Be sure that an ondemand pod is ready (start if not started)
  ensure_ondemand_pod_exists
  SHOW_ARGS[4]=$ONDEMAND_POD

  show_rows "${SHOW_ARGS[@]}"
  if [[ $? -ne 0 ]]; then
    return 1
  fi
}

# Params: <namespace> <database> <table>
function do_show_schema() {

  SHOW_ARGS=("$@")

  check_args SHOW_ARGS 3 3
  if [[ $? -ne 0 ]]; then
    return 1
  fi

  # Be sure that an ondemand pod is ready (start if not started)
  ensure_ondemand_pod_exists
  SHOW_ARGS[4]=$ONDEMAND_POD

  show_schema "${SHOW_ARGS[@]}"
  if [[ $? -ne 0 ]]; then
    return 1
  fi
}

# Params: <namespace> <tablename>
#   Column names and types will be hardcoded for now
#   NOTE: In order for this function to work, create_test_database in
#         values.yaml file needs to be set to true to create a test database
#         at bootrap time.
function do_create_table() {

  CREATE_ARGS=("$@")

  check_args CREATE_ARGS 2 2
  if [[ $? -ne 0 ]]; then
    return 1
  fi

  # Be sure that an ondemand pod is ready (start if not started)
  ensure_ondemand_pod_exists
  CREATE_ARGS[3]=$ONDEMAND_POD

  create_table "${CREATE_ARGS[@]}"
  if [[ $? -ne 0 ]]; then
    return 1
  fi
}

# Params: <namespace> <table>
#   The row values are hardcoded for now.
#   NOTE: In order for this function to work, create_test_database in
#         values.yaml file needs to be set to true to create a test database
#         at bootrap time.
function do_create_row() {

  CREATE_ARGS=("$@")

  check_args CREATE_ARGS 2 2
  if [[ $? -ne 0 ]]; then
    return 1
  fi

  # Be sure that an ondemand pod is ready (start if not started)
  ensure_ondemand_pod_exists
  CREATE_ARGS[3]=$ONDEMAND_POD

  create_row "${CREATE_ARGS[@]}"
  if [[ $? -ne 0 ]]; then
    return 1
  fi
}

# Params: <namespace> <table> <colname> <value>
#   Where: <colname> = <value> is the condition used to find the row to be deleted.
#   NOTE: In order for this function to work, create_test_database in
#         values.yaml file needs to be set to true to create a test database
#         at bootrap time.
function do_delete_row() {

  DELETE_ARGS=("$@")

  check_args DELETE_ARGS 4 4
  if [[ $? -ne 0 ]]; then
    return 1
  fi

  # Be sure that an ondemand pod is ready (start if not started)
  ensure_ondemand_pod_exists
  DELETE_ARGS[5]=$ONDEMAND_POD

  delete_row "${DELETE_ARGS[@]}"
  if [[ $? -ne 0 ]]; then
    return 1
  fi
}

# Params: <namespace> <tablename>
#   NOTE: In order for this function to work, create_test_database in
#         values.yaml file needs to be set to true to create a test database
#         at bootrap time.
function do_delete_table() {

  DELETE_ARGS=("$@")

  check_args DELETE_ARGS 2 2
  if [[ $? -ne 0 ]]; then
    return 1
  fi

  # Be sure that an ondemand pod is ready (start if not started)
  ensure_ondemand_pod_exists
  DELETE_ARGS[3]=$ONDEMAND_POD

  delete_table "${DELETE_ARGS[@]}"
  if [[ $? -ne 0 ]]; then
    return 1
  fi
}

# Params: [-r] <archive> <db_name>
function do_restore() {

  # Determine which argument is the ARCHIVE in order to detect the NAMESPACE
  RESTORE_ARGS=("$@")
  if [[ "${RESTORE_ARGS[1]}" =~ .tar.gz ]]; then
    ARCHIVE="${RESTORE_ARGS[1]}"
    ARCHIVE_POS=1
  elif [[ "${RESTORE_ARGS[2]}" =~ .tar.gz ]]; then
    ARCHIVE="${RESTORE_ARGS[2]}"
    ARCHIVE_POS=2
  else
    echo "ERROR: Archive file not found in 1st or 2nd argument position."
    return 1
  fi

  NAMESPACE="$(echo "$ARCHIVE" | awk -F '.' '{print $2}')"
  RESTORE_ARGS=("${RESTORE_ARGS[@]:0:$ARCHIVE_POS}" "$NAMESPACE" "${RESTORE_ARGS[@]:$ARCHIVE_POS}")

  # NAMESPACE is pulled from the ARCHIVE name, and is inserted into LIST_ARGS increases max arguments by 1
  check_args RESTORE_ARGS 2 4
  if [[ $? -ne 0 ]]; then
    return 1
  fi

  DATABASE=${RESTORE_ARGS[$ARCHIVE_POS+2]}

  # Be sure that an ondemand pod is ready (start if not started)
  ensure_ondemand_pod_exists

  # Execute the command in the on-demand pod
  kubectl exec -i -n "$NAMESPACE" "$ONDEMAND_POD" -- /tmp/restore_mariadb.sh restore "$ARCHIVE" "$DATABASE" "$LOCATION"
}

# Params: <namespace>
function do_sql_prompt() {

  PROMPT_ARGS=("$@")

  check_args PROMPT_ARGS 1 1
  if [[ $? -ne 0 ]]; then
    return 1
  fi

  # Be sure that an ondemand pod is ready (start if not started)
  ensure_ondemand_pod_exists
  PROMPT_ARGS[2]=$ONDEMAND_POD
  sql_prompt "${PROMPT_ARGS[@]}"
  if [[ $? -ne 0 ]]; then
    return 1
  fi
}

function do_cleanup() {

  if [[ ! -z "$USED_NAMESPACES" ]]; then

    IFS=', ' read -re -a USED_NAMESPACE_ARRAY <<< "$USED_NAMESPACES"

    for NAMESPACE in "${USED_NAMESPACE_ARRAY[@]}";
    do
      remove_job "$NAMESPACE" "$ONDEMAND_JOB"
      if [[ $? -ne 0 ]]; then
        return 1
      fi
    done

    unset USED_NAMESPACES
    unset ONDEMAND_POD

    echo "Cleanup complete."
  else
    echo "Nothing to cleanup."
  fi
}

function do_command_history() {

  echo ""
  echo "Command History:"

  for j in "${HISTORY[@]}";
  do
    echo "$j"
  done
}

function do_trap() {

  do_cleanup
  exit
}

function help() {
  echo "Usage:"
  echo "       utilscli dbutils backup (b) <namespace>"
  echo "           Performs a manual backup of all databases within mariadb for the given namespace."
  echo ""
  echo "       utilscli dbutils list_archives (la) [-r] <namespace>"
  echo "           Retrieves the list of archives, either locally (no '-r'"
  echo "           flag) or from the remote RGW (using '-r' flag)."
  echo ""
  echo "       utilscli dbutils list_databases (ld) [-r] <archive>"
  echo "           Retrieves the list of databases contained within the given"
  echo "           archive tarball. The '-r' flag is used to retrieve the"
  echo "           archive from the remote RGW; otherwise the database list"
  echo "           will be retrieved from the archive on the local filesystem."
  echo ""
  echo "       utilscli dbutils list_tables (lt) [-r] <archive> <database>"
  echo "           Retrieves the list of tables contained within the given"
  echo "           database from the given archive tarball. The '-r' flag"
  echo "           is used to retrieve the archive from the remote RGW;"
  echo "           otherwise the table list will be retrieved from the archive"
  echo "           on the local filesystem."
  echo ""
  echo "       utilscli dbutils list_rows (lr) [-r] <archive> <database> <table>"
  echo "           Retrieves the list of rows in the given table contained"
  echo "           within the given database from the given archive tarball."
  echo "           The '-r' flag is used to retrieve the archive from the"
  echo "           remote RGW; otherwise the table rows will be retrieved from"
  echo "           the archive on the local filesystem."
  echo ""
  echo "       utilscli dbutils list_schema (ls) [-r] <archive> <database> <table>"
  echo "           Retrieves the table schema information for the given table"
  echo "           of the given database from the given archive tarball."
  echo "           The '-r' flag is used to retrieve the archive from the"
  echo "           remote RGW; otherwise the table rows will be retrieved from"
  echo "           the archive on the local filesystem."
  echo ""
  echo "       utilscli dbutils show_databases (sd) <namespace>"
  echo "           Retrieves the list of databases in the currently active"
  echo "           mariadb database system for the given namespace."
  echo ""
  echo "       utilscli dbutils show_tables (st) <namespace> <database>"
  echo "           Retrieves the list of tables of the given database in the"
  echo "           currently active mariadb database system."
  echo ""
  echo "       utilscli dbutils show_rows (sr) <namespace> <database> <table>"
  echo "           Retrieves the list of rows in the given table of the given"
  echo "           database from the currently active mariadb database system."
  echo ""
  echo "       utilscli dbutils show_schema (ss) <namespace> <database> <table>"
  echo "           Retrieves the table schema information for the given table"
  echo "           of the given database from the currently active mariadb"
  echo "           database system."
  echo ""
  echo "       utilscli dbutils restore (r) [-r] <archive> <db_name>"
  echo "           where <db_name> can be either a database name or 'all', which"
  echo "               means all databases are to be restored"
  echo "           Restores the specified database(s) from an archive located"
  echo "           on either the remote RGW ('-r' flag specified) or from"
  echo "           the local filesystem (no '-r' flag)"
  echo ""
  echo "       utilscli dbutils sql_prompt (sql) <namespace>"
  echo "           For manual table/row restoration, this command allows access"
  echo "           to the Mariadb mysql interactive user interface. Type quit"
  echo "           to quit the interface and return back to the dbutils menu."
  echo ""
  echo "       utilscli dbutils cleanup (c)"
  echo "           Cleans up (kills) any jobs/pods which are left running for"
  echo "           any namespaces which have been used during this session."
  echo ""
  echo "       utilscli dbutils command_history (ch)"
  echo "           Displays a list of all entered commands during this session."
  echo ""
  echo "       utilscli dbutils <"
  echo "           Fills the prompt with the previous command. Use multiple times"
  echo "           to go further back in the command history."
}

function menu() {
  echo "Please select from the available options:"
  echo "Execution methods:          backup (b) <namespace>"
  echo "                            restore (r) [-r] <archive> <db_name | all>"
  echo "                            sql_prompt (sql) <namespace>"
  echo "                            cleanup (c)"
  echo "Show Archived details:      list_archives (la) [-r] <namespace>"
  echo "                            list_databases (ld) [-r] <archive>"
  echo "                            list_tables (lt) [-r] <archive> <database>"
  echo "                            list_rows (lr) [-r] <archive> <database> <table>"
  echo "                            list_schema (ls) [-r] <archive> <database> <table>"
  echo "Show Live Database details: show_databases (sd) <namespace>"
  echo "                            show_tables (st) <namespace> <database>"
  echo "                            show_rows (sr) <namespace> <database> <table>"
  echo "                            show_schema (ss) <namespace> <database> <table>"
  echo "Other:                      command_history (ch)"
  echo "                            repeat_cmd (<)"
  echo "                            help (h)"
  echo "                            quit (q)"
  echo "Valid namespaces: ${BACKUP_RESTORE_NAMESPACE_LIST[*]}"
}

function execute_selection() {

  case "${ARGS[0]}" in
    "backup"|"b")                 do_backup "${ARGS[@]}";;
    "list_archives"|"la")         do_list_archives "${ARGS[@]}";;
    "list_databases"|"ld")        do_list_databases "${ARGS[@]}";;
    "list_tables"|"lt")           do_list_tables "${ARGS[@]}";;
    "list_rows"|"lr")             do_list_rows "${ARGS[@]}";;
    "list_schema"|"ls")           do_list_schema "${ARGS[@]}";;
    "show_databases"|"sd")        do_show_databases "${ARGS[@]}";;
    "show_tables"|"st")           do_show_tables "${ARGS[@]}";;
    "show_rows"|"sr")             do_show_rows "${ARGS[@]}";;
    "show_schema"|"ss")           do_show_schema "${ARGS[@]}";;
    "create_test_table"|"ctt")    do_create_table "${ARGS[@]}";;
    "create_test_row"|"ctr")      do_create_row "${ARGS[@]}";;
    "delete_test_row"|"dtr")      do_delete_row "${ARGS[@]}";;
    "delete_test_table"|"dtt")    do_delete_table "${ARGS[@]}";;
    "restore"|"r")                do_restore "${ARGS[@]}";;
    "sql_prompt"|"sql")           do_sql_prompt "${ARGS[@]}";;
    "command_history"|"ch")       do_command_history;;
    "<")                          ;;
    "cleanup"|"c"|"quit"|"q")     do_cleanup;;
    *)                            help;;
  esac
}

function main() {

  setup

  # If no arguments are passed, enter interactive mode
  if [[ "${#ARGS[@]}" -eq 0 ]]; then

    CURRENT_COMMAND=0

    while [[ ${ARGS[0]} != "quit" && ${ARGS[0]} != "q" ]]
    do
      menu

      read -re -p "selection: " -a ARGS -i "${HISTORY[$CURRENT_COMMAND]}"

      if [[ ${ARGS[0]} == '<' ]]; then
        if [[ CURRENT_COMMAND -gt 0 ]]; then
          (( CURRENT_COMMAND = CURRENT_COMMAND - 1 ))
        fi
      else
        HISTORY[${#HISTORY[@]}]="${ARGS[*]}"
        (( CURRENT_COMMAND = ${#HISTORY[@]} ))

        execute_selection "${ARGS[@]}"

        echo ""
        if [[ ${ARGS[0]} != "quit" && ${ARGS[0]} != "q" ]]; then
          read -re -n1 -p "press any key to continue..."
        fi
      fi
    done

  # Arguments are passed, execute the requested command then exit
  else
    execute_selection "${ARGS[@]}"
    do_cleanup
  fi
}

# Begin program
main "${ARGS[@]}"
