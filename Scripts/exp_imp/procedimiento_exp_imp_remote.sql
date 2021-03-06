RUTA: /u01/app/oracle/dmp
--- export IGWDES  TMP_RECEP_CARGO 
exp e06993/gegm190320@172.30.8.42:1521/igwprd file=igwprd01.dmp log=igwprd01.log tables=USRMBE00.tmp_recep_cargo query=\"where rownum \<600000\"

:Validacion de estructura de las tablas en ambos ambientes
-- conexion a prod
sqlplus e06993/gegm190320@172.30.8.42:1521/igwprd

dec  USRMBE00.cargo; (PROD y DES)

: Validacion de registro en IGWDES
SQL> select count(*) from USRMBE00.tmp_recep_cargo;

  COUNT(*)
----------
    561186

SQL> select name from v$database;

NAME
---------
IGWDES

: TRUNCATE table en IGWDES
SQL> truncate USRMBE00.tmp_recep_cargo;
truncate USRMBE00.tmp_recep_cargo
                 *
ERROR at line 1:
ORA-03290: Invalid truncate command - missing CLUSTER or TABLE keyword


SQL> truncate table USRMBE00.tmp_recep_cargo drop storage;

Table truncated.

======================================================================
USMBPR00.cargo
Para tabla CARGO:
select * from cargo where rownum< 600000 order by feccargo desc;
=====================================================================
--- export IGWDES  TMP_RECEP_CARGO 
exp e06993/gegm190320@172.30.8.42:1521/igwprd file=igwprd01_USMBPR00_cargo.dmp log=igwprd01_USMBPR00_cargo.log tables=USMBPR00.cargo query=\"where rownum \<600000\"

: VALIDACION ESTRUCTURA PROD - DES
descripcion de tablas prod y des
-- conexion a prod
sqlplus e06993/gegm190320@172.30.8.42:1521/igwprd

-- conteo de regsitros
select count(*) from USRMBE00.cargo;

-- truncate table desarrollo
truncate table USMBPR00.cargo drop storage;

--: Import 
imp e06993/gegm190320 file=igwprd01_USMBPR00_cargo.dmp log=imp_USMBPR00_cargo.log  full=yes ignore=yes grants=no


===================================================================
USMBPR00.matricula
Para tabla MATRICULA:
select * from matricula m where rownum<600000order by m.feccrea desc;
=====================================================================

--- export IGWDES  MATRICULA:
exp e06993/gegm190320@172.30.8.42:1521/igwprd file=igwprd01_USMBPR00_matricula.dmp log=igwprd01_USMBPR00_matricula.log tables=USMBPR00.matricula query=\"where rownum \<600000\"

: VALIDACION ESTRUCTURA PROD - DES
descripcion de tablas prod y des
-- conexion a prod
sqlplus e06993/gegm190320@172.30.8.42:1521/igwprd

-- conteo de regsitros
select count(*) from USMBPR00.matricula;

-- truncate table desarrollo
truncate table USMBPR00.matricula drop storage;

--: Import 
imp e06993/gegm190320 file=igwprd01_USMBPR00_cargo.dmp log=imp_USMBPR00_cargo.log  full=yes ignore=yes grants=no

sqlplus e06993/gegm190320@172.30.8.42:1521/igwprd

--
connect e06993/gegm190320
dec  USRMBE00.cargo; (PROD y DES)

Error:
ERROR at line 1:
ORA-02266: unique/primary keys in table referenced by enabled foreign keys

-- Revisar dependencias

SELECT p.owner, p.table_name "Parent Table", c.table_name "Child Table",
p.constraint_name "Parent Constraint", c.constraint_name "Child Constraint"
FROM all_constraints p
JOIN all_constraints c ON(p.constraint_name=c.r_constraint_name)
WHERE (p.constraint_type = 'P' OR p.constraint_type = 'U')
AND c.constraint_type = 'R'
--AND p.OWNER = ''
AND p.table_name = UPPER('&table_name');

===================================================================
USMBPR00.rmen_cargo
Para tabla RMEN_CARGO:
select * from USMBPR00.rmen_cargo rc where exists(select 1 from USMBPR00.matricula m where rc.codmatric = m.codmatric) and rownum < 600000;
=====================================================================
select count(*) from USMBPR00.rmen_cargo rc where exists(select 1 from USMBPR00.matricula m where rc.codmatric = m.codmatric) and rownum < 600000;

-- create table temporal en prod
create table e06993.tmp_exp_rem_cargo as
select * from USMBPR00.rmen_cargo rc where exists(select 1 from USMBPR00.matricula m where rc.codmatric = m.codmatric) and rownum < 600000;

exp e06993/gegm190320@172.30.8.42:1521/igwprd file=igwprd01_e06993_tmp_exp_rem_cargo.dmp log=igwprd01_e06993_tmp_exp_rem_cargo.log tables=e06993.tmp_exp_rem_cargo

··············································································
parfile:
file=igwprd01_USMBPR00_rmen_cargo.dmp
log=igwprd01_USMBPR00_rmen_cargo.log
tables=USMBPR00.rmen_cargo
query=USMBPR00.rmen_cargo:"where exists(select 1 from USMBPR00.matricula where rmen_cargo.codmatric = matricula.codmatric) and rownum < 600000"

exp e06993/gegm190320@172.30.8.42:1521/igwprd 
··············································································

: VALIDACION ESTRUCTURA PROD - DES
descripcion de tablas prod y des
sqlplus e06993/gegm190320@172.30.8.42:1521/igwprd
--
connect e06993/gegm190320
dec e06993.tmp_exp_rem_cargo; (PROD y DES)

-- conteo de regsitros
select count(*) from e06993.tmp_exp_rem_cargo;

-- truncate table desarrollo
truncate table USMBPR00.rmen_cargo drop storage;

--
set line 300
SELECT p.owner, p.table_name "Parent Table", c.table_name "Child Table",
p.constraint_name "Parent Constraint", c.constraint_name "Child Constraint"
FROM all_constraints p
JOIN all_constraints c ON(p.constraint_name=c.r_constraint_name)
WHERE (p.constraint_type = 'P' OR p.constraint_type = 'U')
AND c.constraint_type = 'R'
--AND p.OWNER = ''
AND p.table_name = UPPER('&table_name');

OWNER                          Parent Table                   Child Table                    Parent Constraint              Child Constraint
------------------------------ ------------------------------ ------------------------------ ------------------------------ ------------------------------
USMBPR00                       RMEN_CARGO                     FILTRO_RMEN_CARGO              PK_RMEN_CARGO                  FK_RMEN_CARGO_01
USMBPR00                       RMEN_CARGO                     COBRO                          PK_RMEN_CARGO                  FK_RMEN_CARGO_02

-- desactivamos constraint
alter table USMBPR00.FILTRO_RMEN_CARGO disable constraint FK_RMEN_CARGO_01;
alter table USMBPR00.COBRO disable constraint FK_RMEN_CARGO_02;

--: Import 
imp e06993/gegm190320 file=igwprd01_e06993_tmp_exp_rem_cargo.dmp log=imp_tmp_exp_rem_cargo.log  full=yes ignore=yes grants=no

insert into USMBPR00.rmen_cargo ( SECDOCCOBRO,IDEPOL,CODMATRIC,NUMDOCCOB ,CODORGNSIST,TIPOPROC,FECCARGO,INDPAGCTA,CODCLI,CODPROD,CODCANAL,NUMOBJASEG,
CODMONEDA, IMPORTEDOC,FECVNCTOCUOTA,TASACAMBIO,STSREGCOBRO, NUMLOTEENVIO,NUMLOTERECEP,CODERROR,DTOSRFRC ,NUMRELING,              
 NUMRELINGTEMPORAL,CODUSRCREA,ORGNRELING ,FECCOBRO,NUMPOL,SECCARGO,STSDOC,FECULTMOD,USRULTMOD,CANTREINTENTOATMCO  )
SELECT * FROM e06993.tmp_exp_rem_cargo;

commit;

-- activamos constraint
alter table USMBPR00.FILTRO_RMEN_CARGO enable constraint FK_RMEN_CARGO_01;
alter table USMBPR00.COBRO enable constraint FK_RMEN_CARGO_02;

===================================================================
USMBPR00.ctrl_lote
Para tabla CTRL_LOTE:
select * from ctrl_lote where rownum<600000 order by fecgenproc desc;
=====================================================================

--- export IGWDES  CTRL_LOTE:
exp e06993/gegm190320@172.30.8.42:1521/igwprd file=igwprd01_USMBPR00_ctrl_lote.dmp log=igwprd01_USMBPR00_ctrl_lote.log tables=USMBPR00.ctrl_lote query=\"where rownum \<600000\"

: VALIDACION ESTRUCTURA PROD - DES
descripcion de tablas prod y des
-- conexion a prod
sqlplus e06993/gegm190320@172.30.8.42:1521/igwprd

connect e06993/gegm190320

-- conteo de regsitros
select count(*) from USMBPR00.ctrl_lote;

-- truncate table desarrollo
truncate table USMBPR00.ctrl_lote drop storage;

--: Import 
imp e06993/gegm190320 file=igwprd01_USMBPR00_ctrl_lote.dmp log=imp_USMBPR00_ctrl_lote.log  full=yes ignore=yes grants=no



===================================================================
USMBCT00.cfg_error
Para tabla CFG_ERROR:
select * from cfg_error;
=====================================================================

--- export IGWDES  CTRL_LOTE:
exp e06993/gegm190320@172.30.8.42:1521/igwprd file=igwprd01_USMBCT00_cfg_error.dmp log=igwprd01USMBCT00_cfg_error.log tables=USMBCT00.cfg_error 

: VALIDACION ESTRUCTURA PROD - DES
descripcion de tablas prod y des
-- conexion a prod
sqlplus e06993/gegm190320@172.30.8.42:1521/igwprd

connect e06993/gegm190320

-- conteo de regsitros
select count(*) from USMBPR00.ctrl_lote;

-- truncate table desarrollo
truncate table USMBCT00.cfg_error drop storage;

Error:
ERROR at line 1:
ORA-02266: unique/primary keys in table referenced by enabled foreign key

-- Revisar dependencias

set line 300
SELECT p.owner, p.table_name "Parent Table", c.table_name "Child Table",
p.constraint_name "Parent Constraint", c.constraint_name "Child Constraint"
FROM all_constraints p
JOIN all_constraints c ON(p.constraint_name=c.r_constraint_name)
WHERE (p.constraint_type = 'P' OR p.constraint_type = 'U')
AND c.constraint_type = 'R'
--AND p.OWNER = ''
AND p.table_name = UPPER('&table_name');


OWNER                          Parent Table                   Child Table                    Parent Constraint              Child Constraint
------------------------------ ------------------------------ ------------------------------ ------------------------------ ------------------------------
USMBCT00                       CFG_ERROR                      CFG_ERROR_ENT_FINANC           PK_CFG_ERROR                   FK_CFG_ERROR_01
USDWCT00                       CFG_ERROR                      CFG_ERROR_ENT_FINANC           PK_CFG_ERROR                   FK_CFG_ERROR_01

--backup tabla referenciada
exp e06993/gegm190320 file=CFG_ERROR_ENT_FINANC_deptab.dmp log=CFG_ERROR_ENT_FINANC.log tables=USMBCT00.CFG_ERROR_ENT_FINANC     

set lines 2999
COL CHILD_TABLE FOR A20
col CONSTRAINT_NAME for a26
col owner form a10
col FK_column form a15
col table_name form a30
select b.owner, b.table_name child_table,
c.column_name FK_column, b.constraint_name
from dba_constraints a, dba_constraints b, dba_cons_columns c
where a.owner=b.r_owner
and b.owner=c.owner
and b.table_name=c.table_name
and b.constraint_name=c.constraint_name
and a.constraint_name=b.r_constraint_name
and b.constraint_type='R'
and a.owner='&owner'
and a.table_name='&TABLE_NAME'
and a.CONSTRAINT_TYPE='P'; 

OWNER      CHILD_TABLE          FK_COLUMN       CONSTRAINT_NAME
---------- -------------------- --------------- --------------------------
USMBCT00   CFG_ERROR_ENT_FINANC CODERROR        FK_CFG_ERROR_01

-- desactivamos constraint
alter table USMBCT00.CFG_ERROR_ENT_FINANC disable constraint FK_CFG_ERROR_01;

-- truncate table desarrollo
truncate table USMBCT00.cfg_error drop storage;

--: Import 
imp e06993/gegm190320 file=igwprd01_USMBCT00_cfg_error.dmp log=imp_USMBCT00_cfg_error.log  full=yes ignore=yes grants=no

-- Import tabla referenciada 
imp e06993/gegm190320 file=CFG_ERROR_ENT_FINANC_deptab.dmp log=imp_CFG_ERROR_ENT_FINANC.log  full=yes ignore=yes grants=no

-- activamos constraint
alter table USMBCT00.CFG_ERROR_ENT_FINANC enable constraint FK_CFG_ERROR_01;
