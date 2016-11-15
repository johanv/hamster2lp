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
  STATUS=$(curl -u "${API_USER}:${API_PW}" -qsw '%{http_code}' -o $TMPFILE -H "Content-Type: application/json" https://app.liquidplanner.com/api/$1)
  cat $TMPFILE
  rm $TMPFILE
  return $STATUS
}

call_lp 'account'

echo Status $?
