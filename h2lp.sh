#!/bin/bash

# the file below should contain:
# API_USER=your_liquidplanner_user_name
# API_PW=your_liquidplanner_password
source ~/.h2lprc

# Public: call the LiquidPlanner API
#
# This uses the credentials in API_USER and API_PW for authentication.
#
# $1 - Resource
#
# Returns the http status code, shows the content on stdout.
#
function call_lp {
  TMPFILE=`mktemp`
  # avoid hitting rate limit
  sleep 1
  URL="https://app.liquidplanner.com/api/${1}"
  # use -g to avoid problems with [] in url.
  STATUS=$(curl -u "${API_USER}:${API_PW}" -qgsw '%{http_code}' -o $TMPFILE -H "Content-Type: application/json" "${URL}")
  cat $TMPFILE
  rm $TMPFILE
  return $STATUS
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
ORDER BY f.start_time;
EOF

while IFS='' read -r line || [[ -n "$line" ]]; do
    TASK=$(echo $line | cut -f 1 -d \|)
    CATEGORY=$(echo $line | cut -f 2 -d \|)
    PERFORMED_ON=$(echo $line | cut -f 3 -d \|)
    HOURS=$(echo $line | cut -f 5 -d \|)
    echo Lets log $HOURS hours for task $TASK - $CATEGORY.
done < $TMPFILE

rm $TMPFILE

echo Package: ${MAP_chirocivi[package]}

# call_lp $1

# track time:
# curl -X POST -H "Content-Type: application/json" -gu "${API_USER}:${API_PW}" https://app.liquidplanner.com/api/workspaces/103787/tasks/34108034/track_time -d '{"work":1,"activity_id":139977}'
