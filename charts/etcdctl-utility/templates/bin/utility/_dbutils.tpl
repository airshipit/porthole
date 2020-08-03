#!/bin/bash

# This file contains database utility scripts which a user can execute
# to perform database specific tasks such as backup, restore, and showing
# tables.
#
# The user can execute this script by calling:
#   dbutils
#
#     No arguments required. However the script will expect the
#     following variables to be exported:
#
#       export NODE               The name of the node which etcd operations will run on.

trap do_trap SIGINT SIGTERM

ARGS=("$@")

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
  if [[ "${ARGS_ARRAY[1]}" =~ ^-rp|^-pr|^-r ]]; then
    export LOC_STRING="remote RGW"
    export LOCATION="remote"
  else
    export LOC_STRING="local"
    export LOCATION=""
  fi

  # Check if persistent on-demand pod is enabled
  if [[ "${ARGS_ARRAY[1]}" =~ ^-rp|^-pr|^-p ]]; then
    export KEEP_POD="true"
  else
    export KEEP_POD="false"
  fi

  # Check if a valid NODE was entered as the last parameter
  NODE_EXISTS=$(kubectl get nodes | grep -w "${ARGS_ARRAY[-1]}" | awk '{print $1}')

  # If a valid NODE was entered above then set NODE
  if [[ ! -z "$NODE_EXISTS" ]]; then
    export NODE="$NODE_EXISTS"

  # If NODE is not set then error
  elif [[ -z "$NODE" ]]; then
    echo "ERROR: NODE could not be determined. Either export NODE prior to"
    echo "running this script or enter it as a parameter."
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
    /tmp/etcd-ondemand-job.sh "$NAMESPACE"
    if [[ $? -ne 0 ]]; then
      echo "ERROR: Failed to execute: /tmp/etcd-ondemand-job.sh $NAMESPACE. Exiting..."
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

# Params: <job>
function remove_job() {

  JOB=$1

  # Cleanup the last attempted job if there is one, wait for the pod to be deleted.
  kubectl get job -n "$NAMESPACE" "$JOB"
  if [[ $? -eq 0 ]]; then
    echo "Removing on-demand job $NAMESPACE $JOB"
    ONDEMAND_POD=$(kubectl get pod -n "$NAMESPACE" | grep "$ONDEMAND_JOB" | awk '{print $1}')
    kubectl delete job --ignore-not-found -n "$NAMESPACE" "$JOB"
    kubectl wait --for=delete --timeout=300s -n "$NAMESPACE" pod/"${ONDEMAND_POD}" &>/dev/null
    if [[ $? -ne 0 ]]; then
      echo "ERROR: could not destroy the $NAMESPACE $JOB job. Exiting..."
      exit 1
    fi
  fi
}

# Params: [-p] [node]
function do_backup() {

  BACKUP_ARGS=("$@")

  check_args BACKUP_ARGS 0 2
  if [[ $? -ne 0 ]]; then
    return 1
  fi

  # Be sure that an ondemand pod is ready (start if not started)
  ensure_ondemand_pod_exists

  # Execute the command in the on-demand pod
  kubectl exec -i -n "$NAMESPACE" "$ONDEMAND_POD" -- /tmp/backup_etcd.sh
}

# Params: [-rp] [node]
function do_list_archives() {

  LIST_ARGS=("$@")

  check_args LIST_ARGS 0 2
  if [[ $? -ne 0 ]]; then
    return 1
  fi

  # Be sure that an ondemand pod is ready (start if not started)
  ensure_ondemand_pod_exists

  # Execute the command in the on-demand pod
  kubectl exec -i -n "$NAMESPACE" "$ONDEMAND_POD" -- /tmp/restore_etcd.sh list_archives "$LOCATION"
}

# Params: [-rp] <archive> <anchor> [node]
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

  RESTORE_ARGS=("${RESTORE_ARGS[@]:0:$ARCHIVE_POS}" "$NAMESPACE" "${RESTORE_ARGS[@]:$ARCHIVE_POS}")

  # NAMESPACE is always set to kube-system and is inserted into RESTORE_ARGS; increases max arguments by 1
  check_args RESTORE_ARGS 2 5
  if [[ $? -ne 0 ]]; then
    return 1
  fi

  DATABASE=${RESTORE_ARGS[$ARCHIVE_POS+2]}

  # Be sure that an ondemand pod is ready (start if not started)
  ensure_ondemand_pod_exists

  # Execute the command in the on-demand pod
  kubectl exec -i -n "$NAMESPACE" "$ONDEMAND_POD" -- /tmp/restore_etcd.sh restore "$ARCHIVE" "$DATABASE" "$LOCATION"
}

function do_cleanup() {

  if [[ "$KEEP_POD" == "false" ]]; then
    remove_job "$ONDEMAND_JOB"

    unset ONDEMAND_POD

    echo "Cleanup complete."
  else
    echo "Persistent Pod -p enabled, no cleanup performed on $ONDEMAND_POD"
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
  echo "       -r Remote flag. When used will use the remote RGW location."
  echo "            Not using this flag will use the local filesystem."
  echo ""
  echo "       -p Persistent On-Demand Pod. The On-Demand Pod will not be"
  echo "            removed when the command finishes if applicable."
  echo ""
  echo "       utilscli dbutils backup (b) [-p] [node]"
  echo "           Performs a manual backup of etcd."
  echo ""
  echo "       utilscli dbutils list_archives (la) [-rp] [node]"
  echo "           Retrieves the list of archives."
  echo ""
  echo "       utilscli dbutils restore (r) [-rp] <archive> <anchor> [node]"
  echo "           Restores the specified etcd archive from an archive."
  echo ""
  echo "       utilscli dbutils cleanup (c)"
  echo "           Cleans up (kills) any jobs/pods which are left running"
  echo "           during this session."
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
  echo "Execution methods:          backup (b) [-p] [node]"
  echo "                            list_archives (la) [-rp] [node]"
  echo "                            restore (r) [-rp] <archive> <anchor> [node]"
  echo "                            cleanup (c)"
  echo "Other:                      command_history (ch)"
  echo "                            repeat_cmd (<)"
  echo "                            help (h)"
  echo "                            quit (q)"
}

function execute_selection() {

  case "${ARGS[0]}" in
    "backup"|"b")                   do_backup "${ARGS[@]}";;
    "list_archives"|"la")           do_list_archives "${ARGS[@]}";;
    "restore"|"r")                  do_restore "${ARGS[@]}";;
    "cleanup"|"c"|"quit"|"q")       do_cleanup;;
    "command_history"|"ch")         do_command_history;;
    "<")                            ;;
    *)                              help;;
  esac
}

function main() {

  # NAMESPACE should always be set to kube-system
  export NAMESPACE="kube-system"
  export ONDEMAND_JOB="etcd-ondemand"
  # Save a backup of NODE if needed later
  export NODE_BACKUP="$NODE"

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

        # Restore the original NODE since it may have been overwritten
        export NODE="$NODE_BACKUP"

        echo ""
        if [[ ${ARGS[0]} != "quit" && ${ARGS[0]} != "q" ]]; then
          read -re -n1 -p "press any key to continue..."
        fi
      fi
    done

  # Arguments are passed, execute the requested command then exit
  else
    execute_selection "${ARGS[@]}"
    if [[ "${ARGS[@]}" != "c" && "${ARGS[@]}" != "cleanup" && "${ARGS[@]}" != "quit" && "${ARGS[@]}" != "q" ]]; then
      do_cleanup
    fi
    echo "Task Complete"
  fi
}

# Begin program
main "${ARGS[@]}"
