ALTER SESSION SET CURRENT_SCHEMA=ASTSYSADMIN;
-- 0) Incluimos las 92 columnas que solicita el cliente:
-- INCLUDE SIGAD_ACAD_OWN
merge into tdm_excepcion_col t
using (
    select 'SIGAD_ACAD_OWN' owner_name, 'MOLPREMATRICULA'            table_name, 'EMAIL'                 column_name, 'FORCE' accion, 'IDENTIFICADOR_EMAIL'     identificador_forz, 'Forzado manual: email validado por cliente SIGAD educacion' razon, 'Y' activa from dual union all
    select 'SIGAD_ACAD_OWN', 'MOLPREMATRICULAFAMILIAR', 'EMAIL',                'FORCE', 'IDENTIFICADOR_EMAIL',     'Forzado manual: email validado por cliente SIGAD educacion', 'Y' from dual union all
    select 'SIGAD_ACAD_OWN', 'OFECENTRO',               'EMAIL',                'FORCE', 'IDENTIFICADOR_EMAIL',     'Forzado manual: email validado por cliente SIGAD educacion', 'Y' from dual union all
    select 'SIGAD_ACAD_OWN', 'OFECENTRO',               'EMAIL2',               'FORCE', 'IDENTIFICADOR_EMAIL',     'Forzado manual: email secundario validado por cliente SIGAD educacion', 'Y' from dual union all
    select 'SIGAD_ACAD_OWN', 'PERPROFESOR',             'EMAIL',                'FORCE', 'IDENTIFICADOR_EMAIL',     'Forzado manual: email validado por cliente SIGAD educacion', 'Y' from dual union all
    select 'SIGAD_ACAD_OWN', 'PERTERCERO',              'EMAIL',                'FORCE', 'IDENTIFICADOR_EMAIL',     'Forzado manual: email validado por cliente SIGAD educacion', 'Y' from dual union all
    select 'SIGAD_ACAD_OWN', 'SEGUSUARIO',              'EMAIL',                'FORCE', 'IDENTIFICADOR_EMAIL',     'Forzado manual: email validado por cliente SIGAD educacion', 'Y' from dual union all
    select 'SIGAD_ACAD_OWN', 'ALUNOTIFICACIONDSP',      'ALUMNO',               'FORCE', 'IDENTIFICADOR_PERSONAL',  'Forzado manual: rol personal alumno validado por cliente SIGAD educacion', 'Y' from dual union all
    select 'SIGAD_ACAD_OWN', 'CENACTIVIDADPROGRAMA',    'RESPONSABLE',          'FORCE', 'IDENTIFICADOR_PERSONAL',  'Forzado manual: campo ambiguo validado como personal por cliente SIGAD educacion', 'Y' from dual union all
    select 'SIGAD_ACAD_OWN', 'CENACTIVIDADPROGRAMA',    'COORDINADOR',          'FORCE', 'IDENTIFICADOR_PERSONAL',  'Forzado manual: campo ambiguo validado como personal por cliente SIGAD educacion', 'Y' from dual union all
    select 'SIGAD_ACAD_OWN', 'CENACTIVIDADPROGRAMA',    'COLABORADOR',          'FORCE', 'IDENTIFICADOR_PERSONAL',  'Forzado manual: campo ambiguo validado como personal por cliente SIGAD educacion', 'Y' from dual union all
    select 'SIGAD_ACAD_OWN', 'CENALUMNO',               'APELLIDO1',            'FORCE', 'IDENTIFICADOR_PERSONAL',  'Forzado manual: apellido validado por cliente SIGAD educacion', 'Y' from dual union all
    select 'SIGAD_ACAD_OWN', 'CENALUMNO',               'APELLIDO2',            'FORCE', 'IDENTIFICADOR_PERSONAL',  'Forzado manual: apellido validado por cliente SIGAD educacion', 'Y' from dual union all
    select 'SIGAD_ACAD_OWN', 'CENALUMNO',               'NOMBRE',               'FORCE', 'IDENTIFICADOR_PERSONAL',  'Forzado manual: nombre validado por cliente SIGAD educacion', 'Y' from dual union all
    select 'SIGAD_ACAD_OWN', 'CENALUMNO',               'NOMBRESENTIDO',        'FORCE', 'IDENTIFICADOR_PERSONAL',  'Forzado manual: nombre sentido validado por cliente SIGAD educacion', 'Y' from dual union all
    select 'SIGAD_ACAD_OWN', 'CENCUENTABANCO',          'TITULAR',              'FORCE', 'IDENTIFICADOR_PERSONAL',  'Forzado manual: titular validado por cliente SIGAD educacion', 'Y' from dual union all
    select 'SIGAD_ACAD_OWN', 'CENCURSOEVALUACION',      'NOMBRE',               'FORCE', 'IDENTIFICADOR_PERSONAL',  'Forzado manual: nombre validado por cliente SIGAD educacion', 'Y' from dual union all
    select 'SIGAD_ACAD_OWN', 'CENFAMILIAR',             'APELLIDO1',            'FORCE', 'IDENTIFICADOR_PERSONAL',  'Forzado manual: apellido validado por cliente SIGAD educacion', 'Y' from dual union all
    select 'SIGAD_ACAD_OWN', 'CENFAMILIAR',             'APELLIDO2',            'FORCE', 'IDENTIFICADOR_PERSONAL',  'Forzado manual: apellido validado por cliente SIGAD educacion', 'Y' from dual union all
    select 'SIGAD_ACAD_OWN', 'CENFAMILIAR',             'NOMBRE',               'FORCE', 'IDENTIFICADOR_PERSONAL',  'Forzado manual: nombre validado por cliente SIGAD educacion', 'Y' from dual union all
    select 'SIGAD_ACAD_OWN', 'DESTINATARIOS',           'NOMBRE',               'FORCE', 'IDENTIFICADOR_PERSONAL',  'Forzado manual: nombre validado por cliente SIGAD educacion', 'Y' from dual union all
    select 'SIGAD_ACAD_OWN', 'MOLPREMATRICULA',         'APELLIDOS',            'FORCE', 'IDENTIFICADOR_PERSONAL',  'Forzado manual: apellidos validados por cliente SIGAD educacion', 'Y' from dual union all
    select 'SIGAD_ACAD_OWN', 'MOLPREMATRICULA',         'APELLIDO1',            'FORCE', 'IDENTIFICADOR_PERSONAL',  'Forzado manual: apellido validado por cliente SIGAD educacion', 'Y' from dual union all
    select 'SIGAD_ACAD_OWN', 'MOLPREMATRICULA',         'APELLIDO2',            'FORCE', 'IDENTIFICADOR_PERSONAL',  'Forzado manual: apellido validado por cliente SIGAD educacion', 'Y' from dual union all
    select 'SIGAD_ACAD_OWN', 'MOLPREMATRICULA',         'NOMBRE',               'FORCE', 'IDENTIFICADOR_PERSONAL',  'Forzado manual: nombre validado por cliente SIGAD educacion', 'Y' from dual union all
    select 'SIGAD_ACAD_OWN', 'MOLPREMATRICULAFAMILIAR', 'APELLIDOS',            'FORCE', 'IDENTIFICADOR_PERSONAL',  'Forzado manual: apellidos validados por cliente SIGAD educacion', 'Y' from dual union all
    select 'SIGAD_ACAD_OWN', 'MOLPREMATRICULAFAMILIAR', 'APELLIDO1',            'FORCE', 'IDENTIFICADOR_PERSONAL',  'Forzado manual: apellido validado por cliente SIGAD educacion', 'Y' from dual union all
    select 'SIGAD_ACAD_OWN', 'MOLPREMATRICULAFAMILIAR', 'APELLIDO2',            'FORCE', 'IDENTIFICADOR_PERSONAL',  'Forzado manual: apellido validado por cliente SIGAD educacion', 'Y' from dual union all
    select 'SIGAD_ACAD_OWN', 'MOLPREMATRICULAFAMILIAR', 'NOMBRE',               'FORCE', 'IDENTIFICADOR_PERSONAL',  'Forzado manual: nombre validado por cliente SIGAD educacion', 'Y' from dual union all
    select 'SIGAD_ACAD_OWN', 'OFECENTRO',               'TITULAR',              'FORCE', 'IDENTIFICADOR_PERSONAL',  'Forzado manual: titular validado por cliente SIGAD educacion', 'Y' from dual union all
    select 'SIGAD_ACAD_OWN', 'OFECENTRORELACIONCOMUNIDAD','NOMBRE',             'FORCE', 'IDENTIFICADOR_PERSONAL',  'Forzado manual: campo ambiguo validado como personal por cliente SIGAD educacion', 'Y' from dual union all
    select 'SIGAD_ACAD_OWN', 'OFECENTRORELACIONCOMUNIDAD','RESPONSABLE',        'FORCE', 'IDENTIFICADOR_PERSONAL',  'Forzado manual: campo ambiguo validado como personal por cliente SIGAD educacion', 'Y' from dual union all
    select 'SIGAD_ACAD_OWN', 'OFECENTRORELACIONCOMUNIDAD','TECNICO',            'FORCE', 'IDENTIFICADOR_PERSONAL',  'Forzado manual: campo ambiguo validado como personal por cliente SIGAD educacion', 'Y' from dual union all
    select 'SIGAD_ACAD_OWN', 'OTROSDATOSDOC',           'PROFESOR_RESPONSABLE', 'FORCE', 'IDENTIFICADOR_PERSONAL',  'Forzado manual: profesor responsable validado por cliente SIGAD educacion', 'Y' from dual union all
    select 'SIGAD_ACAD_OWN', 'OTROSDATOSDOC',           'NOMBRE_PRESIDENTE_APA1','FORCE','IDENTIFICADOR_PERSONAL',  'Forzado manual: nombre personal validado por cliente SIGAD educacion', 'Y' from dual union all
    select 'SIGAD_ACAD_OWN', 'OTROSDATOSDOC',           'NOMBRE_PRESIDENTE_APA2','FORCE','IDENTIFICADOR_PERSONAL',  'Forzado manual: nombre personal validado por cliente SIGAD educacion', 'Y' from dual union all
    select 'SIGAD_ACAD_OWN', 'PERPROFESOR',             'APELLIDO1',            'FORCE', 'IDENTIFICADOR_PERSONAL',  'Forzado manual: apellido validado por cliente SIGAD educacion', 'Y' from dual union all
    select 'SIGAD_ACAD_OWN', 'PERPROFESOR',             'APELLIDO2',            'FORCE', 'IDENTIFICADOR_PERSONAL',  'Forzado manual: apellido validado por cliente SIGAD educacion', 'Y' from dual union all
    select 'SIGAD_ACAD_OWN', 'PERPROFESOR',             'NOMBRE',               'FORCE', 'IDENTIFICADOR_PERSONAL',  'Forzado manual: nombre validado por cliente SIGAD educacion', 'Y' from dual union all
    select 'SIGAD_ACAD_OWN', 'PERTERCERO',              'APELLIDO1',            'FORCE', 'IDENTIFICADOR_PERSONAL',  'Forzado manual: apellido validado por cliente SIGAD educacion', 'Y' from dual union all
    select 'SIGAD_ACAD_OWN', 'PERTERCERO',              'APELLIDO2',            'FORCE', 'IDENTIFICADOR_PERSONAL',  'Forzado manual: apellido validado por cliente SIGAD educacion', 'Y' from dual union all
    select 'SIGAD_ACAD_OWN', 'PERTERCERO',              'NOMBRE',               'FORCE', 'IDENTIFICADOR_PERSONAL',  'Forzado manual: nombre validado por cliente SIGAD educacion', 'Y' from dual union all
    select 'SIGAD_ACAD_OWN', 'SEGUSUARIO',              'APELLIDO1',            'FORCE', 'IDENTIFICADOR_PERSONAL',  'Forzado manual: apellido validado por cliente SIGAD educacion', 'Y' from dual union all
    select 'SIGAD_ACAD_OWN', 'SEGUSUARIO',              'APELLIDO2',            'FORCE', 'IDENTIFICADOR_PERSONAL',  'Forzado manual: apellido validado por cliente SIGAD educacion', 'Y' from dual union all
    select 'SIGAD_ACAD_OWN', 'SEGUSUARIO',              'NOMBRE',               'FORCE', 'IDENTIFICADOR_PERSONAL',  'Forzado manual: nombre validado por cliente SIGAD educacion', 'Y' from dual union all
    select 'SIGAD_ACAD_OWN', 'TSKPCRUNIFICARALUMNOS',   'APELLIDO1ELIMINAR',    'FORCE', 'IDENTIFICADOR_PERSONAL',  'Forzado manual: apellido en proceso de unificacion validado por cliente SIGAD educacion', 'Y' from dual union all
    select 'SIGAD_ACAD_OWN', 'TSKPCRUNIFICARALUMNOS',   'APELLIDO1MANTENER',    'FORCE', 'IDENTIFICADOR_PERSONAL',  'Forzado manual: apellido en proceso de unificacion validado por cliente SIGAD educacion', 'Y' from dual union all
    select 'SIGAD_ACAD_OWN', 'TSKPCRUNIFICARALUMNOS',   'APELLIDO2ELIMINAR',    'FORCE', 'IDENTIFICADOR_PERSONAL',  'Forzado manual: apellido en proceso de unificacion validado por cliente SIGAD educacion', 'Y' from dual union all
    select 'SIGAD_ACAD_OWN', 'TSKPCRUNIFICARALUMNOS',   'APELLIDO2MANTENER',    'FORCE', 'IDENTIFICADOR_PERSONAL',  'Forzado manual: apellido en proceso de unificacion validado por cliente SIGAD educacion', 'Y' from dual union all
    select 'SIGAD_ACAD_OWN', 'TSKPCRUNIFICARALUMNOS',   'NOMBREELIMINAR',       'FORCE', 'IDENTIFICADOR_PERSONAL',  'Forzado manual: nombre en proceso de unificacion validado por cliente SIGAD educacion', 'Y' from dual union all
    select 'SIGAD_ACAD_OWN', 'TSKPCRUNIFICARALUMNOS',   'NOMBREMANTENER',       'FORCE', 'IDENTIFICADOR_PERSONAL',  'Forzado manual: nombre en proceso de unificacion validado por cliente SIGAD educacion', 'Y' from dual union all
    select 'SIGAD_ACAD_OWN', 'TSKPCRUNIFICARFAMILIARES','APELLIDO1ELIMINAR',    'FORCE', 'IDENTIFICADOR_PERSONAL',  'Forzado manual: apellido en proceso de unificacion validado por cliente SIGAD educacion', 'Y' from dual union all
    select 'SIGAD_ACAD_OWN', 'TSKPCRUNIFICARFAMILIARES','APELLIDO1MANTENER',    'FORCE', 'IDENTIFICADOR_PERSONAL',  'Forzado manual: apellido en proceso de unificacion validado por cliente SIGAD educacion', 'Y' from dual union all
    select 'SIGAD_ACAD_OWN', 'TSKPCRUNIFICARFAMILIARES','APELLIDO2ELIMINAR',    'FORCE', 'IDENTIFICADOR_PERSONAL',  'Forzado manual: apellido en proceso de unificacion validado por cliente SIGAD educacion', 'Y' from dual union all
    select 'SIGAD_ACAD_OWN', 'TSKPCRUNIFICARFAMILIARES','APELLIDO2MANTENER',    'FORCE', 'IDENTIFICADOR_PERSONAL',  'Forzado manual: apellido en proceso de unificacion validado por cliente SIGAD educacion', 'Y' from dual union all
    select 'SIGAD_ACAD_OWN', 'TSKPCRUNIFICARFAMILIARES','NOMBREELIMINAR',       'FORCE', 'IDENTIFICADOR_PERSONAL',  'Forzado manual: nombre en proceso de unificacion validado por cliente SIGAD educacion', 'Y' from dual union all
    select 'SIGAD_ACAD_OWN', 'TSKPCRUNIFICARFAMILIARES','NOMBREMANTENER',       'FORCE', 'IDENTIFICADOR_PERSONAL',  'Forzado manual: nombre en proceso de unificacion validado por cliente SIGAD educacion', 'Y' from dual union all
    select 'SIGAD_ACAD_OWN', 'CENALUMNO',               'NDOCUMENTO',           'FORCE', 'IDENTIFICADOR_IDENTIDAD', 'Forzado manual: documento de identidad validado por cliente SIGAD educacion', 'Y' from dual union all
    select 'SIGAD_ACAD_OWN', 'CENFAMILIAR',             'NDOCUMENTO',           'FORCE', 'IDENTIFICADOR_IDENTIDAD', 'Forzado manual: documento de identidad validado por cliente SIGAD educacion', 'Y' from dual union all
    select 'SIGAD_ACAD_OWN', 'MOLPREMATRICULA',         'NDOCUMENTO',           'FORCE', 'IDENTIFICADOR_IDENTIDAD', 'Forzado manual: documento de identidad validado por cliente SIGAD educacion', 'Y' from dual union all
    select 'SIGAD_ACAD_OWN', 'MOLPREMATRICULAFAMILIAR', 'NDOCUMENTO',           'FORCE', 'IDENTIFICADOR_IDENTIDAD', 'Forzado manual: documento de identidad validado por cliente SIGAD educacion', 'Y' from dual union all
    select 'SIGAD_ACAD_OWN', 'PERPROFESOR',             'NDOCUMENTO',           'FORCE', 'IDENTIFICADOR_IDENTIDAD', 'Forzado manual: documento de identidad validado por cliente SIGAD educacion', 'Y' from dual union all
    select 'SIGAD_ACAD_OWN', 'PERTERCERO',              'NDOCUMENTO',           'FORCE', 'IDENTIFICADOR_IDENTIDAD', 'Forzado manual: documento de identidad validado por cliente SIGAD educacion', 'Y' from dual union all
    select 'SIGAD_ACAD_OWN', 'SEGUSUARIO',              'NDOCUMENTO',           'FORCE', 'IDENTIFICADOR_IDENTIDAD', 'Forzado manual: documento de identidad validado por cliente SIGAD educacion', 'Y' from dual union all
    select 'SIGAD_ACAD_OWN', 'TSKPCRUNIFICARALUMNOS',   'NDOCUMENTOMANTENER',   'FORCE', 'IDENTIFICADOR_IDENTIDAD', 'Forzado manual: documento de identidad validado por cliente SIGAD educacion', 'Y' from dual union all
    select 'SIGAD_ACAD_OWN', 'TSKPCRUNIFICARALUMNOS',   'NDOCUMENTOELIMINAR',   'FORCE', 'IDENTIFICADOR_IDENTIDAD', 'Forzado manual: documento de identidad validado por cliente SIGAD educacion', 'Y' from dual union all
    select 'SIGAD_ACAD_OWN', 'TSKPCRUNIFICARFAMILIARES','NDOCUMENTOMANTENER',   'FORCE', 'IDENTIFICADOR_IDENTIDAD', 'Forzado manual: documento de identidad validado por cliente SIGAD educacion', 'Y' from dual union all
    select 'SIGAD_ACAD_OWN', 'TSKPCRUNIFICARFAMILIARES','NDOCUMENTOELIMINAR',   'FORCE', 'IDENTIFICADOR_IDENTIDAD', 'Forzado manual: documento de identidad validado por cliente SIGAD educacion', 'Y' from dual union all
    select 'SIGAD_ACAD_OWN', 'MOLPREMATRICULA',         'DIRECCION',            'FORCE', 'IDENTIFICADOR_DIRECCION', 'Forzado manual: direccion validada por cliente SIGAD educacion', 'Y' from dual union all
    select 'SIGAD_ACAD_OWN', 'OFECENTRO',               'DIRECCION',            'FORCE', 'IDENTIFICADOR_DIRECCION', 'Forzado manual: direccion validada por cliente SIGAD educacion', 'Y' from dual union all
    select 'SIGAD_ACAD_OWN', 'OFECENTRORELACIONCOMUNIDAD','DIRECCION',          'FORCE', 'IDENTIFICADOR_DIRECCION', 'Forzado manual: direccion validada por cliente SIGAD educacion', 'Y' from dual union all
    select 'SIGAD_ACAD_OWN', 'OTROSDATOSDOC',           'DOMICILIOSOCIAL_APA1', 'FORCE', 'IDENTIFICADOR_DIRECCION', 'Forzado manual: direccion validada por cliente SIGAD educacion', 'Y' from dual union all
    select 'SIGAD_ACAD_OWN', 'OTROSDATOSDOC',           'DOMICILIOSOCIAL_APA2', 'FORCE', 'IDENTIFICADOR_DIRECCION', 'Forzado manual: direccion validada por cliente SIGAD educacion', 'Y' from dual union all
    select 'SIGAD_ACAD_OWN', 'PERDOMICILIO',            'NOMBREVIA',            'FORCE', 'IDENTIFICADOR_DIRECCION', 'Forzado manual: direccion validada por cliente SIGAD educacion', 'Y' from dual union all
    select 'SIGAD_ACAD_OWN', 'PERDOMICILIO',            'RESTDIR',              'FORCE', 'IDENTIFICADOR_DIRECCION', 'Forzado manual: direccion validada por cliente SIGAD educacion', 'Y' from dual union all
    select 'SIGAD_ACAD_OWN', 'TERVIA',                  'NOMBRE',               'FORCE', 'IDENTIFICADOR_DIRECCION', 'Forzado manual: nombre de via validado por cliente SIGAD educacion', 'Y' from dual union all
    select 'SIGAD_ACAD_OWN', 'CENALUMNO',               'TELEFONOEMERGENCIA',   'FORCE', 'IDENTIFICADOR_TELEFONO',  'Forzado manual: telefono validado por cliente SIGAD educacion', 'Y' from dual union all
    select 'SIGAD_ACAD_OWN', 'CENALUMNO',               'TELEFONO1',            'FORCE', 'IDENTIFICADOR_TELEFONO',  'Forzado manual: telefono validado por cliente SIGAD educacion', 'Y' from dual union all
    select 'SIGAD_ACAD_OWN', 'CENALUMNO',               'TELEFONO2',            'FORCE', 'IDENTIFICADOR_TELEFONO',  'Forzado manual: telefono validado por cliente SIGAD educacion', 'Y' from dual union all
    select 'SIGAD_ACAD_OWN', 'CENFAMILIAR',             'TELEFONO1',            'FORCE', 'IDENTIFICADOR_TELEFONO',  'Forzado manual: telefono validado por cliente SIGAD educacion', 'Y' from dual union all
    select 'SIGAD_ACAD_OWN', 'CENFAMILIAR',             'TELEFONO2',            'FORCE', 'IDENTIFICADOR_TELEFONO',  'Forzado manual: telefono validado por cliente SIGAD educacion', 'Y' from dual union all
    select 'SIGAD_ACAD_OWN', 'MOLPREMATRICULA',         'TELEFONO1',            'FORCE', 'IDENTIFICADOR_TELEFONO',  'Forzado manual: telefono validado por cliente SIGAD educacion', 'Y' from dual union all
    select 'SIGAD_ACAD_OWN', 'MOLPREMATRICULA',         'TELEFONO2',            'FORCE', 'IDENTIFICADOR_TELEFONO',  'Forzado manual: telefono validado por cliente SIGAD educacion', 'Y' from dual union all
    select 'SIGAD_ACAD_OWN', 'MOLPREMATRICULAFAMILIAR', 'TELEFONO1',            'FORCE', 'IDENTIFICADOR_TELEFONO',  'Forzado manual: telefono validado por cliente SIGAD educacion', 'Y' from dual union all
    select 'SIGAD_ACAD_OWN', 'MOLPREMATRICULAFAMILIAR', 'TELEFONO2',            'FORCE', 'IDENTIFICADOR_TELEFONO',  'Forzado manual: telefono validado por cliente SIGAD educacion', 'Y' from dual union all
    select 'SIGAD_ACAD_OWN', 'OFECENTRO',               'TELEFONO1',            'FORCE', 'IDENTIFICADOR_TELEFONO',  'Forzado manual: telefono validado por cliente SIGAD educacion', 'Y' from dual union all
    select 'SIGAD_ACAD_OWN', 'OFECENTRO',               'TELEFONO2',            'FORCE', 'IDENTIFICADOR_TELEFONO',  'Forzado manual: telefono validado por cliente SIGAD educacion', 'Y' from dual union all
    select 'SIGAD_ACAD_OWN', 'OFECENTRO',               'FAX',                  'FORCE', 'IDENTIFICADOR_TELEFONO',  'Forzado manual: fax validado por cliente SIGAD educacion', 'Y' from dual union all
    select 'SIGAD_ACAD_OWN', 'OFECENTRORELACIONCOMUNIDAD','TELEFONO',           'FORCE', 'IDENTIFICADOR_TELEFONO',  'Forzado manual: telefono validado por cliente SIGAD educacion', 'Y' from dual union all
    select 'SIGAD_ACAD_OWN', 'PERPROFESOR',             'TELEFONO1',            'FORCE', 'IDENTIFICADOR_TELEFONO',  'Forzado manual: telefono validado por cliente SIGAD educacion', 'Y' from dual union all
    select 'SIGAD_ACAD_OWN', 'PERPROFESOR',             'TELEFONO2',            'FORCE', 'IDENTIFICADOR_TELEFONO',  'Forzado manual: telefono validado por cliente SIGAD educacion', 'Y' from dual union all
    select 'SIGAD_ACAD_OWN', 'PERTERCERO',              'TELEFONO1',            'FORCE', 'IDENTIFICADOR_TELEFONO',  'Forzado manual: telefono validado por cliente SIGAD educacion', 'Y' from dual union all
    select 'SIGAD_ACAD_OWN', 'PERTERCERO',              'TELEFONO2',            'FORCE', 'IDENTIFICADOR_TELEFONO',  'Forzado manual: telefono validado por cliente SIGAD educacion', 'Y' from dual union all
    select 'SIGAD_ACAD_OWN', 'CENCUENTABANCO',          'NUMEROCUENTA',         'FORCE', 'IDENTIFICADOR_BANCARIO',  'Forzado manual: numero de cuenta validado por cliente SIGAD educacion', 'Y' from dual
) s on (
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
  insert (owner_name, table_name, column_name,accion, identificador_forz, razon, activa)
  values ( s.owner_name, s.table_name, s.column_name,s.accion, s.identificador_forz, s.razon, s.activa);


-- merge de reglas especiales

MERGE INTO tdm_mask_regla_esp t
USING (
  SELECT 'SIGAD_ACAD_OWN' esquema_objetivo, 'SIGAD_ACAD_OWN' owner_name,
         'SEGUSUARIO' table_name, 'NDOCUMENTO' column_name,
         'DOC_SEGUN_TIPO' tipo_regla, 'IDTIPODOCUMENTO' valor_regla,
         'Y' activa, 'NIF/NIE/PASAPORTE según IDTIPODOCUMENTO' observacion FROM dual
  UNION ALL
  SELECT 'SIGAD_ACAD_OWN','SIGAD_ACAD_OWN',
         'TSKPCRUNIFICARALUMNOS','NDOCUMENTO',
         'DOC_UNIFICADO_MANTENER_1_Y_ULTIMO',NULL,
         'Y','Mantener primer y último carácter del documento' FROM dual
  UNION ALL
  SELECT 'SIGAD_ACAD_OWN','SIGAD_ACAD_OWN',
         'TSKPCRUNIFICARFAMILIARES','NDOCUMENTO',
         'DOC_UNIFICADO_MANTENER_1_Y_ULTIMO',NULL,
         'Y','Mantener primer y último carácter del documento' FROM dual
  UNION ALL
  SELECT 'SIGAD_ACAD_OWN','SIGAD_ACAD_OWN',
         'CENCUENTABANCO','NUMEROCUENTA',
         'IBAN_ES_CONTINUO',NULL,
         'Y','IBAN continuo de 24 caracteres' FROM dual
) s
ON (
   t.esquema_objetivo = s.esquema_objetivo
   AND t.owner_name       = s.owner_name
   AND t.table_name       = s.table_name
   AND t.column_name      = s.column_name
   AND t.tipo_regla       = s.tipo_regla
)
WHEN MATCHED THEN UPDATE
  SET t.valor_regla = s.valor_regla,
      t.activa      = s.activa,
      t.observacion = s.observacion
WHEN NOT MATCHED THEN INSERT (
  regla_id, esquema_objetivo, owner_name, table_name, column_name,
  tipo_regla, valor_regla, activa, observacion
) VALUES (
  seq_dm_mask_regla_esp.NEXTVAL, s.esquema_objetivo, s.owner_name, s.table_name, s.column_name,
  s.tipo_regla, s.valor_regla, s.activa, s.observacion
);

-- 3)  merge de coherencias post-sync
MERGE INTO tdm_mask_relacion_sync t
USING (
  SELECT 'SIGAD_ACAD_OWN' esquema_objetivo,'SEGUSUARIO' tabla_origen,'IDUSUARIO' columna_join_origen,
         'PERPROFESOR' tabla_destino,'IDUSUARIO' columna_join_destino,
         'EMAIL' columna_origen,'EMAIL' columna_destino,'Y' activa,10 prioridad,
         'Coherencia email usuario-profesor' observacion FROM dual
  UNION ALL SELECT 'SIGAD_ACAD_OWN','SEGUSUARIO','IDUSUARIO','PERPROFESOR','IDUSUARIO','NOMBRE','NOMBRE','Y',20,'Coherencia nombre usuario-profesor' FROM dual
  UNION ALL SELECT 'SIGAD_ACAD_OWN','SEGUSUARIO','IDUSUARIO','PERPROFESOR','IDUSUARIO','APELLIDO1','APELLIDO1','Y',21,'Coherencia apellido1 usuario-profesor' FROM dual
  UNION ALL SELECT 'SIGAD_ACAD_OWN','SEGUSUARIO','IDUSUARIO','PERPROFESOR','IDUSUARIO','APELLIDO2','APELLIDO2','Y',22,'Coherencia apellido2 usuario-profesor' FROM dual
  UNION ALL SELECT 'SIGAD_ACAD_OWN','SEGUSUARIO','IDUSUARIO','PERPROFESOR','IDUSUARIO','NDOCUMENTO','NDOCUMENTO','Y',23,'Coherencia documento usuario-profesor' FROM dual
  UNION ALL SELECT 'SIGAD_ACAD_OWN','SEGUSUARIO','IDUSUARIO','CENALUMNO','IDUSUARIO','NOMBRE','NOMBRE','Y',30,'Coherencia nombre usuario-alumno' FROM dual
  UNION ALL SELECT 'SIGAD_ACAD_OWN','SEGUSUARIO','IDUSUARIO','CENALUMNO','IDUSUARIO','APELLIDO1','APELLIDO1','Y',31,'Coherencia apellido1 usuario-alumno' FROM dual
  UNION ALL SELECT 'SIGAD_ACAD_OWN','SEGUSUARIO','IDUSUARIO','CENALUMNO','IDUSUARIO','APELLIDO2','APELLIDO2','Y',32,'Coherencia apellido2 usuario-alumno' FROM dual
  UNION ALL SELECT 'SIGAD_ACAD_OWN','SEGUSUARIO','IDUSUARIO','CENALUMNO','IDUSUARIO','NDOCUMENTO','NDOCUMENTO','Y',33,'Coherencia documento usuario-alumno' FROM dual
  UNION ALL SELECT 'SIGAD_ACAD_OWN','SEGUSUARIO','IDUSUARIO','CENFAMILIAR','IDUSUARIO','NOMBRE','NOMBRE','Y',40,'Coherencia nombre usuario-familiar' FROM dual
  UNION ALL SELECT 'SIGAD_ACAD_OWN','SEGUSUARIO','IDUSUARIO','CENFAMILIAR','IDUSUARIO','APELLIDO1','APELLIDO1','Y',41,'Coherencia apellido1 usuario-familiar' FROM dual
  UNION ALL SELECT 'SIGAD_ACAD_OWN','SEGUSUARIO','IDUSUARIO','CENFAMILIAR','IDUSUARIO','APELLIDO2','APELLIDO2','Y',42,'Coherencia apellido2 usuario-familiar' FROM dual
  UNION ALL SELECT 'SIGAD_ACAD_OWN','SEGUSUARIO','IDUSUARIO','CENFAMILIAR','IDUSUARIO','NDOCUMENTO','NDOCUMENTO','Y',43,'Coherencia documento usuario-familiar' FROM dual
) s
ON (
       t.esquema_objetivo      = s.esquema_objetivo
   AND t.tabla_origen          = s.tabla_origen
   AND t.columna_join_origen   = s.columna_join_origen
   AND t.tabla_destino         = s.tabla_destino
   AND t.columna_join_destino  = s.columna_join_destino
   AND t.columna_origen        = s.columna_origen
   AND t.columna_destino       = s.columna_destino
)
WHEN MATCHED THEN UPDATE
  SET t.activa = s.activa,
      t.prioridad = s.prioridad,
      t.observacion = s.observacion
WHEN NOT MATCHED THEN INSERT (
  sync_id, esquema_objetivo, tabla_origen, columna_join_origen,
  tabla_destino, columna_join_destino, columna_origen, columna_destino,
  activa, prioridad, observacion
) VALUES (
  seq_dm_mask_relacion_sync.NEXTVAL, s.esquema_objetivo, s.tabla_origen, s.columna_join_origen,
  s.tabla_destino, s.columna_join_destino, s.columna_origen, s.columna_destino,
  s.activa, s.prioridad, s.observacion
);









