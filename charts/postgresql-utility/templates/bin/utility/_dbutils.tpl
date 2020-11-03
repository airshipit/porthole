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

  source /tmp/pgutils.sh
  if [[ $? -ne 0 ]]; then
    echo "ERROR: source /tmp/pgutils.sh failed. Cannot continue. Exiting..."
    exit 1
  fi

  if [[ -z "$BACKUP_RESTORE_NAMESPACE_LIST" ]]; then
    echo "ERROR: Namespaces are not defined. Exiting..."
    exit 1
  fi

  export ONDEMAND_JOB="postgresql-ondemand"
  export KEEP_POD="false"

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

  NAMESPACE_POS=1

  # Check if the first parameter is the remote flag.
  if [[ "${ARGS_ARRAY[1]}" =~ ^-rp|^-pr|^-r ]]; then
    export LOC_STRING="remote RGW"
    export LOCATION="remote"
    NAMESPACE_POS=2
  else
    export LOC_STRING="local"
    export LOCATION=""
  fi

  # Check if persistent on-demand pod is enabled
  if [[ "${ARGS_ARRAY[1]}" =~ ^-rp|^-pr|^-p ]]; then
    export KEEP_POD="true"
    NAMESPACE_POS=2
  else
    export KEEP_POD="false"
  fi

  setup_namespace "${ARGS_ARRAY[$NAMESPACE_POS]}"
  if [[ "$?" -ne 0 ]]; then
    return 1
  fi

  return 0
}

# Ensure that the ondemand pod is running
function ensure_ondemand_pod_exists() {

  # Determine the status of the on demand pod if it exists
  POD_LISTING=$(kubectl get pod -n "$NAMESPACE" | grep "$ONDEMAND_JOB")
  if [[ ! -z "$POD_LISTING" ]]; then
    ONDEMAND_POD=$(echo "$POD_LISTING" | awk '{print $1}')
    STATUS=$(echo "$POD_LISTING" | awk '{print $3}')
    if [[ "$STATUS" == "Terminating" ]]; then
      kubectl wait -n "$NAMESPACE" --for=delete pod/"$ONDEMAND_POD" --timeout=30s
      unset ONDEMAND_POD
    elif [[ "$STATUS" != "Running" ]]; then
      kubectl wait -n "$NAMESPACE" --for condition=ready pod/"$ONDEMAND_POD" --timeout=30s
    fi
  fi

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
    /tmp/pg-ondemand-job.sh "$NAMESPACE"
    if [[ $? -ne 0 ]]; then
      echo "ERROR: Failed to execute: /tmp/pg-ondemand-job.sh $NAMESPACE. Exiting..."
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

# Params: [namespace] <job>
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

# Params: timeout (how long in seconds flock waited on the lock to be released)
function flock_error() {
   echo "ERROR: Lock did not release after $1 seconds."
   echo "  Another process may have locked /tmp/dbutils.lock"
   echo "  If you are sure no other process is running, rm /tmp/dbutils.lock"
   echo "  and run dbutils again."

   exit 1
}

# Params: timeout (if locked, how long should flock wait on the lock to be released)
function lock() {
  timeout=$1
  exec 200>/tmp/dbutils.lock
  flock -w "$timeout" 200 || flock_error "$timeout"
  export MY_LOCK="true"
  echo "Acquired lock."
}

function unlock() {
  flock -u 200
  export MY_LOCK="false"
  echo "Lock Removed."
}

# Params: [-p] [database]
function do_backup() {

  BACKUP_ARGS=("$@")

  check_args BACKUP_ARGS 0 2
  if [[ $? -ne 0 ]]; then
    return 1
  fi

  # Be sure that an ondemand pod is ready (start if not started)
  ensure_ondemand_pod_exists

  lock 60

  # Execute the command in the on-demand pod
  if [[ -z "${BACKUP_ARGS[1]}" ]]; then
    DB_LOC=0
  else
    if [[ "${BACKUP_ARGS[1]}" != "-p" ]]; then
      DB_LOC=1
    else
      DB_LOC=2
    fi
  fi

  if [[ "$DB_LOC" == 0 ]]; then
    COMMAND="/tmp/backup_postgresql.sh"
  else
    COMMAND="/tmp/backup_postgresql.sh ${BACKUP_ARGS[$DB_LOC]}"
  fi

  kubectl exec -i -n "$NAMESPACE" "$ONDEMAND_POD" -- $COMMAND

  unlock
}

# Params: [-rp] [namespace]
function do_list_archives() {

  LIST_ARGS=("$@")

  check_args LIST_ARGS 0 2
  if [[ $? -ne 0 ]]; then
    return 1
  fi

  # Be sure that an ondemand pod is ready (start if not started)
  ensure_ondemand_pod_exists

  # Execute the command in the on-demand pod
  kubectl exec -i -n "$NAMESPACE" "$ONDEMAND_POD" -- /tmp/restore_postgresql.sh list_archives "$LOCATION"
}

# Params: [-rp] <archive>
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
  kubectl exec -i -n "$NAMESPACE" "$ONDEMAND_POD" -- /tmp/restore_postgresql.sh list_databases "$ARCHIVE" "$LOCATION"
}

# Params: [-rp] <archive> <database>
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
  kubectl exec -i -n "$NAMESPACE" "$ONDEMAND_POD" -- /tmp/restore_postgresql.sh list_tables "$ARCHIVE" "$DATABASE" "$LOCATION"
}

# Params: [-rp] <archive> <database> <table>
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

  # NAMESPACE is pulled from the ARCHIVE name, and is inserted into LIST_ARGS increases max arguments by 1
  check_args LIST_ARGS 3 5
  if [[ $? -ne 0 ]]; then
    return 1
  fi

  DATABASE=${LIST_ARGS[$ARCHIVE_POS+2]}
  TABLE=${LIST_ARGS[$ARCHIVE_POS+3]}

  # Be sure that an ondemand pod is ready (start if not started)
  ensure_ondemand_pod_exists

  # Execute the command in the on-demand pod
  kubectl exec -i -n "$NAMESPACE" "$ONDEMAND_POD" -- /tmp/restore_postgresql.sh list_rows "$ARCHIVE" "$DATABASE" "$TABLE" "$LOCATION"
}

# Params: [-rp] <archive> <database> <table>
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

  # NAMESPACE is pulled from the ARCHIVE name, and is inserted into LIST_ARGS increases max arguments by 1
  check_args LIST_ARGS 3 5
  if [[ $? -ne 0 ]]; then
    return 1
  fi

  DATABASE=${LIST_ARGS[$ARCHIVE_POS+2]}
  TABLE=${LIST_ARGS[$ARCHIVE_POS+3]}

  # Be sure that an ondemand pod is ready (start if not started)
  ensure_ondemand_pod_exists

  # Execute the command in the on-demand pod
  kubectl exec -i -n "$NAMESPACE" "$ONDEMAND_POD" -- /tmp/restore_postgresql.sh list_schema "$ARCHIVE" "$DATABASE" "$TABLE" "$LOCATION"
}

# Params: [-rp] <archive>
function do_delete_archive() {

  # Determine which argument is the ARCHIVE in order to detect the NAMESPACE
  DELETE_ARCH_ARGS=("$@")
  if [[ "${DELETE_ARCH_ARGS[1]}" =~ .tar.gz ]]; then
    ARCHIVE="${DELETE_ARCH_ARGS[1]}"
    ARCHIVE_POS=1
  elif [[ "${DELETE_ARCH_ARGS[2]}" =~ .tar.gz ]]; then
    ARCHIVE="${DELETE_ARCH_ARGS[2]}"
    ARCHIVE_POS=2
  else
    echo "ERROR: Archive file not found in 1st or 2nd argument position."
    return 1
  fi

  NAMESPACE="$(echo "${ARCHIVE}" | awk -F '.' '{print $2}')"
  DELETE_ARCH_ARGS=("${DELETE_ARCH_ARGS[@]:0:$ARCHIVE_POS}" "${NAMESPACE}" "${DELETE_ARCH_ARGS[@]:$ARCHIVE_POS}")

  # NAMESPACE is pulled from the ARCHIVE name, and is inserted into DELETE_ARCH_ARGS increases max arguments by 1
  check_args DELETE_ARCH_ARGS 1 3
  if [[ $? -ne 0 ]]; then
    return 1
  fi

  # Be sure that an ondemand pod is ready (start if not started)
  ensure_ondemand_pod_exists

  # Execute the command in the on-demand pod
  kubectl exec -i -n "${NAMESPACE}" "${ONDEMAND_POD}" -- /tmp/restore_postgresql.sh delete_archive "${ARCHIVE}" "${LOCATION}"
}

# Params: [namespace]
function do_show_databases() {

  SHOW_ARGS=("$@")

  check_args SHOW_ARGS 0 1
  if [[ $? -ne 0 ]]; then
    return 1
  fi

  SHOW_ARGS=("${SHOW_ARGS[@]:0:1}" "$NAMESPACE" "${SHOW_ARGS[@]:1}")
  show_databases "${SHOW_ARGS[@]}"
  if [[ $? -ne 0 ]]; then
    return 1
  fi
}

# Params: [namespace] <database>
function do_show_tables() {

  SHOW_ARGS=("$@")

  check_args SHOW_ARGS 1 2
  if [[ $? -ne 0 ]]; then
    return 1
  fi

  SHOW_ARGS=("${SHOW_ARGS[@]:0:1}" "$NAMESPACE" "${SHOW_ARGS[@]:1}")
  show_tables "${SHOW_ARGS[@]}"
  if [[ $? -ne 0 ]]; then
    return 1
  fi
}

# Params: [namespace] <database> <table>
function do_show_rows() {

  SHOW_ARGS=("$@")

  check_args SHOW_ARGS 2 3
  if [[ $? -ne 0 ]]; then
    return 1
  fi

  SHOW_ARGS=("${SHOW_ARGS[@]:0:1}" "$NAMESPACE" "${SHOW_ARGS[@]:1}")
  show_rows "${SHOW_ARGS[@]}"
  if [[ $? -ne 0 ]]; then
    return 1
  fi
}

# Params: [namespace] <database> <table>
function do_show_schema() {

  SHOW_ARGS=("$@")

  check_args SHOW_ARGS 2 3
  if [[ $? -ne 0 ]]; then
    return 1
  fi

  SHOW_ARGS=("${SHOW_ARGS[@]:0:1}" "$NAMESPACE" "${SHOW_ARGS[@]:1}")

  show_schema "${SHOW_ARGS[@]}"
  if [[ $? -ne 0 ]]; then
    return 1
  fi
}

# Params: [namespace] <tablename>
#   Column names and types will be hardcoded for now
#   NOTE: Database is always a pre-provisioned database.
function do_create_table() {

  CREATE_ARGS=("$@")

  check_args CREATE_ARGS 1 2
  if [[ $? -ne 0 ]]; then
    return 1
  fi

  CREATE_ARGS=("${CREATE_ARGS[@]:0:1}" "$NAMESPACE" "${CREATE_ARGS[@]:1}")
  create_table "${CREATE_ARGS[@]}"
  if [[ $? -ne 0 ]]; then
    return 1
  fi
}

# Params: [namespace] <table>
#   The row values are hardcoded for now.
#   NOTE: Database is always a pre-provisioned database.
function do_create_row() {

  CREATE_ARGS=("$@")

  check_args CREATE_ARGS 1 2
  if [[ $? -ne 0 ]]; then
    return 1
  fi

  CREATE_ARGS=("${CREATE_ARGS[@]:0:1}" "$NAMESPACE" "${CREATE_ARGS[@]:1}")
  create_row "${CREATE_ARGS[@]}"
  if [[ $? -ne 0 ]]; then
    return 1
  fi
}

# Params: [namespace]
#   Create grants for the test user to access the test database.
#   NOTE: Database is always a pre-provisioned database.
#   NOTE: In order for this function to create a user, create_test_database in
#         values.yaml file needs to be set to true to create the test database
#         at bootstrap time. Otherwise it cannot correctly give the user any
#         privileges.
function do_create_user_grants() {

  CREATE_GRANTS_ARGS=("$@")

  check_args CREATE_GRANTS_ARGS 0 1
  if [[ $? -ne 0 ]]; then
    return 1
  fi

  CREATE_GRANTS_ARGS=("${CREATE_GRANTS_ARGS[0]}" "${NAMESPACE}")
  create_user_grants "${CREATE_GRANTS_ARGS[@]}"
  if [[ $? -ne 0 ]]; then
    return 1
  fi
}

# Params: [namespace]
#   Query the test user of the test database.
#   Returns a string indicating whether or not the query was successful.
#   NOTE: Database is always a pre-provisioned database.
#   NOTE: In order for this function to show a user, create_test_database in
#         values.yaml file needs to be set to true to create the test user
#         at bootstrap time.
function do_query_user() {

  QUERY_USER_ARGS=("$@")

  check_args QUERY_USER_ARGS 0 1
  if [[ $? -ne 0 ]]; then
    return 1
  fi

  QUERY_USER_ARGS=("${QUERY_USER_ARGS[0]}" "${NAMESPACE}")
  query_user "${QUERY_USER_ARGS[@]}"
  if [[ $? -ne 0 ]]; then
    return 1
  fi
}

# Params: [namespace]
#   Delete the grants for the test user in the test database.
#   NOTE: Database is always a pre-provisioned database.
#   NOTE: In order for this function to delete a user, create_test_database in
#         values.yaml file needs to be set to true to create the test user
#         at bootstrap time. If the user isn't there this will fail.
function do_delete_user_grants() {

  DELETE_GRANTS_ARGS=("$@")

  check_args DELETE_GRANTS_ARGS 0 1
  if [[ $? -ne 0 ]]; then
    return 1
  fi

  DELETE_GRANTS_ARGS=("${DELETE_GRANTS_ARGS[0]}" "${NAMESPACE}")
  delete_user_grants "${DELETE_GRANTS_ARGS[@]}"
  if [[ $? -ne 0 ]]; then
    return 1
  fi
}

# Params: [namespace] <table> <colname> <value>
#   Where: <colname> = <value> is the condition used to find the row to be deleted.
#   NOTE: Database is always a pre-provisioned database.
function do_delete_row() {

  DELETE_ARGS=("$@")

  check_args DELETE_ARGS 3 4
  if [[ $? -ne 0 ]]; then
    return 1
  fi

  DELETE_ARGS=("${DELETE_ARGS[@]:0:1}" "$NAMESPACE" "${DELETE_ARGS[@]:1}")

  delete_row "${DELETE_ARGS[@]}"
  if [[ $? -ne 0 ]]; then
    return 1
  fi
}

# Params: [namespace] <tablename>
#   NOTE: Database is always a pre-provisioned database.
function do_delete_table() {

  DELETE_ARGS=("$@")

  check_args DELETE_ARGS 1 2
  if [[ $? -ne 0 ]]; then
    return 1
  fi

  DELETE_ARGS=("${DELETE_ARGS[@]:0:1}" "$NAMESPACE" "${DELETE_ARGS[@]:1}")

  delete_table "${DELETE_ARGS[@]}"
  if [[ $? -ne 0 ]]; then
    return 1
  fi
}

# Params: [namespace]
#   Delete the test backups that have been created by the test functions above.
#   NOTE: only backups associated with the test database will be deleted.
#         Both local and remote test backups will be deleted.
function do_delete_backups() {

  DELETE_BACKUPS_ARGS=("$@")

  check_args DELETE_BACKUPS_ARGS 0 1
  if [[ $? -ne 0 ]]; then
    return 1
  fi

  # Be sure that an ondemand pod is ready (start if not started)
  ensure_ondemand_pod_exists

  DELETE_BACKUPS_ARGS=("${DELETE_BACKUPS_ARGS[0]}" "${NAMESPACE}" ${ONDEMAND_POD})
  delete_backups "${DELETE_BACKUPS_ARGS[@]}"
  if [[ $? -ne 0 ]]; then
    return 1
  fi
}

# Params: [-rp] <archive> <db_name>
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

  # NAMESPACE is pulled from the ARCHIVE name, and is inserted into RESTORE_ARGS increases max arguments by 1
  check_args RESTORE_ARGS 2 4
  if [[ $? -ne 0 ]]; then
    return 1
  fi

  DATABASE=${RESTORE_ARGS[$ARCHIVE_POS+2]}

  # Be sure that an ondemand pod is ready (start if not started)
  ensure_ondemand_pod_exists

  lock 60

  # Execute the command in the on-demand pod
  kubectl exec -i -n "$NAMESPACE" "$ONDEMAND_POD" -- /tmp/restore_postgresql.sh restore "$ARCHIVE" "$DATABASE" "$LOCATION"

  unlock
}

function do_sql_prompt() {

  PROMPT_ARGS=("$@")

  check_args PROMPT_ARGS 0 1
  if [[ $? -ne 0 ]]; then
    return 1
  fi

  if [[ -z "${PROMPT_ARGS[1]}" ]]; then
    PROMPT_ARGS[1]="$NAMESPACE"
  fi

  sql_prompt "${PROMPT_ARGS[@]}"
  if [[ $? -ne 0 ]]; then
    return 1
  fi
}

# Params: [namespace]
function do_cleanup() {

  # If a namespace is given go ahead and try to clean it up.
  if [[ ! -z "$2" ]]; then
    remove_job "$2" "$ONDEMAND_JOB"
    unset ONDEMAND_POD
  elif [[ "$KEEP_POD" == "false" && ! -z "$ONDEMAND_POD" ]]; then

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
    if [[ "$KEEP_POD" == "true" ]]; then
      echo "Persistent Pod -p enabled, no cleanup performed on $ONDEMAND_POD"
    else
      echo "Nothing to cleanup."
    fi
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

  if [[ "$MY_LOCK" == "true" ]]; then
    unlock
  fi

  do_cleanup
  exit
}

function help() {
  echo "Usage:"
  echo "       -r Remote flag. When used will use the remote RGW location."
  echo "            Not using this flag will use the local filesystem."
  echo ""
  echo "       -p Persistent On-Demand Pod. The On-Demand Pod will not be"
  echo "            removed when the command finishes if applicable."
  echo ""
  echo "       utilscli dbutils backup (b) [-p]"
  echo "           Performs a manual backup of all databases within Postgresql"
  echo "           for the given namespace."
  echo ""
  echo "       utilscli dbutils list_archives (la) [-rp]"
  echo "           Retrieves the list of archives."
  echo ""
  echo "       utilscli dbutils list_databases (ld) [-rp] <archive>"
  echo "           Retrieves the list of databases contained within the given"
  echo "           archive tarball."
  echo ""
  echo "       utilscli dbutils list_tables (lt) [-rp] <archive> <database>"
  echo "           Retrieves the list of tables contained within the given"
  echo "           database from the given archive tarball."
  echo ""
  echo "       utilscli dbutils list_rows (lr) [-rp] <archive> <database> <table>"
  echo "           Retrieves the list of rows in the given table contained"
  echo "           within the given database from the given archive tarball."
  echo ""
  echo "       utilscli dbutils list_schema (ls) [-rp] <archive> <database> <table>"
  echo "           Retrieves the table schema information for the given table"
  echo "           of the given database from the given archive tarball."
  echo ""
  echo "       utilscli dbutils show_databases (sd)"
  echo "           Retrieves the list of databases in the currently active"
  echo "           Postgresql database system for the given namespace."
  echo ""
  echo "       utilscli dbutils show_tables (st) <database>"
  echo "           Retrieves the list of tables of the given database in the"
  echo "           currently active Postgresql database system."
  echo ""
  echo "       utilscli dbutils show_rows (sr) <database> <table>"
  echo "           Retrieves the list of rows in the given table of the given"
  echo "           database from the currently active Postgresql database system."
  echo ""
  echo "       utilscli dbutils show_schema (ss) <database> <table>"
  echo "           Retrieves the table schema information for the given table"
  echo "           of the given database from the currently active Postgresql"
  echo "           database system."
  echo ""
  echo "       utilscli dbutils restore (r) [-rp] <archive> <db_name>"
  echo "           where <db_name> can be either a database name or 'all', which"
  echo "               means all databases are to be restored"
  echo "           Restores the specified database(s)."
  echo ""
  echo "       utilscli dbutils delete_archive (da) [-rp] <archive>"
  echo "           Deletes the specified archive from either the local file"
  echo "           system or the remove rgw location."
  echo ""
  echo "       utilscli dbutils sql_prompt (sql)"
  echo "           For manual table/row restoration, this command allows access"
  echo "           to the Postgresql psql interactive user interface. Type '\q'"
  echo "           to quit the interface and return back to the dbutils menu."
  echo ""
  echo "       utilscli dbutils cleanup (c) [namespace]"
  echo "           Cleans up (kills) any jobs/pods which are left running for"
  echo "           any namespaces which have been used during this session."
  echo "           For non-interactive mode, namespace is required for cleanup."
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
  echo "Execution methods:          backup (b) [-p]"
  echo "                            restore (r) [-rp] <archive> <db_name | all>"
  echo "                            sql_prompt (sql)"
  echo "                            delete_archive (da) [-rp] <archive>"
  echo "                            cleanup (c)"
  echo "Show Archived details:      list_archives (la) [-rp]"
  echo "                            list_databases (ld) [-rp] <archive>"
  echo "                            list_tables (lt) [-rp] <archive> <database>"
  echo "                            list_rows (lr) [-rp] <archive> <database> <table>"
  echo "                            list_schema (ls) [-rp] <archive> <database> <table>"
  echo "Show Live Database details: show_databases (sd)"
  echo "                            show_tables (st) <database>"
  echo "                            show_rows (sr) <database> <table>"
  echo "                            show_schema (ss) <database> <table>"
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
    "delete_archive"|"da")        do_delete_archive "${ARGS[@]}";;
    "show_databases"|"sd")        do_show_databases "${ARGS[@]}";;
    "show_tables"|"st")           do_show_tables "${ARGS[@]}";;
    "show_rows"|"sr")             do_show_rows "${ARGS[@]}";;
    "show_schema"|"ss")           do_show_schema "${ARGS[@]}";;
    "create_test_table"|"ctt")    do_create_table "${ARGS[@]}";;
    "create_test_row"|"ctr")      do_create_row "${ARGS[@]}";;
    "create_test_user_grants"|"ctug")     do_create_user_grants "${ARGS[@]}";;
    "query_test_user"|"qtu")              do_query_user "${ARGS[@]}";;
    "delete_test_user_grants"|"dtug")     do_delete_user_grants "${ARGS[@]}";;
    "delete_test_row"|"dtr")      do_delete_row "${ARGS[@]}";;
    "delete_test_table"|"dtt")    do_delete_table "${ARGS[@]}";;
    "delete_test_backups"|"dtb")  do_delete_backups "${ARGS[@]}";;
    "restore"|"r")                do_restore "${ARGS[@]}";;
    "sql_prompt"|"sql")           do_sql_prompt "${ARGS[@]}";;
    "command_history"|"ch")       do_command_history;;
    "<")                          ;;
    "cleanup"|"c"|"quit"|"q")     do_cleanup "${ARGS[@]}";;
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
    if [[ "${ARGS[0]}" != "c" && "${ARGS[0]}" != "cleanup" && "${ARGS[0]}" != "quit" && "${ARGS[0]}" != "q" ]]; then
      do_cleanup
    fi
    echo "Task Complete"
  fi
}

# Begin program
main "${ARGS[@]}"
