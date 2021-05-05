How To Generate AWR Report In RAC

AWR report can be generating in RAC database using 2 scripts awrrpt.sql or awrrpti.sql

awrrpt.sql – > This will generate the one report for the database across all the nodes(i.e for all instances) for a partiular snapshot range.

awrrpti.sql – > This will genereate report for a particular instance, i.e for a 2 node RAC database , there will be two reports( one for each instance).

USING AWRRPT.SQL SCRIPT:

SQL> @$ORACLE_HOME/rdbms/admin/awrrpt.sql

SQL> @$ORACLE_HOME/rdbms/admin/awrrpti.sql

Specify the Report Type
~~~~~~~~~~~~~~~~~~~~~~~
AWR reports can be generated in the following formats. Please enter the
name of the format at the prompt. Default value is 'html'.

'html' HTML format (default)
'text' Text format
'active-html' Includes Performance Hub active report

Enter value for report_type:

Type Specified: html


Instances in this Workload Repository schema
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

DB Id Inst Num DB Name Instance Host
------------ -------- ------------ ------------ ------------
229213524 2 CLPRE CLPRE2 local95-2
* 229213524 1 CLPRE CLPRE1 local94-2

Enter value for dbid: 229213524
Using 229213524 for database Id
Enter value for inst_num: 1 ------------------->>> Here you need to the pass the instance number
Using 1 for instance number

