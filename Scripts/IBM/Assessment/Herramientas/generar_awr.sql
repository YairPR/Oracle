https://dbamohsin.wordpress.com/2012/07/02/generate-awr-reports-from-command-line/
https://dbaclass.com/article/generate-awr-report-oracle/

The Automatic Workload Repository (AWR) collects and maintains statistics of the database.

We can generate awr report for a particular time frame in the past using the script awrrpt.sql ( located under $ORACLE_HOME/rdbms/admin)

script – @$ORACLE_HOME/rdbms/admin/awrrpt.sql

conn / as sysdba

SQL> @$ORACLE_HOME/rdbms/admin/awrrpt.sql


For NON-SYSDBA USERS, BELOW GRANTS ARE REQUIRED TO GENERATE AWR REPORT:
SQL> grant connect,SELECT_CATALOG_ROLE to support_id;

SQL> grant execute on dbms_workload_repository to support_id;


HOME / ORACLE RAC, PERFORMANCE TUNING / HOW TO GENERATE AWR REPORT IN RAC
How To Generate AWR Report In RAC
5462 views 1 min , 54 sec read 0

AWR report can be generating in RAC database using 2 scripts awrrpt.sql or awrrpti.sql

awrrpt.sql – > This will generate the one report for the database across all the nodes(i.e for all instances) for a partiular snapshot range.

awrrpti.sql – > This will genereate report for a particular instance, i.e for a 2 node RAC database , there will be two reports( one for each instance).

1. The awrrpt.sql SQL script generates an HTML or text report that displays statistics for a range of snapshot Ids.
2. The awrrpti.sql SQL script generates an HTML or text report that displays statistics for a range of snapshot Ids on a specified database and instance.
3. The awrsqrpt.sql SQL script generates an HTML or text report that displays statistics of a particular SQL statement for a range of snapshot Ids. Run this report to inspect or debug the performance of a SQL statement.
4. The awrsqrpi.sql SQL script generates an HTML or text report that displays statistics of a particular SQL statement for a range of snapshot Ids on a specified SQL.
5. The awrddrpt.sql SQL script generates an HTML or text report that compares detailed performance attributes and configuration settings between two selected time periods.
6. The awrddrpi.sql SQL script generates an HTML or text report that compares detailed performance attributes and configuration settings between two selected time periods on a specific database and instance.
