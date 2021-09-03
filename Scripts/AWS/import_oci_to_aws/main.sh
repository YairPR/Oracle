#***************************************************************************************************
#@autor: Eddie Yair Purisaca Rivera
#@Fecha: 10-07-2018
#@Descripcion:  Bash scriptrealiza el import del dmp de la data de oracle hacia aws
#***************************************************************************************************
#!/bin/ksh
#set -x
#Ingresar como root
#sudo su;

#************************************************************
#            Parametros de entrada
#************************************************************

build_id=$1
rds_sid=$2
steps=$3
old_dump=$4

DATE_MIGRATION=`date '+%Y-%m-%d-%H-%M-%S'`
LOG_FILE=/home/ec2-user/utec/app-logs/current-import-$build_id-$DATE_MIGRATION.log

#************************************************************
#            Variables de entorno oracle
#************************************************************

export PERL5LIB=/root/perl5/lib/perl5
export PATH=/root/perl5/bin:/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin:/root/bin
export ORACLE_BASE=/home/ec2-user/oracle_tools/oracle
export ORACLE_HOME=$ORACLE_BASE/instantclient_11_2
export PATH=$ORACLE_HOME:$PATH
export TNS_ADMIN=$HOME/etc
export LD_LIBRARY_PATH=$ORACLE_HOME
export DIR_DUMP=/home/ec2-user/oracle_dump

export JAVA_HOME=/home/ec2-user/utec/app-core/jdk1.8.0_151
export PATH=$PATH:$JAVA_HOME/bin

aws_access_key=$(grep aws.access.key /home/ec2-user/utec/app-devops/edu_oracle_to_aws/params.properties |cut -d'=' -f2)
aws_secret_key=$(grep aws.secret.key /home/ec2-user/utec/app-devops/edu_oracle_to_aws/params.properties |cut -d'=' -f2)
utec_user=$(grep $rds_sid'.'app.user /home/ec2-user/utec/app-devops/edu_oracle_to_aws/params.properties |cut -d'=' -f2)
utec_user_password=$(grep $rds_sid'.'app.pass /home/ec2-user/utec/app-devops/edu_oracle_to_aws/params.properties |cut -d'=' -f2)
desarrollo_user_password=$(grep desarrollo /home/ec2-user/utec/app-devops/edu_oracle_to_aws/params.properties |cut -d'=' -f2)

date1=$(date +"%s")

rds_host=$rds_sid".cl2cyff2cklb.us-west-2.rds.amazonaws.com"
rds_port=1521
rds_user=$(grep $rds_sid'.'dba.user /home/ec2-user/utec/app-devops/edu_oracle_to_aws/params.properties |cut -d'=' -f2)
rds_password=$(grep $rds_sid'.'dba.pass /home/ec2-user/utec/app-devops/edu_oracle_to_aws/params.properties |cut -d'=' -f2)

echo ""
echo ""
echo "Parameters"
echo ""
#whoami
#echo $PATH
echo "host: $rds_host"
echo "rds_sid: $rds_sid"
echo "app user: $utec_user"
echo "dba user: $rds_user"
echo "dba password: ****"
echo ""
echo ""
#echo "Disk Space"
#df -h

db_statuscheck() {

DB_HostName=$rds_host
DB_Port=$rds_port
DB_SID=$rds_sid
DB_UserName=$rds_user
DB_Password=$rds_password
DB_Password_cut=${rds_password:0:3}

        printf "\n`date` :Checking DB connectivity...";
        printf "\n`date` :Trying to connect "${DB_UserName}"/"${DB_Password_cut}"@"${DB_SID}" ..."
        printf "\nexit" | sqlplus "${DB_UserName}/${DB_Password}@(DESCRIPTION=(ADDRESS_LIST=(ADDRESS=(PROTOCOL=TCP)(HOST=${DB_HostName})(PORT=${DB_Port})))(CONNECT_DATA=(SERVER=DEDICATED)(SERVICE_NAME=${DB_SID})))" > /dev/null
        if [ $? -eq 0 ]
        then
                DB_STATUS="UP"
                export DB_STATUS
                printf "\n`date` :Status: ${DB_STATUS}. Able to Connect..."
        else
                DB_STATUS="DOWN"
                export DB_STATUS
                printf "\n`date` :Status: DOWN . Not able to Connect."
                printf "\n`date` :Not able to connect to database with Username: "${DB_UserName}" Password: "${DB_Password_cut}" DB HostName: "${DB_HostName}" DB Port: "${DB_Port}" SID: "${DB_SID}"."
                printf "\n`date` :Exiting Script Run..."
                exit 1
        fi
}



runsql() {

DB_HostName=$rds_host
DB_Port=$rds_port
DB_SID=$rds_sid
DB_UserName=$rds_user
DB_Password=$rds_password
SQL_script=$6

        printf "\n`date` :Checking DB status..."
        db_statuscheck $rds_host $rds_port $rds_sid $rds_user $rds_password

        if [[ "$DB_STATUS" == "DOWN" ]] ; then
                printf "\n`date` :DB status check failed..."
                printf "\n`date` :Skipping to run extra sqls and exiting..."
                exit 1
        fi

        printf "\n`date` :DB status check completed"
        printf "\n`date` :Connecting To ${DB_UserName}/******@${DB_SID}";

        if [[ "$DB_STATUS" == "UP" ]] ; then

                printf "\n`date` :Executing file $file..."
                printf "\n`date` :__________________________________________";
                printf "\n`date` :SQL OUTPUT:";
                printf "\n`date` :__________________________________________\n\n";
                sqlplus -s ""${rds_user}"/"${rds_password}"@(DESCRIPTION=(ADDRESS_LIST=(ADDRESS=(PROTOCOL=TCP)(HOST="${rds_host}")(PORT="${rds_port}")))(CONNECT_DATA=(SERVER=DEDICATED)(SERVICE_NAME="${rds_sid}")))" <<EOF
                @$SQL_script;
                commit;
                quit;

EOF

                if [ $? -eq 0 ]
                then
                        printf "\n`date` :completed running sqls."
                else
                        printf "\n`date` :Failed when executing sql..."
                        exit 1
                fi

        else
                printf "\n`date` :Either the DB is down or the exit status returned by script shows ERROR."
                printf "\n`date` :Exiting ..."
                exit 1
        fi

}

runsqlWithPositionArguments() {

SQL_script=$1

        printf "\n`date` :Checking DB status..."
        db_statuscheck $rds_host $rds_port $rds_sid $rds_user $rds_password

        if [[ "$DB_STATUS" == "DOWN" ]] ; then
                printf "\n`date` :DB status check failed..."
                printf "\n`date` :Skipping to run extra sqls and exiting..."
                exit 1
        fi

        printf "\n`date` :DB status check completed"
        printf "\n`date` :Connecting To ${DB_UserName}/******@${DB_SID}";

        if [[ "$DB_STATUS" == "UP" ]] ; then

                printf "\n`date` :Executing file $file..."
                printf "\n`date` :__________________________________________";
                printf "\n`date` :SQL OUTPUT:";
                printf "\n`date` :Params:$@";
                printf "\n`date` :__________________________________________\n\n";
                sqlplus -s ""${rds_user}"/"${rds_password}"@(DESCRIPTION=(ADDRESS_LIST=(ADDRESS=(PROTOCOL=TCP)(HOST="${rds_host}")(PORT="${rds_port}")))(CONNECT_DATA=(SERVER=DEDICATED)(SERVICE_NAME="${rds_sid}")))" <<EOF
                @$SQL_script $@;
                commit;
                quit;

EOF

                if [ $? -eq 0 ]
                then
                        printf "\n`date` :completed running sqls."
                else
                        printf "\n`date` :Failed when executing sql..."
                        exit 1
                fi

        else
                printf "\n`date` :Either the DB is down or the exit status returned by script shows ERROR."
                printf "\n`date` :Exiting ..."
                exit 1
        fi

}

runplsql() {

DB_HostName=$rds_host
DB_Port=$rds_port
DB_SID=$rds_sid
DB_UserName=$rds_user
DB_Password=$rds_password
SQL_script=$6
DMP_file=$7
JOB_NAME="$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)"

        echo "`date` :Checking DB status..."
        db_statuscheck $rds_host $rds_port $rds_sid $rds_user $rds_password
        if [[ "$DB_STATUS" == "DOWN" ]] ; then
                echo "`date` :DB status check failed..."
                echo "`date` :Skipping to run extra sqls and exiting..."
                exit
        fi

        echo "`date` :DB status check completed"
        echo "`date` :Connecting To ${DB_UserName}/******@${DB_SID}";

        if [[ "$DB_STATUS" == "UP" ]] ; then

                echo "`date` :Executing file $file..."
                echo "`date` :__________________________________________";
                echo "`date` :SQL OUTPUT:";
                echo "`date` :__________________________________________";
                sqlplus -s ""${rds_user}"/"${rds_password}"@(DESCRIPTION=(ADDRESS_LIST=(ADDRESS=(PROTOCOL=TCP)(HOST="${rds_host}")(PORT="${rds_port}")))(CONNECT_DATA=(SERVER=DEDICATED)(SERVICE_NAME="${rds_sid}")))" <<EOF
                @$SQL_script $JOB_NAME $DMP_file $DATE_MIGRATION;
                commit;
                quit;
                echo "`date` :__________________________________________";

EOF

                if [ $? -eq 0 ]
                then
                        printf "\n`date` :completed running sqls."
                else
                        printf "\n`date` :Failed when executing sql..."
                        exit 1
                fi

        else
                echo "`date` :Either the DB is down or the exit status returned by script shows ERROR."
                echo "`date` :Exiting ..."
                exit
        fi

}


## main process
(

        bash /home/ec2-user/utec/app-devops/edu_oracle_to_aws/intro_message.sh

        echo -e "\n\nDatabase connection check ...\n"

        echo -e "\n\n5 STEPS\n"
        db_statuscheck $rds_host $rds_port $rds_sid $rds_user $rds_password

        if [[ $steps == *"0"* ]]; then

                date_begin=$(date +"%s")
                echo -e "\n\nSTEP 0 : Delete and create oracle database in aws ..."

    java -jar /home/ec2-user/utec/app-devops/edu_oracle_to_aws/amazon-rds-util-jar-with-dependencies.jar $aws_access_key $aws_secret_key $rds_sid $rds_user $rds_password "recreate"

                if [ $? -ne 0 ]; then
                        exit 1
                fi

                date_end=$(date +"%s")
                diff=$(($date_end-$date_begin))
                printf "\nElapsed time: $(($diff / 60)) minutes and $(($diff % 60)) seconds elapsed."
                echo -e "\n>>>>>success!!"
                echo -e "step 0: success" >> $LOG_FILE

        fi

        if [[ $steps == *"1"* ]]; then

                #************************************************************
                #                Validacion de Archivo DMP
                #************************************************************
                cd $DIR_DUMP

                fec=$(date +'%Y%m%d')
                getfile=$(find -name "*$fec.gz" -mtime 0  -printf "%f\n")

                if [ -e "$getfile" ]
                then
                        dump_file_name_path=$DIR_DUMP/$getfile
                        export dump_file_name_path=$dump_file_name_path
                        dump_file_name="production_data_$(date +'%d_%m_%Y').dmp.gz"
                        export dump_file_name=$dump_file_name
                        dump_file_dir=$(dirname "${dump_file_name_path}")
                        export dump_file_dir=$dump_file_dir

                        ext=".gz"
                        decompressed_dump_finename=${dump_file_name/$ext/}
                        export decompressed_dump_finename=$decompressed_dump_finename

                else
                        echo ""
                        echo ""
                        echo ""
                        echo "AWS Archivo dmp no existe"
                        echo "Use one o the following dumps:"
                        ls -la $DIR_DUMP
                        echo "-----------------"
                        if [ -z "$old_dump" ]
                        then
                              echo "old dump name is not configured."
                              echo "Please contact to Richard Leon or try again adding a parameter called old_dump_name"
                              echo "Example bash ../../main.sh coreqa5 12345 bdUTEC_Core_20190403.gz"
                              echo "This value bdUTEC_Core_20190403.gz will be founded at the top of log. See <Use one o the following dumps> section"
                                                exit 1
                        else
                              echo "old dump name is configured as PLAN B: $old_dump"

                                                dump_file_name_path=$DIR_DUMP/$old_dump
                                                export dump_file_name_path=$dump_file_name_path
                                                dump_file_name="production_data_$(date +'%d_%m_%Y').dmp.gz"
                                                export dump_file_name=$dump_file_name
                                                dump_file_dir=$(dirname "${dump_file_name_path}")
                                                export dump_file_dir=$dump_file_dir

                                                ext=".gz"
                                                decompressed_dump_finename=${dump_file_name/$ext/}
                                                export decompressed_dump_finename=$decompressed_dump_finename
                        fi
                fi

    date_begin=$(date +"%s")
                echo -e "\n\nSTEP 1 : Decompresing... : $dump_file_dir/$dump_file_name"

                cp $dump_file_name_path "$dump_file_dir/$dump_file_name"
                gzip -d "$dump_file_dir/$dump_file_name" -f
                ls -la $dump_file_name_path
                if [ $? -ne 0 ]; then
                        exit 1
                fi

                date_end=$(date +"%s")
                diff=$(($date_end-$date_begin))
                printf "\nElapsed time: $(($diff / 60)) minutes and $(($diff % 60)) seconds elapsed."
                echo -e "\n>>>>>success!!"
                echo -e "step 1: success" >> $LOG_FILE
        fi

        if [[ $steps == *"2"* ]]; then

                date_begin=$(date +"%s")
                echo -e "\n\nSTEP 2 : Upload dump file from ec2 bridge to rds ..."
                echo $dump_file_dir/$decompressed_dump_finename
                perl /home/ec2-user/utec/app-devops/edu_oracle_to_aws/02_upload_datapumpdir.pl  $rds_port $rds_host $rds_user/$rds_password $rds_sid $dump_file_dir/$decompressed_dump_finename
                if [ $? -ne 0 ]; then
                        exit 1
                fi

                date_end=$(date +"%s")
                diff=$(($date_end-$date_begin))
                printf "\nElapsed time: $(($diff / 60)) minutes and $(($diff % 60)) seconds elapsed."
                echo -e "\n>>>>>success!!"
                echo -e "step 2: success" >> $LOG_FILE

        fi

        if [[ $steps == *"3"* ]]; then

                date_begin=$(date +"%s")
                cd /home/ec2-user/utec/app-devops/edu_oracle_to_aws
                echo -e "\n\nSTEP 3 : Initialize database schemes,users,etc ..."
                runsql $rds_host $rds_port $rds_sid $rds_user $rds_password "/home/ec2-user/utec/app-devops/edu_oracle_to_aws/03_initialize_db.sql"

                date_end=$(date +"%s")
                diff=$(($date_end-$date_begin))
                printf "\nElapsed time: $(($diff / 60)) minutes and $(($diff % 60)) seconds elapsed."
                echo -e "\n>>>>>success!!"
                echo -e "step 3: success" >> $LOG_FILE
        fi

        if [[ $steps == *"4"* ]]; then

                date_begin=$(date +"%s")
                cd /home/ec2-user/utec/app-devops/edu_oracle_to_aws
                echo -e "\n\nSTEP 4 : Execute DBMS_DATAPUMP in RDS ..."
                runplsql $rds_host $rds_port $rds_sid $utec_user $utec_user_password "/home/ec2-user/utec/app-devops/edu_oracle_to_aws/04_execute_dbms_datapump.sql" $decompressed_dump_finename $DATE_MIGRATION

                date_end=$(date +"%s")
                diff=$(($date_end-$date_begin))
                printf "\nElapsed time: $(($diff / 60)) minutes and $(($diff % 60)) seconds elapsed."
                echo -e "\n>>>>>success!!"
                echo -e "step 4: success" >> $LOG_FILE
        fi

        if [[ $steps == *"5"* ]]; then

                date_begin=$(date +"%s")
                cd /home/ec2-user/utec/app-devops/edu_oracle_to_aws
                echo -e "\n\nSTEP 5 : Execute sql after import ..."
                runsqlWithPositionArguments "/home/ec2-user/utec/app-devops/edu_oracle_to_aws/05_post_import.sql" $utec_user_password $desarrollo_user_password

                date_end=$(date +"%s")
                diff=$(($date_end-$date_begin))
                printf "\nElapsed time: $(($diff / 60)) minutes and $(($diff % 60)) seconds elapsed."
                echo -e "\n>>>>>success!!"
                echo -e "step 5: success" >> $LOG_FILE
        fi

)
STATUS_FINAL=$?

if [ -f $dump_file_dir/$dump_file_name ]; then
        echo "remove tmp dmp file : $dump_file_dir/$decompressed_dump_finename"
        #rm -f $dump_file_dir/$decompressed_dump_finename
fi

echo ""

if [ $STATUS_FINAL -eq 0 ]; then
        bash  /home/ec2-user/utec/app-devops/edu_oracle_to_aws/sucess_message.sh

        date2=$(date +"%s")
        diff=$(($date2-$date1))

        printf "\n#################################"
        printf "\nELAPSED TIME $(($diff / 60)) minutes and $(($diff % 60)) seconds elapsed."
        printf "\n#################################"
        printf "\n"
        echo "STATUS_COMPLETED"
        exit 0
else
        sh /home/ec2-user/utec/app-devops/edu_oracle_to_aws/failed_message.sh

        date2=$(date +"%s")
        diff=$(($date2-$date1))

        printf "\n#################################"
        printf "\nELAPSED TIME $(($diff / 60)) minutes and $(($diff % 60)) seconds elapsed."
        printf "\n#################################"
        printf "\n"
        echo "STATUS_ERROR"
        echo "STATUS_ERROR" >> $LOG_FILE
        exit 1
fi

exit
