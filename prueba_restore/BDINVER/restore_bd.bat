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
@echo MIN = %MIN%
@echo HH = %HH%

rman catalog rcatbdinver/catalogo@bdrman target / cmdfile "restore_bd.sql" msglog "restore_bd_%Year%.%Month%.%Day%_%HORA%.%MIN%.log"

