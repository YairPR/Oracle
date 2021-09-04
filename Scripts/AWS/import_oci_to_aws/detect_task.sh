
#!/bin/bash
file=/home/ec2-user/oracle_dump/new_task
detect_task_log=/home/ec2-user/oracle_dump/detect_task.log

echo "" >>  $detect_task_log
echo "" >>  $detect_task_log
echo "Script starting" >>  $detect_task_log
echo "File to review:$file" >>  $detect_task_log
date >>  $detect_task_log
whoami >>  $detect_task_log

if [ -e "$file" ]; then

    migration_id=$(grep migration_id $file |cut -d'=' -f2)
    database=$(grep database $file |cut -d'=' -f2)
    steps=$(grep steps $file |cut -d'=' -f2)
    log_file=/home/ec2-user/utec/app-logs/current_import_$migration_id.log

    date >> $detect_task_log
    echo "New Task detected: $database : $steps">> $detect_task_log
    rm -rf $file

    echo "Date start at:"  > $log_file
    date  >> $log_file
    bash /home/ec2-user/utec/app-devops/edu_oracle_to_aws/main.sh $database $steps >> $log_file
else
    date >> $detect_task_log
    echo "No task detected" >> $detect_task_log
fi
