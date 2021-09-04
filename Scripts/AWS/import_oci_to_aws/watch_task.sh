#!/bin/bash

LOG_FILE=/home/ec2-user/utec/app-logs/current_import_$1.log
touch $LOG_FILE
set +x
has_started=true
current_lines=0
while true; do
  # echo "waiting for download, compile and deploy status...";
  sleep 5;

  if [[ "$has_started" == *"true"* ]]; then
    lines=$(wc -l $LOG_FILE | cut -d' ' -f1)
    current_lines=$lines
    has_started=false
    tail $LOG_FILE
  else
    lines=$(wc -l $LOG_FILE | cut -d' ' -f1)
    new_lines=$(($lines-$current_lines))
    current_lines=$lines
    tail -$new_lines $LOG_FILE
  fi


  # status=$(grep -rnw $LOG_FILE -e 'STATUS_COMPLETED')
  # status2=$(grep -rnw $LOG_FILE -e 'STATUS_ERROR')
  STATUS_COMPLETED=$(grep STATUS_COMPLETED $LOG_FILE)
  STATUS_ERROR=$(grep STATUS_ERROR $LOG_FILE)

  if [[ "$STATUS_COMPLETED" == *"STATUS_COMPLETED"* ]]; then
    echo "STATUS : COMPLETED"
    break
  else
      if [[ "$STATUS_ERROR" == *"STATUS_ERROR"* ]]; then
        echo "STATUS : ERROR"
        break
      fi
  fi
done
