#!/bin/bash

# t2lp.sh - pushes pending taskwarrior tasks to liquidplanner.

# Copyright 2016 Johan Vervloet
# You can use this under the terms of GNU GPL v3.
# https://www.gnu.org/licenses/gpl-3.0.en.html

SCRIPTDIR=`dirname ${0}`
source $SCRIPTDIR/h2lp-lib.sh

task export | jq '.[] | select(.status == "pending") | (.description,.project)' | while read TASK
do
  read PROJECT
  # strip enclosing quotes, and remove strange characters
  # like it's done when pushing tasks from taskwarrior to hamster.

  TASK=$(echo $TASK | sed 's/^"\(.*\)"$/\1/g' | tr '()#[]-' '______')
  PROJECT=$(echo $PROJECT | sed 's/^"\(.*\)"$/\1/g' | tr '()#[]-' '______')

  LP_TASK=$(get_or_create_lp_task "${TASK}" "${PROJECT}")

  echo $LP_TASK : $PROJECT - $TASK
done
