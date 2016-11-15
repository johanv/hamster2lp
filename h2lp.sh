#!/bin/bash

# see the h2lprc.example file for info about the rc file
source ~/.h2lprc

function inspect {
  for var in "$@"
  do
    echo argument: "$var"
  done
}

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
  #call_lp "workspaces/${WORKSPACE_ID}/tasks" -G --data-urlencode "filter[]=name = forensics"
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
    >&2 echo "Warning: Tasks in category $2 are not logged."
    return
  fi

  get_lp_task "${1}" "${FOLDER}"
}

if [ -z $1 ]; then
  echo "USAGE: $0 start_date"
  exit 1
fi

TMPFILE=`mktemp`
sqlite3 ~/.local/share/hamster-applet/hamster.db > $TMPFILE << EOF
SELECT a.name, c.name, f.start_time, f.end_time,
  24*(julianday(f.end_time)-julianday(f.start_time))
FROM facts f
JOIN activities a ON f.activity_id = a.id
JOIN categories c ON a.category_id = c.id
WHERE f.start_time >= "$1"
ORDER BY f.start_time
-- limit 2 while testing
LIMIT 2;
EOF

while IFS='' read -r line || [[ -n "$line" ]]; do
    TASK=$(echo $line | cut -f 1 -d \|)
    CATEGORY=$(echo $line | cut -f 2 -d \|)
    PERFORMED_ON=$(echo $line | cut -f 3 -d \|)
    HOURS=$(echo $line | cut -f 5 -d \|)
    LP_TASK=$(get_or_create_lp_task "${TASK}" "${CATEGORY}")

    echo LP_TASK: $CATEGORY .. $LP_TASK
done < $TMPFILE

rm $TMPFILE


# call_lp $1

# track time:
# curl -X POST -H "Content-Type: application/json" -gu "${API_USER}:${API_PW}" https://app.liquidplanner.com/api/workspaces/103787/tasks/34108034/track_time -d '{"work":1,"activity_id":139977}'
