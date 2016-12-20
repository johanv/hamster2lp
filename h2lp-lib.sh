# h2lp-lib.sh shared functions for the h2lp scripts.

# Copyright 2016 Johan Vervloet
# You can use this under the terms of GNU GPL v3.
# https://www.gnu.org/licenses/gpl-3.0.en.html

# see the h2lprc.example file for info about the rc file
source ~/.h2lprc

# Private: call the LiquidPlanner API
#
# This uses the credentials in API_USER and API_PW for authentication.
#
# $1 - Resource
# $2 - Extra options for curl (yeah hacky hacky)
#
# Returns the http status code, shows the content on stdout.
#
function call_lp {
  TMPFILE=`mktemp`
  RESOURCE="${1}"
  shift
  # avoid hitting rate limit
  sleep 1
  URL="https://app.liquidplanner.com/api/${RESOURCE}"
  # use -g to avoid problems with [] in url.
  STATUS=$(curl "$@" -u "${API_USER}:${API_PW}" -qgsw '%{http_code}' -o $TMPFILE -H "Content-Type: application/json" "${URL}")
  cat $TMPFILE
  rm $TMPFILE
  return $STATUS
}

# Public: return task ID of task in given folder on stdout.
#
# $1 - Task name
# $2 - ID of liquidplanner folder
function get_lp_task {
  call_lp "workspaces/${WORKSPACE_ID}/tasks" -G --data-urlencode \
    "filter[]=name=${1}" --data-urlencode "filter[]=parent_id=${2}" | jq '.[0]|.id'
}

# Public: creates a new task in LiquidPlanner.
# The task-ID is shown on stdout.
#
# $1 - Task name
# $2 - ID of parent folder
function create_lp_task {
  PACKAGE_DATA="";
  if [ ! -z $PACKAGE_ID ]; then
    PACKAGE_DATA=", \"package_id\":${PACKAGE_ID}";
  fi
  DATA="{\"task\": {\"name\": \"${1}\", \"parent_id\": ${2}${PACKAGE_DATA}}}"
  JSON=$(call_lp "workspaces/${WORKSPACE_ID}/tasks" -X POST --data "${DATA}")
  STATUS=$?
  if [[ ! $STATUS = 201 ]]; then
    2>&1 echo "ERROR: Could not create task ${1} in ${2}."
    2>&1 echo "STATUS: $STATUS"
  fi
  echo $JSON | jq .id
}

# Public: get or create a task in LiquidPlanner.
#
# The task-ID will be printed on stdout (because return values are 8-bit ints)
# categories/projects are mapped to LiquidPlanner folders based on the
# MAP_* variables in ~/.h2lprc.
#
# $1 - Task name
# $2 - category/project
#
function get_or_create_lp_task {
  MAPNAME=MAP_$2
  # getting elements of associative arrays if the name of the
  # array is given, does not seem to be trivial using bash.

  TASK_ID=$(eval echo \${$MAPNAME[task]})
  FOLDER=$(eval echo \${$MAPNAME[folder]})

  if [ ! -z $TASK_ID ]; then
    echo $TASK_ID
    return
  fi

  if [ -z $FOLDER ]; then
    >&2 echo "WARNING: Tasks in category $2 are ignored."
    return
  fi

  TASK_ID=$(get_lp_task "${1}" "${FOLDER}")
  if [ "$TASK_ID" = 'null' ]; then
    >&2 echo INFO: CREATING TASK "${1}" in "${FOLDER}"
    create_lp_task "${1}" "${FOLDER}"
    return
  fi
  echo $TASK_ID
}
