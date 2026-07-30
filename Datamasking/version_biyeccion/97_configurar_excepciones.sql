
-- cuando existe en t_columna_hist
update astsysadmin.tdm_columna_hist set ENMASCARAR='Y' where owner_name='PNCSS_OWN' and column_name='AYU_APELNOM';

**************************************************************************
--CUANDO NO EXISTE EN T_COLUMNA_HIST
EXCLUDE → elimina columna del discovery  
FORCE → fuerza identificador y masking
--Insertar una EXCLUSIÓN (EXCLUDE)
--Descarta una columna
INSERT INTO tdm_excepcion_col (owner_name, table_name, column_name, accion, identificador_forz, activa)
VALUES ( 'ESQUEMA','TABLA', 'NOMINA','EXCLUDE', NULL, 'Y');

--Insertar una INCLUSIÓN FORZADA (FORCE)
INSERT INTO astsysadmin.tdm_excepcion_col (owner_name,table_name,column_name,accion,identificador_forz,activa)
VALUES('PNCSS_OWN','PNCSS_AYUNTAMIENTOS', 'AYU_APELNOM', 'FORCE', 'IDENTIFICADOR_PERSONAL', 'Y');

-- desactivar una excepcion:
UPDATE tdm_excepcion_col SET activa = 'N' WHERE owner_name = 'ESQUEMA' AND table_name = 'TABLA' AND column_name = 'COLUMNA';

--eliminar excepcion:
DELETE FROM tdm_excepcion_col WHERE owner_name = 'ESQUEMA' AND table_name = 'TABLA' AND column_name = 'COLUMNA';





-- INCLUDE
merge into tdm_excepcion_col t
using (
    select 'PNCSS_OWN' owner_name, 'PNCSS_ACUSES'         table_name, 'ACU_NOMBRE'    column_name, 'FORCE' accion, 'IDENTIFICADOR_PERSONAL' identificador_forz, 'Forzado manual: nombre personal validado' razon, 'Y' activa from dual union all
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
       t.owner_name  = s.owner_name
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
      owner_name, table_name, column_name,
      accion, identificador_forz, razon, activa
  )
  values (
      s.owner_name, s.table_name, s.column_name,
      s.accion, s.identificador_forz, s.razon, s.activa
  );
  
--------------------------------------------------------------------------------

-- EXCLUDE

merge into tdm_excepcion_col t
using (
    select 'DM_PCSS_OWN' owner_name, 'ICSS_DESGLOSE_ATRASOS' table_name, 'NOMINA' column_name, 'EXCLUDE' accion, null identificador_forz, 'Excluido manual: no es dato personal' razon, 'Y' activa from dual union all
    select 'DM_PCSS_OWN', 'ICSS_KIBANA_DATOS',     'NOMINA',     'EXCLUDE', null, 'Excluido manual: no es dato personal', 'Y' from dual union all
    select 'DM_PCSS_OWN', 'ICSS_SOL_PAGALAM',      'NOMINA',     'EXCLUDE', null, 'Excluido manual: no es dato personal', 'Y' from dual union all
    select 'DM_PCSS_OWN', 'PCSS_EXP_CALCULO_VIVI', 'NOMINA_EJE', 'EXCLUDE', null, 'Excluido manual: no es dato personal', 'Y' from dual union all
    select 'DM_PCSS_OWN', 'PCSS_EXP_CALCULO_VIVI', 'NOMINA',     'EXCLUDE', null, 'Excluido manual: no es dato personal', 'Y' from dual union all
    select 'DM_PCSS_OWN', 'PCSS_KIBANA_DATOS',     'NOMINA',     'EXCLUDE', null, 'Excluido manual: no es dato personal', 'Y' from dual
) s
on (
       t.owner_name  = s.owner_name
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
      owner_name, table_name, column_name,
      accion, identificador_forz, razon, activa
  )
  values (
      s.owner_name, s.table_name, s.column_name,
      s.accion, s.identificador_forz, s.razon, s.activa
  );
