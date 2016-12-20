#!/bin/bash

# h2lp.sh - pushes hamster time tracking info to the liquidplanner time sheets.

# Copyright 2016 Johan Vervloet
# You can use this under the terms of GNU GPL v3.
# https://www.gnu.org/licenses/gpl-3.0.en.html

SCRIPTDIR=`dirname ${0}`
source $SCRIPTDIR/h2lp-lib.sh

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
