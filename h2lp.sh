#!/bin/bash

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
  DATA="{\"task\": {\"name\": \"${1}\", \"parent_id\": ${2}}}"
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
# Hamster categories are mapped to LiquidPlanner folders based on the
# MAP_* variables in ~/.h2lprc.
#
# $1 - Task name
# $2 - hamster category
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
    >&2 echo "WARNING: Tasks in category $2 are not logged."
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

# Public: log time in LiquidPlanner.
# Prevents double logging by checking the fact id in ~/.h2lp.facts
#
# $1 - task ID
# $2 - # hours to log
# $3 - activity id
# $4 - fact id
# $5 - date on which the work was performed
#
function lp_log {
  EXISTING=$(grep "^$4\$" ~/.h2lp.facts)
  if [ ! -z "$EXISTING" ]; then
    2>&1 echo "INFO: $4: Skipped logging activity $3, task $1 on $5."
    return
  fi
  DATA="{\"work\":\"$2\",\"activity_id\":${3}, \"work_performed_on\":\"${5}\"}"
  JSON=$(call_lp "workspaces/${WORKSPACE_ID}/tasks/${1}/track_time" -X POST --data "${DATA}")
  if [ ! $STATUS = 200 ]; then
    2>&1 echo "ERROR: $4: Could not track time for $1 on $5 ($2 hours)"
    return
  fi
  echo $4 >> ~/.h2lp.facts
}

if [ -z $1 ]; then
  echo "USAGE: $0 start_date"
  exit 1
fi

TMPFILE=`mktemp`
sqlite3 ~/.local/share/hamster-applet/hamster.db > $TMPFILE << EOF
SELECT a.name, c.name, f.start_time, f.end_time,
  24*(julianday(f.end_time)-julianday(f.start_time)), f.id
FROM facts f
JOIN activities a ON f.activity_id = a.id
JOIN categories c ON a.category_id = c.id
WHERE f.start_time >= "$1"
ORDER BY f.start_time;
EOF

while IFS='' read -r line || [[ -n "$line" ]]; do
    # remove annoying characters from task names, replace by _
    TASK=$(echo $line | tr '()[]-' '_____'| cut -f 1 -d \|)
    CATEGORY=$(echo $line | cut -f 2 -d \| | tr - _)
    PERFORMED_ON=$(echo $line | cut -f 3 -d \|)
    HOURS=$(echo $line | cut -f 5 -d \|)
    FACT_ID=$(echo $line | cut -f 6 -d \|)
    LP_TASK=$(get_or_create_lp_task "${TASK}" "${CATEGORY}")

    if [ ! -z "${LP_TASK}" ]; then
      # smelly code...
      MAPNAME=MAP_$CATEGORY
      ACTIVITY=$(eval echo \${$MAPNAME[activity]})
      echo "$FACT_ID: $CATEGORY: $PERFORMED_ON: $HOURS: $TASK ($LP_TASK) "
      lp_log $LP_TASK $HOURS $ACTIVITY $FACT_ID $PERFORMED_ON
    fi
done < $TMPFILE

rm $TMPFILE

