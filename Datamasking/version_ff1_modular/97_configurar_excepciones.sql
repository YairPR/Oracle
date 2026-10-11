set serveroutput on size unlimited
set feedback on
set verify off

Rem =========================================================
Rem 97_configurar_excepciones.sql
Rem
Rem Carga de excepciones manuales en TDM_EXCEPCION_COL (FORCE / EXCLUDE).
Rem Se ejecuta con un usuario DBA (ROL_DATAMASKING solo tiene SELECT sobre
Rem TDM_EXCEPCION_COL; escribir exige DBA o ser el dueño del motor). El esquema del motor se detecta solo
Rem (ASTSYSADMIN o ACC_ADMIN, el que exista): no hay nombres de esquema fijos.
Rem
Rem   FORCE   -> fuerza identificador y enmascaramiento (manda sobre el descubrimiento)
Rem   EXCLUDE -> la columna sale del descubrimiento y no se enmascara
Rem
Rem Los MERGE de abajo son los de cada cliente; son idempotentes (repetir no duplica).
Rem Para otro cliente, copiar un bloque MERGE y cambiar owner/tabla/columna/razon.
Rem
Rem Ejemplos sueltos (ejecutar manualmente, ya con el esquema del motor activo):
Rem   desactivar : update tdm_excepcion_col set activa = 'N'
Rem                 where ora_owner = 'ESQUEMA' and table_name = 'TABLA' and column_name = 'COLUMNA';
Rem   eliminar   : delete from tdm_excepcion_col
Rem                 where ora_owner = 'ESQUEMA' and table_name = 'TABLA' and column_name = 'COLUMNA';
Rem   forzar una columna que YA existe en el historial del descubrimiento:
Rem                 update tdm_columna_hist set enmascarar = 'Y'
Rem                  where ora_owner = 'ESQUEMA' and column_name = 'COLUMNA';
Rem =========================================================

declare
  l_esquema dba_users.username%type;
begin
  select username into l_esquema
    from (select username from all_users
           where username in ('ASTSYSADMIN','ACC_ADMIN')
           order by decode(username,'ASTSYSADMIN',1,'ACC_ADMIN',2,9))
   where rownum = 1;
  execute immediate 'alter session set current_schema = ' || l_esquema;
  dbms_output.put_line('Esquema del motor: ' || l_esquema);
exception
  when no_data_found then
    raise_application_error(-20001, 'No se encontro ni ASTSYSADMIN ni ACC_ADMIN: no hay motor donde cargar excepciones.');
end;
/

-- INCLUDE
merge into tdm_excepcion_col t
using (
    select 'PNCSS_OWN' ora_owner, 'PNCSS_ACUSES'         table_name, 'ACU_NOMBRE'    column_name, 'FORCE' accion, 'IDENTIFICADOR_PERSONAL' identificador_forz, 'Forzado manual: nombre personal validado' razon, 'Y' activa from dual union all
    select 'PNCSS_OWN', 'PNCSS_ALQUEC',        'ALQU_NOMUEC', 'FORCE', 'IDENTIFICADOR_PERSONAL', 'Forzado manual: nombre personal validado', 'Y' from dual union all
    select 'PNCSS_OWN', 'PNCSS_ARRENDADORES',  'ARR_NOMARR',  'FORCE', 'IDENTIFICADOR_PERSONAL', 'Forzado manual: nombre personal validado', 'Y' from dual union all
    select 'PNCSS_OWN', 'PNCSS_AYUNTAMIENTOS', 'AYU_NOMSOL',  'FORCE', 'IDENTIFICADOR_PERSONAL', 'Forzado manual: nombre personal validado', 'Y' from dual union all
    select 'PNCSS_OWN', 'PNCSS_COPIA04',       'COP_NOMSOL',  'FORCE', 'IDENTIFICADOR_PERSONAL', 'Forzado manual: nombre personal validado', 'Y' from dual union all
    select 'PNCSS_OWN', 'PNCSS_COPIA05',       'COP_NOMSOL',  'FORCE', 'IDENTIFICADOR_PERSONAL', 'Forzado manual: nombre personal validado', 'Y' from dual union all
    select 'PNCSS_OWN', 'PNCSS_INSS',          'INSS_NOMSOL', 'FORCE', 'IDENTIFICADOR_PERSONAL', 'Forzado manual: nombre personal validado', 'Y' from dual union all
    select 'PNCSS_OWN', 'PNCSS_PERSONAS',      'PER_NOMSOL',  'FORCE', 'IDENTIFICADOR_PERSONAL', 'Forzado manual: nombre personal validado', 'Y' from dual union all
    select 'PNCSS_OWN', 'PNCSS_PERSONAS',      'PER_PADRE',   'FORCE', 'IDENTIFICADOR_PERSONAL', 'Forzado manual: nombre personal validado', 'Y' from dual union all
    select 'PNCSS_OWN', 'PNCSS_PERSONAS',      'PER_MADRE',   'FORCE', 'IDENTIFICADOR_PERSONAL', 'Forzado manual: nombre personal validado', 'Y' from dual union all
    select 'PNCSS_OWN', 'PNCSS_REVISIONES1',   'REV_NOMSOL',  'FORCE', 'IDENTIFICADOR_PERSONAL', 'Forzado manual: nombre personal validado', 'Y' from dual union all
    select 'PNCSS_OWN', 'PNCSS_SOLIC',         'NOMSO',       'FORCE', 'IDENTIFICADOR_PERSONAL', 'Forzado manual: nombre personal validado', 'Y' from dual union all
    select 'PNCSS_OWN', 'PNCSS_SOLICH',        'NOMSO',       'FORCE', 'IDENTIFICADOR_PERSONAL', 'Forzado manual: nombre personal validado', 'Y' from dual union all
    select 'PNCSS_OWN', 'PNCSS_UNIDADFAMILIAR','UNIFAM_APENU','FORCE', 'IDENTIFICADOR_PERSONAL', 'Forzado manual: nombre completo validado', 'Y' from dual union all
    select 'PNCSS_OWN', 'PNCSS_USUARIOS',      'USU_LT_USU',  'FORCE', 'IDENTIFICADOR_PERSONAL', 'Forzado manual: nombre de usuario/persona validado', 'Y' from dual
) s
on (
       t.ora_owner  = s.ora_owner
   and t.table_name  = s.table_name
   and t.column_name = s.column_name
)
when matched then
  update set
      t.accion             = s.accion,
      t.identificador_forz = s.identificador_forz,
      t.razon              = s.razon,
      t.activa             = s.activa
when not matched then
  insert (
      ora_owner, table_name, column_name,
      accion, identificador_forz, razon, activa
  )
  values (
      s.ora_owner, s.table_name, s.column_name,
      s.accion, s.identificador_forz, s.razon, s.activa
  );
  
--------------------------------------------------------------------------------

-- EXCLUDE

merge into tdm_excepcion_col t
using (
    select 'DM_PCSS_OWN' ora_owner, 'ICSS_DESGLOSE_ATRASOS' table_name, 'NOMINA' column_name, 'EXCLUDE' accion, null identificador_forz, 'Excluido manual: no es dato personal' razon, 'Y' activa from dual union all
    select 'DM_PCSS_OWN', 'ICSS_KIBANA_DATOS',     'NOMINA',     'EXCLUDE', null, 'Excluido manual: no es dato personal', 'Y' from dual union all
    select 'DM_PCSS_OWN', 'ICSS_SOL_PAGALAM',      'NOMINA',     'EXCLUDE', null, 'Excluido manual: no es dato personal', 'Y' from dual union all
    select 'DM_PCSS_OWN', 'PCSS_EXP_CALCULO_VIVI', 'NOMINA_EJE', 'EXCLUDE', null, 'Excluido manual: no es dato personal', 'Y' from dual union all
    select 'DM_PCSS_OWN', 'PCSS_EXP_CALCULO_VIVI', 'NOMINA',     'EXCLUDE', null, 'Excluido manual: no es dato personal', 'Y' from dual union all
    select 'DM_PCSS_OWN', 'PCSS_KIBANA_DATOS',     'NOMINA',     'EXCLUDE', null, 'Excluido manual: no es dato personal', 'Y' from dual
) s
on (
       t.ora_owner  = s.ora_owner
   and t.table_name  = s.table_name
   and t.column_name = s.column_name
)
when matched then
  update set
      t.accion             = s.accion,
      t.identificador_forz = s.identificador_forz,
      t.razon              = s.razon,
      t.activa             = s.activa
when not matched then
  insert (
      ora_owner, table_name, column_name,
      accion, identificador_forz, razon, activa
  )
  values (
      s.ora_owner, s.table_name, s.column_name,
      s.accion, s.identificador_forz, s.razon, s.activa
  );

commit;
