REM ============================================================
REM NAME                           PASSWORD
REM ------------------------------ -----------------
REM APP_CVX                        D3968F8EF465FDEA
REM APP_INTERFACE                  B1B48A30A9CD862B
REM UCONEX00                       DB7741505C25EF07
REM ============================================================

REM ============================================================
REM OBTIENE LA FECHA DE EJECUCIÓN
REM ============================================================
@For /F "tokens=1,2,3,4 delims=/ " %%A in ('Date /t') do @( 
    Set Dia=%%A
	Set Day=%%C
    Set Month=%%B
    Set Year=%%D
)
@echo Dia = %Day%
@echo Day = %Day%
@echo Month = %Month%
@echo Year = %Year%

@For /F "tokens=1,2,3 delims=: " %%a in ('Time /t') do @( 
    Set HORA=%%a
	Set MIN=%%b
    Set HH=%%c
)
@echo HORA = %HORA%

alter database backup controlfile to 'D:\backup\BDINVER\control_bdinver.bkp';

select UPPER(a.host_name) host, UPPER(a.instance_name) INSTANCIA, a.version, a.status, b.DATABASE_ROLE, b.LOG_MODE, b.OPEN_MODE,
d.datos + t.temp TOTAL_BD_DISCO_GB, u.usado TOTAL_USADO_GB 
from v$instance a,
v$database b,
(SELECT ROUND(sum(bytes)/1024/1024/1024,2) datos 
 from dba_data_files) d,
 (select ROUND(sum(bytes)/1024/1024/1024,2) temp from dba_temp_files) t,
  (SELECT ROUND(sum(bytes)/1024/1024/1024,2) usado from dba_segments) u;
@echo MIN = %MIN%
@echo HH = %HH%
REM ============================================================
REM SETEO VARIABLES
REM ============================================================
set ORACLE_SID=BDINVER
set ORACLE_HOME=D:\oracle\product\11.2.0.4\dbhome
set PATH=%PATH%:D:\oracle\product\11.2.0.4\dbhome\bin
set NLS_LANG=american_america.WE8ISO8859P1
set TNS_ADMIN=D:\oracle\product\11.2.0.4\dbhome\NETWORK\ADMIN
SET user=MANTENIMIENTO
SET pass=mn2013mn
set DIR_DMP_EXPORT=D:\BACKUP\BDINVER\DATA\
REM ============================================================
REM INICIO DE BACKUP
REM ============================================================
cd D:\BACKUP\BDINVER\DATA\
D:
rm SCHEMAS_BDINVER*.dmp
rm SCHEMAS_BDINVER*.DMP
expdp %user%/%pass% schemas=UCONEX00, APP_CVX,APP_INTERFACE directory=PMS_DUMP dumpfile=SCHEMAS_BDINVER_%Year%.%Month%.%Day%_%HORA%.%MIN%_%%U.dmp  logfile=SCHEMAS_BDINVER_%Year%.%Month%.%Day%_%HORA%.%MIN%.log EXCLUDE=statistics content=all  parallel=4
REM ============================================================
REM INICIO DE COPIA
REM ============================================================
net use W: \\rssibdinver02\Backup /user:rssibdinver02\oracle p4ssw0rd$1
ROBOCOPY D:\backup\BDINVER\data W: SCHEMAS_BDINVER_%Year%.%Month%.%Day%_%HORA%.%MIN%_*.DMP /z /R:1 /W:0 /LOG:D:\backup\LOG_Robocopy\log_%Year%.%Month%.%Day%_%HORA%.%MIN%.log
net use  W: /delete /y
