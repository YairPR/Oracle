set echo off
set feedback on
set verify off
set serveroutput on size unlimited
set linesize 220
set pagesize 200
set long 50000
set trimspool on
set tab off

Rem ================================================================================
Rem INSTALACION ORDENADA DATAMASKING - DESCUBRIMIENTO + ENMASCARAMIENTO
Rem VERSION FF1 (NIST SP 800-38G): nucleo numerico con Cifrado que Preserva Formato
Rem                                estandar (AES-128). Solo cambia 06_dm_pkg_func_mask
Rem                                y la generacion del pepper (CSPRNG). El resto igual.
Rem ================================================================================
Rem
Rem Este archivo es una guia para SQL*Plus.
Rem - Los scripts @@ deben estar en la misma ruta de este archivo o ajustar la ruta.
Rem ================================================================================

column v_fecha new_value v_fecha
select to_char(sysdate,'YYYYMMDD_HH24MISS') v_fecha from dual;

spool install_datamasking_&v_fecha..log
Rem
Rem
Rem ----------------------------------------------------------------
Rem 1.1 PRIVILEGIOS DE SISTEMA PARA ASTSYSADMIN
Rem ----------------------------------------------------------------

grant select any dictionary to ASTSYSADMIN;
grant execute on SYS.DBMS_CRYPTO to ASTSYSADMIN;

Rem
Rem ----------------------------------------------------------------
Rem 1.2 CREACION DEL ROL 
Rem ----------------------------------------------------------------

declare
  e_role_exists exception;
  pragma exception_init(e_role_exists, -1921);
begin
  execute immediate 'create role ROL_DATAMASKING';
exception
  when e_role_exists then
    dbms_output.put_line('ROL_DATAMASKING ya existe, se reutiliza.');
end;
/

Rem
Rem ----------------------------------------------------------------
Rem 1.3 SINONIMOS PRIVADOS
Rem ----------------------------------------------------------------
Rem Los sinonimos privados ya NO se crean desde este instalador.
Rem
Rem Cada DBA debe crearlos conectado con su propio usuario:
Rem
Rem   conn <usuario>/<password>@<servicio>
Rem   @crea_sinonimos <USUARIO>
Rem ----------------------------------------------------------------
Rem
Rem ================================================================================
Rem AHORA CONECTAR COMO ASTSYSADMIN
Rem ================================================================================

ALTER SESSION SET CURRENT_SCHEMA = ASTSYSADMIN;
Rem
Rem ----------------------------------------------------------------
Rem 2.1 LIMPIEZA OPCIONAL PREVIA
Rem ----------------------------------------------------------------
Rem Si deseas reinstalar desde cero, ejecuta primero:
Rem   @@98_uninstall.sql
Rem Si no necesitas limpiar, continua con la creacion.
Rem ----------------------------------------------------------------

Rem
Rem ----------------------------------------------------------------
Rem 2.2 CREACION DE OBJETOS DE DESCUBRIMIENTO
Rem ----------------------------------------------------------------
@@01_dm_descubrimiento_objetos.sql

Rem
Rem ----------------------------------------------------------------
Rem 2.3 CREACION DE OBJETOS DE ENMASCARAMIENTO
Rem ----------------------------------------------------------------
@@02_dm_enmascaramiento_objetos.sql

Rem
Rem ----------------------------------------------------------------
Rem 2.3.1 CARGA DE SEMILLA DE SEGURIDAD (PEPPER)
Rem ----------------------------------------------------------------
Rem NOTA OPERATIVA: El pepper aleatorio hace que cada instalacion genere un pepper
Rem distinto, por lo que los valores enmascarados difieren entre entornos. Si se
Rem necesita reproducir exactamente un dump ya entregado (o que PRE coincida con
Rem otro entorno), generar el pepper una sola vez y replicar la misma fila de
Rem tdm_secreto al resto de entornos - nunca regenerarlo.
Rem NOTA FF1: El pepper ES EFIMERO POR CAMPANA (ejecucion_id). Ya NO se genera en
Rem   la instalacion. Cada campana usa su PROPIA fila clave='PEPPER_MASK:'||ejec,
Rem   de modo que dos esquemas enmascarados a la vez tienen peppers independientes
Rem   (sin carrera de creacion ni purga cruzada).
Rem   pkg_dm_enmascarar.p_dm_enmascara lo crea al inicio de cada enmascarado
Rem   (RAWTOHEX(DBMS_CRYPTO.RANDOMBYTES(32)), idempotente, COMMIT antes del paralelo).
Rem   Purga por-campana tras el export:
Rem      EXEC pkg_dm_enmascarar.p_dm_pepper_purgar(<ejecucion_id>);
Rem   Invariante: dos esquemas con FK ENTRE SI deben ir en la MISMA ejecucion.
Rem   Se comparte entre los workers paralelos via tdm_secreto durante la corrida.
Rem   Requisito: GRANT EXECUTE ON SYS.DBMS_CRYPTO (concedido en la fase de SYS).

Rem
Rem ----------------------------------------------------------------
Rem 2.4 CARGA DE REGLAS DE DESCUBRIMIENTO
Rem ----------------------------------------------------------------
@@03_dm_descubrimiento_carga_reglas.sql

Rem
Rem ----------------------------------------------------------------
Rem 2.5 CONFIGURACION DE EXCEPCIONES (OPCIONAL)
Rem ----------------------------------------------------------------
Rem Si existe el archivo y deseas cargar excepciones:
Rem   @@97_configurar_excepciones.sql
Rem ----------------------------------------------------------------
Rem ----------------------------------------------------------------
Rem 2.3 CREACION DEL PAQUETE DE DESCUBRIMIENTO
Rem ----------------------------------------------------------------
@@04_dm_pkg_descubrimiento.sql
Rem
Rem ----------------------------------------------------------------
Rem 2.7 CREACION DE PAQUETES DE ENMASCARAMIENTO
Rem ----------------------------------------------------------------
Rem Ajustar estos nombres si tus archivos reales difieren:
@@06_dm_pkg_func_mask.sql
@@05_dm_pkg_enmascarar.sql
@@07_dm_pkg_export.sql
Rem ----------------------------------------------------------------

Rem
Rem ----------------------------------------------------------------
Rem 2.8 COMPILACION Y REVISION DE ERRORES
Rem ----------------------------------------------------------------
show errors package pkg_dm_descubrimiento
show errors package body pkg_dm_descubrimiento

show errors package pkg_dm_func_mask
show errors package body pkg_dm_func_mask

show errors package pkg_dm_enmascarar
show errors package body pkg_dm_enmascarar

show errors package pkg_dm_export
show errors package body pkg_dm_export

Rem
Rem ----------------------------------------------------------------
Rem 2.9 GRANTS SOBRE OBJETOS AL ROL ROL_DATAMASKING
Rem ----------------------------------------------------------------
grant execute on pkg_dm_descubrimiento to ROL_DATAMASKING;
grant execute on pkg_dm_func_mask       to ROL_DATAMASKING;
grant execute on pkg_dm_enmascarar      to ROL_DATAMASKING;
grant execute on pkg_dm_export          to ROL_DATAMASKING;

grant select on tdm_ejecucion          to ROL_DATAMASKING;
grant select on tdm_ejecucion_scope    to ROL_DATAMASKING;
grant select on tdm_ejecucion_error    to ROL_DATAMASKING;
grant select on tdm_objeto_ctrl        to ROL_DATAMASKING;
grant select on tdm_regla              to ROL_DATAMASKING;
grant select on tdm_excepcion_col      to ROL_DATAMASKING;
grant select on tdm_columna_hist       to ROL_DATAMASKING;
grant select on tdm_dependencia_hist   to ROL_DATAMASKING;
grant select on tdm_columna_final      to ROL_DATAMASKING;
grant select on tdm_dependencia_final  to ROL_DATAMASKING;

grant select, insert, update on tdm_mask_solicitud      to ROL_DATAMASKING;
grant select, insert          on tdm_mask_trace          to ROL_DATAMASKING;
grant select, insert, update  on tdm_mask_dep_estado     to ROL_DATAMASKING;
grant select                  on tdm_mask_regla_esp      to ROL_DATAMASKING;
grant select                  on tdm_mask_relacion_sync  to ROL_DATAMASKING;
---grant select, insert, update  on tdm_mask_cache          to ROL_DATAMASKING;

grant select on seq_dm_ejecucion          to ROL_DATAMASKING;
grant select on seq_dm_ejecucion_err      to ROL_DATAMASKING;
grant select on seq_dm_ejecucion_scope    to ROL_DATAMASKING;
grant select on seq_dm_regla              to ROL_DATAMASKING;
grant select on seq_dm_columna_hist       to ROL_DATAMASKING;
grant select on seq_dm_dependencia_hist   to ROL_DATAMASKING;
grant select on seq_dm_mask_solicitud     to ROL_DATAMASKING;
grant select on seq_dm_mask_trace         to ROL_DATAMASKING;
---grant select on seq_dm_mask_resultado     to ROL_DATAMASKING;
grant select on seq_dm_mask_regla_esp     to ROL_DATAMASKING;
grant select on seq_dm_mask_relacion_sync to ROL_DATAMASKING;

Rem
Rem ================================================================================
Rem FIN FASE 2
Rem AHORA CONECTAR COMO SYS
Rem ================================================================================
Rem ================================================================================

Rem
Rem ----------------------------------------------------------------
Rem 3.1 ASIGNAR EL ROL A LOS DBA
Rem ----------------------------------------------------------------
grant ROL_DATAMASKING to ALOPEZDIAZ;
grant ROL_DATAMASKING to ACASTANGI;
grant ROL_DATAMASKING to DMIRANDA;
grant ROL_DATAMASKING to EYPURISACA;
grant ROL_DATAMASKING to ASANCLEMENTE;
grant ROL_DATAMASKING to CSOETERS;
grant ROL_DATAMASKING to ACAMING;
grant ROL_DATAMASKING to CROSS;

spool off

Rem
Rem ================================================================================
Rem FIN FASE 3
Rem VALIDACION FINAL
Rem ================================================================================
Rem Esta validacion puede ejecutarse como SYS o con un usuario con acceso a DBA_*
Rem ================================================================================

column owner          format a20
column object_name    format a30
column object_type    format a20
column status         format a12
column grantee        format a20
column table_name     format a30
column privilege      format a15
column granted_role   format a25
column synonym_name   format a30
column table_owner    format a20
column name           format a30
column type           format a18
Rem
Rem ----------------------------------------------------------------
Rem 4.1 VALIDACION DE OBJETOS DESCUBRIMIENTO
Rem ----------------------------------------------------------------

select owner, object_name, object_type, status
from dba_objects
where owner = 'ASTSYSADMIN'
  and object_name in ('PKG_DM_DESCUBRIMIENTO',
    'TDM_EJECUCION',
    'TDM_EJECUCION_SCOPE',
    'TDM_OBJETO_CTRL',
    'TDM_COLUMNA_HIST',
    'TDM_DEPENDENCIA_HIST',
    'TDM_COLUMNA_FINAL',
    'TDM_DEPENDENCIA_FINAL',
    'TDM_EJECUCION_ERROR',
    'TDM_REGLA',
    'TDM_EXCEPCION_COL')
order by object_type, object_name;

Rem
Rem ----------------------------------------------------------------
Rem 4.2 VALIDACION DE OBJETOS ENMASCARAMIENTO
Rem ----------------------------------------------------------------

select owner, object_name, object_type, status
from dba_objects
where owner = 'ASTSYSADMIN'
  and object_name in (
    'PKG_DM_FUNC_MASK',
    'PKG_DM_ENMASCARAR',
    'TDM_MASK_SOLICITUD',
    'TDM_MASK_TRACE',
    'TDM_MASK_DEP_ESTADO',
    'TDM_MASK_RESULTADO',
    'TDM_MASK_REGLA_ESP',
    'TDM_MASK_RELACION_SYNC',
    'TDM_MASK_CACHE'
  ) order by object_type, object_name;

Rem
Rem ----------------------------------------------------------------
Rem 4.3 VALIDACION DE GRANTS AL ROL
Rem ----------------------------------------------------------------

select grantee,
       owner,
       table_name,
       privilege
from dba_tab_privs
where owner = 'ASTSYSADMIN'
  and grantee = 'ROL_DATAMASKING'
order by table_name, privilege;

Rem
Rem ----------------------------------------------------------------
Rem 4.4 VALIDACION DE ASIGNACION DEL ROL A LOS DBA
Rem ----------------------------------------------------------------

select grantee,
       granted_role
from dba_role_privs
where granted_role = 'ROL_DATAMASKING'
  and grantee in (
    'ALOPEZDIAZ',
    'ACASTANGI',
    'DMIRANDA',
    'EYPURISACA',
    'ASANCLEMENTE',
    'CSOETERS',
    'ACAMING',
    'CROSS'  )
order by grantee;

/*
Rem
Rem ----------------------------------------------------------------
Rem 4.5 VALIDACION DE SINONIMOS EN LOS DBA
Rem ----------------------------------------------------------------

	select owner,
		   synonym_name,
		   table_owner,
		   table_name
	from dba_synonyms
	where owner in (    'ALOPEZDIAZ',
		'ACASTANGI',
		'DMIRANDA',
		'EYPURISACA',
		'ASANCLEMENTE',
		'CSOETERS',
		'ACAMING',
		'CROSS')  and table_owner = 'ASTSYSADMIN'
	order by owner, synonym_name;
*/
Rem
Rem ----------------------------------------------------------------
Rem 4.6 VALIDACION DE ERRORES DE COMPILACION
Rem ----------------------------------------------------------------

select owner,
       name,
       type,
       line,
       position,
       text
from dba_errors
where owner = 'ASTSYSADMIN'
  and name in (
    'PKG_DM_DESCUBRIMIENTO',
    'PKG_DM_FUNC_MASK',
    'PKG_DM_ENMASCARAR'
  ) order by name, type, sequence;

Rem
Rem ================================================================================
Rem FIN DE INSTALACION / VALIDACION
Rem ================================================================================

