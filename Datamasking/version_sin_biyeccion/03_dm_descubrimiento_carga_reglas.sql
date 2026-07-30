--------------------------------------------------------------------------------
-- 12) CARGA DE REGLAS 
-- Ejecutar una vez o cuando se quiera resetear catálogo.
--------------------------------------------------------------------------------
-- Limpieza opcional
-- delete from tdm_regla;

-- select * from tdm_regla

insert into tdm_regla(regla_id, identificador, tipo_regla, expresion, puntuacion, prioridad, descripcion) select seq_dm_regla.nextval, 
'IDENTIFICADOR_IDENTIDAD',  'COLUMN_NAME', '(^|_)(DNISO|DNIPEN|DNIARR|DNIUEC[0-9]{0,2}|DNI_UEC[0-9]{0,2}|DNISO[0-9]{0,2}|ALQU_DNIPEN|ARR_DNIARR|P[0-9]{2}_IDENTIFICACION)($|_)',
       100,    8,    'Alias funcionales de identidad personal' from dual where not exists ( select 1 from tdm_regla where identificador = 'IDENTIFICADOR_IDENTIDAD'
       and tipo_regla = 'COLUMN_NAME' and expresion = '(^|_)(DNISO|DNIPEN|DNIARR|DNIUEC[0-9]{0,2}|DNI_UEC[0-9]{0,2}|DNISO[0-9]{0,2}|ALQU_DNIPEN|ARR_DNIARR|P[0-9]{2}_IDENTIFICACION)($|_)');

insert into tdm_regla( regla_id, identificador, tipo_regla, expresion, puntuacion, prioridad, descripcion) select seq_dm_regla.nextval,
       'IDENTIFICADOR_PERSONAL',  'COLUMN_NAME', '(^|_)(AP1SO|AP2SO|AP1SOL|AP2SOL|AP1ARR|AP2ARR|APENU[0-9]{1,2}|COP_APENU[0-9]{1,2})($|_)',
       95,   8,  'Alias funcionales de apellido personal' from dual where not exists ( select 1  from tdm_regla  where identificador = 'IDENTIFICADOR_PERSONAL'
       and tipo_regla = 'COLUMN_NAME'   and expresion = '(^|_)(AP1SO|AP2SO|AP1SOL|AP2SOL|AP1ARR|AP2ARR|APENU[0-9]{1,2}|COP_APENU[0-9]{1,2})($|_)');

insert into tdm_regla( regla_id, identificador, tipo_regla, expresion, puntuacion, prioridad, descripcion) select seq_dm_regla.nextval,
       'IDENTIFICADOR_PERSONAL', 'COLUMN_NAME','(^|_)(NOMSO|NOMSOL|NOMARR|NOMUEC|ACU_NOMBRE|USU_LT_USU|UNIFAM_APENU|APELLIDOS_NOMBRE|NOMBRE_COMPLETO)($|_)',
       92,   8,   'Alias funcionales de nombre personal' from dual where not exists ( select 1 from tdm_regla where identificador = 'IDENTIFICADOR_PERSONAL'
       and tipo_regla = 'COLUMN_NAME'  and expresion = '(^|_)(NOMSO|NOMSOL|NOMARR|NOMUEC|ACU_NOMBRE|USU_LT_USU|UNIFAM_APENU|APELLIDOS_NOMBRE|NOMBRE_COMPLETO)($|_)');

insert into tdm_regla(regla_id,identificador,tipo_regla,expresion,puntuacion,prioridad,confianza_min,muestra_min,descripcion)
select seq_dm_regla.nextval, 'IDENTIFICADOR_PERSONAL','COLUMN_NAME','(^|_)(NOMBRE|APE1|APE2|APELLIDO1|APELLIDO2|APELLIDOS)($|_)',90,10,60,null,'Nombre/apellidos persona' from dual
where not exists (select 1 from tdm_regla where identificador='IDENTIFICADOR_PERSONAL' and tipo_regla='COLUMN_NAME' and expresion='(^|_)(NOMBRE|APE1|APE2|APELLIDO1|APELLIDO2|APELLIDOS)($|_)');

/* 2026-03-08 23:10 Ajuste calibración: reforzar columnas titular para detectar nombres compuestos */
insert into tdm_regla(regla_id,identificador,tipo_regla,expresion,puntuacion,prioridad,confianza_min,muestra_min,descripcion)
select seq_dm_regla.nextval, 'IDENTIFICADOR_PERSONAL','COLUMN_NAME','(^|_)(TITULAR|NOMBRE_TITULAR|TITULAR_NOMBRE|TITULAR_APELLIDOS?)($|_)',85,9,55,10,'Titular/nombre titular con alta probabilidad de dato personal' from dual
where not exists (select 1 from tdm_regla where identificador='IDENTIFICADOR_PERSONAL' and tipo_regla='COLUMN_NAME' and expresion='(^|_)(TITULAR|NOMBRE_TITULAR|TITULAR_NOMBRE|TITULAR_APELLIDOS?)($|_)');

insert into tdm_regla(regla_id,identificador,tipo_regla,expresion,puntuacion,prioridad,confianza_min,muestra_min,descripcion)
select seq_dm_regla.nextval, 'IDENTIFICADOR_PERSONAL','COLUMN_NAME','(^|_)(NOMBRE|DENOMINACION)_(MUNICIPIO|PROVINCIA|PAIS|ARCHIVO|FICHERO|PRODUCTO|SERVICIO)($|_)',-260,1,70,null,'Descarta nombres no personales' from dual
where not exists (select 1 from tdm_regla where identificador='IDENTIFICADOR_PERSONAL' and tipo_regla='COLUMN_NAME' and expresion='(^|_)(NOMBRE|DENOMINACION)_(MUNICIPIO|PROVINCIA|PAIS|ARCHIVO|FICHERO|PRODUCTO|SERVICIO)($|_)');

insert into tdm_regla(regla_id,identificador,tipo_regla,expresion,puntuacion,prioridad,muestra_min,descripcion)
select seq_dm_regla.nextval, 'IDENTIFICADOR_EMAIL','DATA_PATTERN','^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$',55,20,500,'Formato email' from dual
where not exists (select 1 from tdm_regla where identificador='IDENTIFICADOR_EMAIL' and tipo_regla='DATA_PATTERN' and expresion='^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$');

insert into tdm_regla(regla_id,identificador,tipo_regla,expresion,puntuacion,prioridad,descripcion)
select seq_dm_regla.nextval, 'IDENTIFICADOR_EMAIL','COLUMN_NAME','(^|_)(EMAIL|MAIL|CORREO)($|_)',90,10,'Correo electrónico' from dual
where not exists (select 1 from tdm_regla where identificador='IDENTIFICADOR_EMAIL' and tipo_regla='COLUMN_NAME' and expresion='(^|_)(EMAIL|MAIL|CORREO)($|_)');

/* 2026-03-08 23:10 Ajuste calibración: evitar falsos positivos tipo S/N en EMAIL_DEFAULT */
insert into tdm_regla(regla_id,identificador,tipo_regla,expresion,puntuacion,prioridad,descripcion)
select seq_dm_regla.nextval, 'IDENTIFICADOR_EMAIL','COLUMN_NAME','(^|_)(EMAIL|MAIL)_(DEFAULT|DEFECTO)$|(^|_)(DEFAULT|DEFECTO)_(EMAIL|MAIL)($|_)',-260,1,'Banderas/default de email, no dato personal directo' from dual
where not exists (select 1 from tdm_regla where identificador='IDENTIFICADOR_EMAIL' and tipo_regla='COLUMN_NAME' and expresion='(^|_)(EMAIL|MAIL)_(DEFAULT|DEFECTO)$|(^|_)(DEFAULT|DEFECTO)_(EMAIL|MAIL)($|_)');

insert into tdm_regla(regla_id,identificador,tipo_regla,expresion,puntuacion,prioridad,descripcion)
select seq_dm_regla.nextval, 'IDENTIFICADOR_TELEFONO','COLUMN_NAME','(^|_)(TEL|TELEFONO|TFNO|MOVIL|CELULAR)($|_)',75,10,'Teléfono' from dual
where not exists (select 1 from tdm_regla where identificador='IDENTIFICADOR_TELEFONO' and tipo_regla='COLUMN_NAME' and expresion='(^|_)(TEL|TELEFONO|TFNO|MOVIL|CELULAR)($|_)');

/* 2026-03-08 23:55 Ajuste calibración: soportar sufijos numéricos TELEFONO1/TELEFONO2 sin hardcode de esquema */
insert into tdm_regla(regla_id,identificador,tipo_regla,expresion,puntuacion,prioridad,descripcion)
select seq_dm_regla.nextval, 'IDENTIFICADOR_TELEFONO','COLUMN_NAME','(^|_)(TEL|TELEFONO|TFNO|MOVIL|CELULAR)([0-9]{1,2})($|_)',78,9,'Teléfono con sufijo numérico (ej. TELEFONO1/TELEFONO2)' from dual
where not exists (select 1 from tdm_regla where identificador='IDENTIFICADOR_TELEFONO' and tipo_regla='COLUMN_NAME' and expresion='(^|_)(TEL|TELEFONO|TFNO|MOVIL|CELULAR)([0-9]{1,2})($|_)');

insert into tdm_regla(regla_id,identificador,tipo_regla,expresion,puntuacion,prioridad,muestra_min,descripcion)
select seq_dm_regla.nextval, 'IDENTIFICADOR_TELEFONO','DATA_PATTERN','^(\+34)?[ -]?[6789][0-9]{8}$',50,20,500,'Teléfono ES' from dual
where not exists (select 1 from tdm_regla where identificador='IDENTIFICADOR_TELEFONO' and tipo_regla='DATA_PATTERN' and expresion='^(\+34)?[ -]?[6789][0-9]{8}$');

/* 2026-03-08 23:55 Ajuste calibración: aceptar teléfonos ES con separadores frecuentes */
insert into tdm_regla(regla_id,identificador,tipo_regla,expresion,puntuacion,prioridad,muestra_min,descripcion)
select seq_dm_regla.nextval, 'IDENTIFICADOR_TELEFONO','DATA_PATTERN','^(\+?34)?[ .-]?[6789]([ .-]?[0-9]){8}$',42,21,500,'Teléfono ES con espacios/puntos/guiones' from dual
where not exists (select 1 from tdm_regla where identificador='IDENTIFICADOR_TELEFONO' and tipo_regla='DATA_PATTERN' and expresion='^(\+?34)?[ .-]?[6789]([ .-]?[0-9]){8}$');

insert into tdm_regla(regla_id,identificador,tipo_regla,expresion,puntuacion,prioridad,descripcion)
select seq_dm_regla.nextval, 'IDENTIFICADOR_BANCARIO','COLUMN_NAME','(^|_)(IBAN|CUENTA|CCC|SWIFT)($|_)',95,10,'Cuenta bancaria/IBAN' from dual
where not exists (select 1 from tdm_regla where identificador='IDENTIFICADOR_BANCARIO' and tipo_regla='COLUMN_NAME' and expresion='(^|_)(IBAN|CUENTA|CCC|SWIFT)($|_)');

insert into tdm_regla(regla_id,identificador,tipo_regla,expresion,puntuacion,prioridad,muestra_min,descripcion)
select seq_dm_regla.nextval, 'IDENTIFICADOR_BANCARIO','DATA_PATTERN','^ES[0-9]{22}$',65,20,500,'IBAN español' from dual
where not exists (select 1 from tdm_regla where identificador='IDENTIFICADOR_BANCARIO' and tipo_regla='DATA_PATTERN' and expresion='^ES[0-9]{22}$');

insert into tdm_regla(regla_id,identificador,tipo_regla,expresion,puntuacion,prioridad,descripcion)
select seq_dm_regla.nextval, 'IDENTIFICADOR_DIRECCION','COLUMN_NAME','(^|_)(DIRECCION|DOMICILIO|CALLE|VIA|AVENIDA|PLAZA|CP|CODIGO_POSTAL)($|_)',85,10,'Dirección' from dual
where not exists (select 1 from tdm_regla where identificador='IDENTIFICADOR_DIRECCION' and tipo_regla='COLUMN_NAME' and expresion='(^|_)(DIRECCION|DOMICILIO|CALLE|VIA|AVENIDA|PLAZA|CP|CODIGO_POSTAL)($|_)');

/* 2026-03-10 00:40 Ajuste recall cross-esquema: cubrir NOMVIA y variantes de nombre de vía */
insert into tdm_regla(regla_id,identificador,tipo_regla,expresion,puntuacion,prioridad,descripcion)
select seq_dm_regla.nextval, 'IDENTIFICADOR_DIRECCION','COLUMN_NAME','(^|_)(NOMVIA|NOMBRE_VIA|NOM_VIA|DIR_NOMVIA)($|_)',78,9,'Nombre de vía/dirección sin token literal DIRECCION' from dual
where not exists (select 1 from tdm_regla where identificador='IDENTIFICADOR_DIRECCION' and tipo_regla='COLUMN_NAME' and expresion='(^|_)(NOMVIA|NOMBRE_VIA|NOM_VIA|DIR_NOMVIA)($|_)');

/* 2026-03-10 13:05 Aprendizaje continuo DIRECCION: excluir catálogos/maestros de tipo de vía */
insert into tdm_regla(regla_id,identificador,tipo_regla,expresion,puntuacion,prioridad,descripcion)
select seq_dm_regla.nextval, 'IDENTIFICADOR_DIRECCION','TABLE_NAME','(^|_)(TIPOS?VIA|TIPO_VIA|CAT(ALOGO)?|MAESTR[OA]|PARAM|LOOKUP|DICCIONARIO|LOV|LISTA)($|_)',-220,2,'Tablas de tipo vía/catálogo no son dirección personal' from dual
where not exists (select 1 from tdm_regla where identificador='IDENTIFICADOR_DIRECCION' and tipo_regla='TABLE_NAME' and expresion='(^|_)(TIPOS?VIA|TIPO_VIA|CAT(ALOGO)?|MAESTR[OA]|PARAM|LOOKUP|DICCIONARIO|LOV|LISTA)($|_)');

/* 2026-03-10 13:05 Aprendizaje continuo DIRECCION: descripciones de tipo vía no son domicilio */
insert into tdm_regla(regla_id,identificador,tipo_regla,expresion,puntuacion,prioridad,descripcion)
select seq_dm_regla.nextval, 'IDENTIFICADOR_DIRECCION','COLUMN_NAME','(^|_)(DESCRI(_)?VIA|DESC(_)?VIA|TIPO(_)?VIA|ABREV(_)?VIA|NOMTIPOVIA)($|_)',-240,1,'Descripción/abreviatura de tipo de vía, no dirección de persona' from dual
where not exists (select 1 from tdm_regla where identificador='IDENTIFICADOR_DIRECCION' and tipo_regla='COLUMN_NAME' and expresion='(^|_)(DESCRI(_)?VIA|DESC(_)?VIA|TIPO(_)?VIA|ABREV(_)?VIA|NOMTIPOVIA)($|_)');

/* 2026-03-10 13:05 Aprendizaje continuo DIRECCION: valores puramente numéricos no son calle/domicilio */
insert into tdm_regla(regla_id,identificador,tipo_regla,expresion,puntuacion,prioridad,muestra_min,descripcion)
select seq_dm_regla.nextval, 'IDENTIFICADOR_DIRECCION','DATA_PATTERN','^[0-9]{1,6}$',-220,1,10,'Contenido numérico puro, no dirección textual' from dual
where not exists (select 1 from tdm_regla where identificador='IDENTIFICADOR_DIRECCION' and tipo_regla='DATA_PATTERN' and expresion='^[0-9]{1,6}$');

/* 2026-03-10 13:30 Aprendizaje continuo DIRECCION: CALLE/VIA por nombre requiere evidencia de contenido */
insert into tdm_regla(regla_id,identificador,tipo_regla,expresion,puntuacion,prioridad,descripcion)
select seq_dm_regla.nextval, 'IDENTIFICADOR_DIRECCION','COLUMN_NAME','(^|_)(CALLE|VIA)($|_)',-50,3,'Nombre de columna genérico, requiere soporte por patrón/contexto' from dual
where not exists (select 1 from tdm_regla where identificador='IDENTIFICADOR_DIRECCION' and tipo_regla='COLUMN_NAME' and expresion='(^|_)(CALLE|VIA)($|_)');

/* 2026-03-10 13:30 Aprendizaje continuo DIRECCION: evidencia textual de domicilio real */
insert into tdm_regla(regla_id,identificador,tipo_regla,expresion,puntuacion,prioridad,muestra_min,descripcion)
select seq_dm_regla.nextval, 'IDENTIFICADOR_DIRECCION','DATA_PATTERN','(^|[[:space:]])(C/|CALLE|AVDA|AVENIDA|PASEO|PLAZA|RONDA|CAMINO|TRAVESIA|TRAVESÍA)([[:space:]]|$)',45,16,10,'Tokens direccionales típicos en contenido' from dual
where not exists (select 1 from tdm_regla where identificador='IDENTIFICADOR_DIRECCION' and tipo_regla='DATA_PATTERN' and expresion='(^|[[:space:]])(C/|CALLE|AVDA|AVENIDA|PASEO|PLAZA|RONDA|CAMINO|TRAVESIA|TRAVESÍA)([[:space:]]|$)');

insert into tdm_regla(regla_id,identificador,tipo_regla,expresion,puntuacion,prioridad,muestra_min,descripcion)
select seq_dm_regla.nextval, 'IDENTIFICADOR_OBS','DATA_PATTERN','^(APROBADO|DENEGADO|RECHAZADO|ACEPTADO|PENDIENTE|VARIACION|VARIACIÓN)$',-100,1,500,'Estado corto, no observación' from dual
where not exists (select 1 from tdm_regla where identificador='IDENTIFICADOR_OBS' and tipo_regla='DATA_PATTERN' and expresion='^(APROBADO|DENEGADO|RECHAZADO|ACEPTADO|PENDIENTE|VARIACION|VARIACIÓN)$');

-- Ajustes finos heredados de reglas históricas (mejor recall sin subir falsos positivos)
insert into tdm_regla(regla_id,identificador,tipo_regla,expresion,puntuacion,prioridad,descripcion)
select seq_dm_regla.nextval,'IDENTIFICADOR_PERSONAL','COLUMN_NAME','(^|_)(NOMBRE_USUARIO|APE1_USUARIO|APE2_USUARIO|NIF_USUARIO|US_NOMBRE|US_APELLIDO)($|_)',95,8,'Campos usuario/persona frecuentes' from dual
where not exists (select 1 from tdm_regla where identificador='IDENTIFICADOR_PERSONAL' and tipo_regla='COLUMN_NAME' and expresion='(^|_)(NOMBRE_USUARIO|APE1_USUARIO|APE2_USUARIO|NIF_USUARIO|US_NOMBRE|US_APELLIDO)($|_)');

/* 2026-03-10 13:30 Aprendizaje continuo PERSONAL: roles de persona frecuentes sin usar NOMBRE/APELLIDO */
insert into tdm_regla(regla_id,identificador,tipo_regla,expresion,puntuacion,prioridad,descripcion)
select seq_dm_regla.nextval,'IDENTIFICADOR_PERSONAL','COLUMN_NAME','(^|_)(SOLICITANTE|INTERESAD[OA]|BENEFICIARI[OA]|DECLARANTE|REPRESENTANTE)($|_)',88,8,'Roles de persona con alta probabilidad de dato personal' from dual
where not exists (select 1 from tdm_regla where identificador='IDENTIFICADOR_PERSONAL' and tipo_regla='COLUMN_NAME' and expresion='(^|_)(SOLICITANTE|INTERESAD[OA]|BENEFICIARI[OA]|DECLARANTE|REPRESENTANTE)($|_)');

insert into tdm_regla(regla_id,identificador,tipo_regla,expresion,puntuacion,prioridad,descripcion)
select seq_dm_regla.nextval,'IDENTIFICADOR_DIRECCION','COLUMN_NAME','(^|_)(DEN_DOMICILIO|DOMICILIO|NOMBRE_VIA_R)($|_)',120,7,'Dirección explícita en dominios ICSS/PCSS' from dual
where not exists (select 1 from tdm_regla where identificador='IDENTIFICADOR_DIRECCION' and tipo_regla='COLUMN_NAME' and expresion='(^|_)(DEN_DOMICILIO|DOMICILIO|NOMBRE_VIA_R)($|_)');

insert into tdm_regla(regla_id,identificador,tipo_regla,expresion,puntuacion,prioridad,descripcion)
select seq_dm_regla.nextval,'IDENTIFICADOR_DIRECCION','COLUMN_NAME','(^|_)(DEN_CP|CP|CODIGO_POSTAL)($|_)',-220,1,'Código postal: no enmascarar como dirección sensible' from dual
where not exists (select 1 from tdm_regla where identificador='IDENTIFICADOR_DIRECCION' and tipo_regla='COLUMN_NAME' and expresion='(^|_)(DEN_CP|CP|CODIGO_POSTAL)($|_)');

insert into tdm_regla(regla_id,identificador,tipo_regla,expresion,puntuacion,prioridad,descripcion)
select seq_dm_regla.nextval,'IDENTIFICADOR_TELEFONO','COLUMN_NAME','(^|_)(DEN_TFNO|DEN_TFNO_MOVIL|DEN_TELEF1|DEN_TELEF2|TFNO_MOVIL|TELEF1|TELEF2)($|_)',95,8,'Teléfonos con prefijo DEN_ y variantes' from dual
where not exists (select 1 from tdm_regla where identificador='IDENTIFICADOR_TELEFONO' and tipo_regla='COLUMN_NAME' and expresion='(^|_)(DEN_TFNO|DEN_TFNO_MOVIL|DEN_TELEF1|DEN_TELEF2|TFNO_MOVIL|TELEF1|TELEF2)($|_)');

insert into tdm_regla(regla_id,identificador,tipo_regla,expresion,puntuacion,prioridad,descripcion)
select seq_dm_regla.nextval,'IDENTIFICADOR_EMAIL','COLUMN_NAME','(^|_)(DEN_EMAIL|MAIL)($|_)',90,8,'Correos con variantes de nombre' from dual
where not exists (select 1 from tdm_regla where identificador='IDENTIFICADOR_EMAIL' and tipo_regla='COLUMN_NAME' and expresion='(^|_)(DEN_EMAIL|MAIL)($|_)');

insert into tdm_regla(regla_id,identificador,tipo_regla,expresion,puntuacion,prioridad,descripcion)
select seq_dm_regla.nextval, 'IDENTIFICADOR_BANCARIO',  'COLUMN_NAME',  '(^|_)(CUENTA_NEW|IBAN_NEW)($|_)',     
95,   8,  'Variantes bancarias reales' from dual where not exists (select 1 from tdm_regla
where identificador='IDENTIFICADOR_BANCARIO'  and tipo_regla='COLUMN_NAME'   and expresion='(^|_)(CUENTA_NEW|IBAN_NEW)($|_)');

insert into tdm_regla(regla_id,identificador,tipo_regla,expresion,puntuacion,prioridad,descripcion)
select seq_dm_regla.nextval,'IDENTIFICADOR_PERSONAL','TABLE_NAME','(^|_)(ICSS|PCSS|IMVSS)_(DATOS|EXP|SOL|USUARIOS|PERSONA|TITULAR)',40,20,'Contexto funcional alto de datos personales' from dual
where not exists (select 1 from tdm_regla where identificador='IDENTIFICADOR_PERSONAL' and tipo_regla='TABLE_NAME' and expresion='(^|_)(ICSS|PCSS|IMVSS)_(DATOS|EXP|SOL|USUARIOS|PERSONA|TITULAR)');

insert into tdm_regla(regla_id,identificador,tipo_regla,expresion,puntuacion,prioridad,descripcion)
select seq_dm_regla.nextval,'IDENTIFICADOR_PERSONAL','COLUMN_NAME','(^|_)(NOMBRE_VIA|NOMBRE_VIA_R|NOMBRE_MUNICIPIO|NOMBRE_ARCHIVO|NOMBRE_DOCUMENTO)($|_)',-260,1,'Nombre de vía/objeto/documento no es nombre de persona' from dual
where not exists (select 1 from tdm_regla where identificador='IDENTIFICADOR_PERSONAL' and tipo_regla='COLUMN_NAME' and expresion='(^|_)(NOMBRE_VIA|NOMBRE_VIA_R|NOMBRE_MUNICIPIO|NOMBRE_ARCHIVO|NOMBRE_DOCUMENTO)($|_)');

insert into tdm_regla(regla_id,identificador,tipo_regla,expresion,puntuacion,prioridad,descripcion)
select seq_dm_regla.nextval,'IDENTIFICADOR_DIRECCION','COLUMN_NAME','(^|_)(CODIGO_VIA|NUMERO_VIA|DEN_CP|CP)($|_)',-230,1,'Campos técnicos de vía/código postal' from dual
where not exists (select 1 from tdm_regla where identificador='IDENTIFICADOR_DIRECCION' and tipo_regla='COLUMN_NAME' and expresion='(^|_)(CODIGO_VIA|NUMERO_VIA|DEN_CP|CP)($|_)');

insert into tdm_regla(regla_id,identificador,tipo_regla,expresion,puntuacion,prioridad,descripcion)
select seq_dm_regla.nextval,'IDENTIFICADOR_OBS','COLUMN_NAME','(^|_)(NOTA|OBS|OBSERVACION|OBSERVACIONES)($|_)',90,6,'Campos de observaciones/notas a enmascarar' from dual
where not exists (select 1 from tdm_regla where identificador='IDENTIFICADOR_OBS' and tipo_regla='COLUMN_NAME' and expresion='(^|_)(NOTA|OBS|OBSERVACION|OBSERVACIONES)($|_)');

/* 2026-03-06 12:10 Mejora calibración: reforzar observaciones y banca en tablas pequeñas */
insert into tdm_regla(regla_id,identificador,tipo_regla,expresion,puntuacion,prioridad,descripcion)
select seq_dm_regla.nextval,'IDENTIFICADOR_OBS','COLUMN_NAME','(^|_)(DESCRIPCION|CONSULTA|RESPUESTA|DETALLE)($|_)',55,7,'Texto libre potencial (requiere validación por patrón de datos)' from dual
where not exists (select 1 from tdm_regla where identificador='IDENTIFICADOR_OBS' and tipo_regla='COLUMN_NAME' and expresion='(^|_)(DESCRIPCION|CONSULTA|RESPUESTA|DETALLE)($|_)');

insert into tdm_regla(regla_id,identificador,tipo_regla,expresion,puntuacion,prioridad,muestra_min,descripcion)
select seq_dm_regla.nextval,'IDENTIFICADOR_BANCARIO','DATA_PATTERN','^ES[0-9A-Z]{2,22}$',45,22,10,'IBAN parcial o truncado (migraciones/cambios)' from dual
where not exists (select 1 from tdm_regla where identificador='IDENTIFICADOR_BANCARIO' and tipo_regla='DATA_PATTERN' and expresion='^ES[0-9A-Z]{2,22}$');

insert into tdm_regla(regla_id,identificador,tipo_regla,expresion,puntuacion,prioridad,muestra_min,descripcion)
select seq_dm_regla.nextval,'IDENTIFICADOR_BANCARIO','DATA_PATTERN','^[0-9]{10,24}$',35,23,10,'Número de cuenta numérico (sin prefijo país)' from dual
where not exists (select 1 from tdm_regla where identificador='IDENTIFICADOR_BANCARIO' and tipo_regla='DATA_PATTERN' and expresion='^[0-9]{10,24}$');

insert into tdm_regla(regla_id,identificador,tipo_regla,expresion,puntuacion,prioridad,muestra_min,descripcion)
select seq_dm_regla.nextval,'IDENTIFICADOR_PERSONAL','DATA_PATTERN','(\.pdf$|\.xml$|\.docx?$|\.xlsx?$|\.zip$|\.csv$|\.json$)',-220,1,10,'Nombre de archivo/documento, no personal' from dual
where not exists (select 1 from tdm_regla where identificador='IDENTIFICADOR_PERSONAL' and tipo_regla='DATA_PATTERN' and expresion='(\.pdf$|\.xml$|\.docx?$|\.xlsx?$|\.zip$|\.csv$|\.json$)');

/* 2026-03-06 14:35 Mejora calibración OBS: reforzar evidencia en datos y penalizar catálogos */
insert into tdm_regla(regla_id,identificador,tipo_regla,expresion,puntuacion,prioridad,descripcion)
select seq_dm_regla.nextval,'IDENTIFICADOR_OBS','COLUMN_NAME','(^|_)(MENSAJE|COMENTARIO|OBS|OBSERVACION|OBSERVACIONES|NOTA)($|_)',35,8,'Columna potencial OBS, requiere evidencia de datos' from dual
where not exists (select 1 from tdm_regla where identificador='IDENTIFICADOR_OBS' and tipo_regla='COLUMN_NAME' and expresion='(^|_)(MENSAJE|COMENTARIO|OBS|OBSERVACION|OBSERVACIONES|NOTA)($|_)');

insert into tdm_regla(regla_id,identificador,tipo_regla,expresion,puntuacion,prioridad,descripcion)
select seq_dm_regla.nextval,'IDENTIFICADOR_OBS','TABLE_NAME','(^|_)(CAT|CATALOG|CATALOGO|PARAM|TIPO|PARENTESCO|PREGUNTA|PESTANA|PESTAÑA|COMODIN|MAESTRO|DICCIONARIO|LOOKUP|LOV|DOCUMENTO)($|_)',-180,2,'Tablas de catálogo/listado/documento con baja probabilidad de OBS sensible' from dual
where not exists (select 1 from tdm_regla where identificador='IDENTIFICADOR_OBS' and tipo_regla='TABLE_NAME' and expresion='(^|_)(CAT|CATALOG|CATALOGO|PARAM|TIPO|PARENTESCO|PREGUNTA|PESTANA|PESTAÑA|COMODIN|MAESTRO|DICCIONARIO|LOOKUP|LOV|DOCUMENTO)($|_)');

insert into tdm_regla(regla_id,identificador,tipo_regla,expresion,puntuacion,prioridad,muestra_min,descripcion)
select seq_dm_regla.nextval,'IDENTIFICADOR_OBS','DATA_PATTERN','^.{40,}$',50,12,10,'Texto largo compatible con observación sensible' from dual
where not exists (select 1 from tdm_regla where identificador='IDENTIFICADOR_OBS' and tipo_regla='DATA_PATTERN' and expresion='^.{40,}$');

insert into tdm_regla(regla_id,identificador,tipo_regla,expresion,puntuacion,prioridad,muestra_min,descripcion)
select seq_dm_regla.nextval,'IDENTIFICADOR_OBS','DATA_PATTERN','^.{1,20}$',-45,3,10,'Texto corto, normalmente no observación sensible' from dual
where not exists (select 1 from tdm_regla where identificador='IDENTIFICADOR_OBS' and tipo_regla='DATA_PATTERN' and expresion='^.{1,20}$');

insert into tdm_regla(regla_id,identificador,tipo_regla,expresion,puntuacion,prioridad,muestra_min,descripcion)
select seq_dm_regla.nextval,'IDENTIFICADOR_OBS','DATA_PATTERN','^(OK|KO|SI|SÍ|NO|TRUE|FALSE|APROBADO|DENEGADO|RECHAZADO|ACEPTADO|PENDIENTE|VARIACION|VARIACIÓN)$',-160,2,10,'Estados/respuestas cortas no son observación sensible' from dual
where not exists (select 1 from tdm_regla where identificador='IDENTIFICADOR_OBS' and tipo_regla='DATA_PATTERN' and expresion='^(OK|KO|SI|SÍ|NO|TRUE|FALSE|APROBADO|DENEGADO|RECHAZADO|ACEPTADO|PENDIENTE|VARIACION|VARIACIÓN)$');

/* 2026-03-06 14:35 Mejora calibración DIRECCION: descartar checks/flags técnicos */
insert into tdm_regla(regla_id,identificador,tipo_regla,expresion,puntuacion,prioridad,descripcion)
select seq_dm_regla.nextval,'IDENTIFICADOR_DIRECCION','COLUMN_NAME','(^|_)CHECK_',-220,1,'Campo técnico de validación/check, no dirección' from dual
where not exists (select 1 from tdm_regla where identificador='IDENTIFICADOR_DIRECCION' and tipo_regla='COLUMN_NAME' and expresion='(^|_)CHECK_');

/* 2026-03-06 16:10 Mejora calibración: OBSERVACIONES_DOMICILIO debe tratarse como OBS y no como DIRECCION */
insert into tdm_regla(regla_id,identificador,tipo_regla,expresion,puntuacion,prioridad,descripcion)
select seq_dm_regla.nextval,'IDENTIFICADOR_DIRECCION','COLUMN_NAME','(^|_)(OBS|OBSERVACION|OBSERVACIONES|COMENTARIO|REV).*(_)?(DOMICILIO|DIRECCION)($|_)',-260,1,'Observación de domicilio no es dato dirección estructurada' from dual
where not exists (select 1 from tdm_regla where identificador='IDENTIFICADOR_DIRECCION' and tipo_regla='COLUMN_NAME' and expresion='(^|_)(OBS|OBSERVACION|OBSERVACIONES|COMENTARIO|REV).*(_)?(DOMICILIO|DIRECCION)($|_)');

insert into tdm_regla(regla_id,identificador,tipo_regla,expresion,puntuacion,prioridad,descripcion)
select seq_dm_regla.nextval,'IDENTIFICADOR_OBS','COLUMN_NAME','(^|_)(OBS|OBSERVACION|OBSERVACIONES|COMENTARIO|REV).*(_)?(DOMICILIO|DIRECCION)($|_)',95,5,'Observaciones de domicilio/dirección se tratan como OBS' from dual
where not exists (select 1 from tdm_regla where identificador='IDENTIFICADOR_OBS' and tipo_regla='COLUMN_NAME' and expresion='(^|_)(OBS|OBSERVACION|OBSERVACIONES|COMENTARIO|REV).*(_)?(DOMICILIO|DIRECCION)($|_)');

/* 2026-03-06 16:10 Mejora calibración OBS: penalizar tablas claramente de catálogo/listado */
insert into tdm_regla(regla_id,identificador,tipo_regla,expresion,puntuacion,prioridad,descripcion)
select seq_dm_regla.nextval,'IDENTIFICADOR_OBS','TABLE_NAME','(^|_)(BAREMO|PESTANAS?|TIPOINGRESO|TIPOID|ROL|ACCION|PARENTESCO)($|_)',-210,1,'Tablas de catálogo/listado no suelen contener observaciones sensibles' from dual
where not exists (select 1 from tdm_regla where identificador='IDENTIFICADOR_OBS' and tipo_regla='TABLE_NAME' and expresion='(^|_)(BAREMO|PESTANAS?|TIPOINGRESO|TIPOID|ROL|ACCION|PARENTESCO)($|_)');

/* 2026-03-06 17:05 Mejora calibración DIRECCION: descartar tipos/códigos de vía y plaza */
insert into tdm_regla(regla_id,identificador,tipo_regla,expresion,puntuacion,prioridad,descripcion)
select seq_dm_regla.nextval,'IDENTIFICADOR_DIRECCION','COLUMN_NAME','(^|_)(TIPO_DOMICILIO|TIPO_VIA|ID_VIA(_ACCESO)?|ID_TIPO_PLAZA)($|_)',-260,1,'Campos tipo/código/ID no son dirección sensible' from dual
where not exists (select 1 from tdm_regla where identificador='IDENTIFICADOR_DIRECCION' and tipo_regla='COLUMN_NAME' and expresion='(^|_)(TIPO_DOMICILIO|TIPO_VIA|ID_VIA(_ACCESO)?|ID_TIPO_PLAZA)($|_)');

/* 2026-03-06 17:05 Mejora calibración PERSONAL: excluir geografía/entidad administrativa */
insert into tdm_regla(regla_id,identificador,tipo_regla,expresion,puntuacion,prioridad,descripcion)
select seq_dm_regla.nextval,'IDENTIFICADOR_PERSONAL','COLUMN_NAME','(^|_)(NOMBRE_(ENTIDAD|LOCALIDAD|COMARCA|MUNICIPIO|PROVINCIA|PAIS|REGION))($|_)',-280,1,'Nombre geográfico/administrativo no personal' from dual
where not exists (select 1 from tdm_regla where identificador='IDENTIFICADOR_PERSONAL' and tipo_regla='COLUMN_NAME' and expresion='(^|_)(NOMBRE_(ENTIDAD|LOCALIDAD|COMARCA|MUNICIPIO|PROVINCIA|PAIS|REGION))($|_)');


insert into tdm_regla(regla_id,identificador,tipo_regla,expresion,puntuacion,prioridad,muestra_min,descripcion)
select seq_dm_regla.nextval, 'IDENTIFICADOR_IDENTIDAD','DATA_PATTERN','^[0-9]{8}[A-Z]$|^[XYZ][0-9]{7}[A-Z]$',60,20,500,'Formato DNI/NIE' from dual
where not exists (select 1 from tdm_regla where identificador='IDENTIFICADOR_IDENTIDAD' and tipo_regla='DATA_PATTERN' and expresion='^[0-9]{8}[A-Z]$|^[XYZ][0-9]{7}[A-Z]$');

insert into tdm_regla(regla_id,identificador,tipo_regla,expresion,puntuacion,prioridad,descripcion)
select seq_dm_regla.nextval, 'IDENTIFICADOR_IDENTIDAD','COLUMN_NAME','(^|_)(NIF|NIE|DNI|DOC_IDENTIDAD|DOCUMENTO_IDENTIDAD)($|_)',110,10,'Documento de identidad (token explícito)' from dual
where not exists (select 1 from tdm_regla where identificador='IDENTIFICADOR_IDENTIDAD' and tipo_regla='COLUMN_NAME' and expresion='(^|_)(NIF|NIE|DNI|DOC_IDENTIDAD|DOCUMENTO_IDENTIDAD)($|_)');

/* 2026-03-10 00:40 Ajuste recall cross-esquema: incluir CIF y variantes de documento fiscal */
insert into tdm_regla(regla_id,identificador,tipo_regla,expresion,puntuacion,prioridad,descripcion)
select seq_dm_regla.nextval, 'IDENTIFICADOR_IDENTIDAD','COLUMN_NAME','(^|_)(CIF|DOCIDENT|DOC_IDENT|NIF_CIF|CIF_NIF)($|_)',95,9,'CIF y variantes de identificador fiscal/documental' from dual
where not exists (select 1 from tdm_regla where identificador='IDENTIFICADOR_IDENTIDAD' and tipo_regla='COLUMN_NAME' and expresion='(^|_)(CIF|DOCIDENT|DOC_IDENT|NIF_CIF|CIF_NIF)($|_)');

insert into tdm_regla(regla_id,identificador,tipo_regla,expresion,puntuacion,prioridad,descripcion)
select seq_dm_regla.nextval,'IDENTIFICADOR_IDENTIDAD','COLUMN_NAME','(^|_)(NIFNIE|NIF_ACTUAL|NIF_ANTERIOR|NIF_INVOCA|CUENTA_TITU_NIF)($|_)',115,7,'Variantes NIF/NIE de negocio' from dual
where not exists (select 1 from tdm_regla where identificador='IDENTIFICADOR_IDENTIDAD' and tipo_regla='COLUMN_NAME' and expresion='(^|_)(NIFNIE|NIF_ACTUAL|NIF_ANTERIOR|NIF_INVOCA|CUENTA_TITU_NIF)($|_)');

insert into tdm_regla(regla_id,identificador,tipo_regla,expresion,puntuacion,prioridad,descripcion)
select seq_dm_regla.nextval,'IDENTIFICADOR_IDENTIDAD','COLUMN_NAME','(^|_)(TIPO_NIF|TIPO_DNI|TIPO_NIE|CODIGO_NIF|COD_NIF)($|_)',-260,1,'Tipo/código de identidad, no dato sensible directo' from dual
where not exists (select 1 from tdm_regla where identificador='IDENTIFICADOR_IDENTIDAD' and tipo_regla='COLUMN_NAME' and expresion='(^|_)(TIPO_NIF|TIPO_DNI|TIPO_NIE|CODIGO_NIF|COD_NIF)($|_)');

/* 2026-03-06 18:05 Mejora calibración IDENTIDAD/PERSONAL en nuevos dominios (SIGAD/educación) */
insert into tdm_regla(regla_id,identificador,tipo_regla,expresion,puntuacion,prioridad,descripcion)
select seq_dm_regla.nextval,'IDENTIFICADOR_IDENTIDAD','COLUMN_NAME','(^|_)(NDOCUMENTO|NUM_DOCUMENTO|NRO_DOCUMENTO)($|_)',95,8,'Documento de identidad por nomenclatura NDOCUMENTO/NUM_DOCUMENTO' from dual
where not exists (select 1 from tdm_regla where identificador='IDENTIFICADOR_IDENTIDAD' and tipo_regla='COLUMN_NAME' and expresion='(^|_)(NDOCUMENTO|NUM_DOCUMENTO|NRO_DOCUMENTO)($|_)');

insert into tdm_regla(regla_id,identificador,tipo_regla,expresion,puntuacion,prioridad,descripcion)
select seq_dm_regla.nextval,'IDENTIFICADOR_IDENTIDAD','COLUMN_NAME','(^|_)(IDTIPODOCUMENTO|TIPODOCUMENTO|TIPO_DOCUMENTO|COD_TIPODOC)($|_)',-260,1,'Tipo/código de documento, no identidad sensible' from dual
where not exists (select 1 from tdm_regla where identificador='IDENTIFICADOR_IDENTIDAD' and tipo_regla='COLUMN_NAME' and expresion='(^|_)(IDTIPODOCUMENTO|TIPODOCUMENTO|TIPO_DOCUMENTO|COD_TIPODOC)($|_)');

/* 2026-03-10 15:05 Ajuste precisión identidad: códigos de tipo/ítem documental no son NIF/NIE */
insert into tdm_regla(regla_id,identificador,tipo_regla,expresion,puntuacion,prioridad,descripcion)
select seq_dm_regla.nextval,'IDENTIFICADOR_IDENTIDAD','COLUMN_NAME','(^|_)(IT_DOCUMENTO|TIPO_DOCUMENTO|ID_DOCUMENTO|COD_DOCUMENTO)($|_)',-300,1,'Códigos/ítems de documento no son identidad personal' from dual
where not exists (select 1 from tdm_regla where identificador='IDENTIFICADOR_IDENTIDAD' and tipo_regla='COLUMN_NAME' and expresion='(^|_)(IT_DOCUMENTO|TIPO_DOCUMENTO|ID_DOCUMENTO|COD_DOCUMENTO)($|_)');

/* 2026-03-10 15:05 Ajuste precisión identidad: valores numéricos cortos no cumplen formato regulatorio NIF/NIE */
insert into tdm_regla(regla_id,identificador,tipo_regla,expresion,puntuacion,prioridad,muestra_min,descripcion)
select seq_dm_regla.nextval,'IDENTIFICADOR_IDENTIDAD','DATA_PATTERN','^[0-9]{1,3}$',-260,1,10,'Código corto numérico, no identidad española' from dual
where not exists (select 1 from tdm_regla where identificador='IDENTIFICADOR_IDENTIDAD' and tipo_regla='DATA_PATTERN' and expresion='^[0-9]{1,3}$');

/* 2026-03-10 15:35 Ajuste precisión identidad: columnas marca/flag/check DNI no son identidad */
insert into tdm_regla(regla_id,identificador,tipo_regla,expresion,puntuacion,prioridad,descripcion)
select seq_dm_regla.nextval,'IDENTIFICADOR_IDENTIDAD','COLUMN_NAME','(^|_)(MARCA_DNI|SW_DNI|FLAG_DNI|IND_DNI|CHECK_DNI)($|_)',-320,1,'Marca/flag/check de DNI, no dato identidad' from dual
where not exists (select 1 from tdm_regla where identificador='IDENTIFICADOR_IDENTIDAD' and tipo_regla='COLUMN_NAME' and expresion='(^|_)(MARCA_DNI|SW_DNI|FLAG_DNI|IND_DNI|CHECK_DNI)($|_)');

/* 2026-03-10 16:05 Ajuste recall identidad: NUMERO_DOCUMENTO y variantes */
insert into tdm_regla(regla_id,identificador,tipo_regla,expresion,puntuacion,prioridad,descripcion)
select seq_dm_regla.nextval,'IDENTIFICADOR_IDENTIDAD','COLUMN_NAME','(^|_)(NUMERO_DOCUMENTO|NUMDOC|DOC_NUMERO)($|_)',95,8,'Variantes explícitas de número de documento' from dual
where not exists (select 1 from tdm_regla where identificador='IDENTIFICADOR_IDENTIDAD' and tipo_regla='COLUMN_NAME' and expresion='(^|_)(NUMERO_DOCUMENTO|NUMDOC|DOC_NUMERO)($|_)');

/* 2026-03-10 15:35 Ajuste precisión identidad/bancario: valores binarios S/N no son documentos ni cuentas */
insert into tdm_regla(regla_id,identificador,tipo_regla,expresion,puntuacion,prioridad,muestra_min,descripcion)
select seq_dm_regla.nextval,'IDENTIFICADOR_IDENTIDAD','DATA_PATTERN','^[SN]$',-260,1,10,'Bandera S/N, no NIF/NIE' from dual
where not exists (select 1 from tdm_regla where identificador='IDENTIFICADOR_IDENTIDAD' and tipo_regla='DATA_PATTERN' and expresion='^[SN]$');

insert into tdm_regla(regla_id,identificador,tipo_regla,expresion,puntuacion,prioridad,muestra_min,descripcion)
select seq_dm_regla.nextval,'IDENTIFICADOR_IDENTIDAD','DATA_PATTERN','^[0-9]{7,8}[A-Z]$',55,14,10,'Documento nacional de 7-8 dígitos + letra' from dual
where not exists (select 1 from tdm_regla where identificador='IDENTIFICADOR_IDENTIDAD' and tipo_regla='DATA_PATTERN' and expresion='^[0-9]{7,8}[A-Z]$');

/*16/03/2026 Agrega patron CIF*/
insert into tdm_regla(regla_id,identificador,tipo_regla,expresion,puntuacion,prioridad,muestra_min,descripcion)
select seq_dm_regla.nextval, 'IDENTIFICADOR_IDENTIDAD', 'DATA_PATTERN','^[ABCDEFGHJNPQRSUVW][0-9]{7}[0-9A-J]$',50,18,10, 'Formato CIF/NIF persona jurídica' from dual
where not exists (  select 1  from tdm_regla  where identificador='IDENTIFICADOR_IDENTIDAD'    and tipo_regla='DATA_PATTERN'    and expresion='^[ABCDEFGHJNPQRSUVW][0-9]{7}[0-9A-J]$');

/* 2026-03-10 15:35 Ajuste precisión bancario: flags de ingreso/cuenta no son número de cuenta */
insert into tdm_regla(regla_id,identificador,tipo_regla,expresion,puntuacion,prioridad,descripcion)
select seq_dm_regla.nextval,'IDENTIFICADOR_BANCARIO','COLUMN_NAME','(^|_)(SW|FLAG|IND|MARCA)_(.*)?(CUENTA|IBAN|CCC|SWIFT)($|_)',-320,1,'Indicadores/flags sobre cuenta, no cuenta bancaria' from dual
where not exists (select 1 from tdm_regla where identificador='IDENTIFICADOR_BANCARIO' and tipo_regla='COLUMN_NAME' and expresion='(^|_)(SW|FLAG|IND|MARCA)_(.*)?(CUENTA|IBAN|CCC|SWIFT)($|_)');

/* 2026-03-10 15:35 Ajuste precisión personal: componentes de vía bajo prefijo TITULAR no son nombre persona */
insert into tdm_regla(regla_id,identificador,tipo_regla,expresion,puntuacion,prioridad,descripcion)
select seq_dm_regla.nextval,'IDENTIFICADOR_PERSONAL','COLUMN_NAME','(^|_)(TITULAR)_(SIGLA_VIA|NOMBRE_VIA|PRIMERA_LETRA_VIA|SEGUNDA_LETRA_VIA|BLOQUE|ESCALERA|PUERTA|CODIGO_POSTAL|MUNICIPIO|PROVINCIA|VIA)($|_)',-320,1,'Componentes de dirección de titular, no identidad personal nominal' from dual
where not exists (select 1 from tdm_regla where identificador='IDENTIFICADOR_PERSONAL' and tipo_regla='COLUMN_NAME' and expresion='(^|_)(TITULAR)_(SIGLA_VIA|NOMBRE_VIA|PRIMERA_LETRA_VIA|SEGUNDA_LETRA_VIA|BLOQUE|ESCALERA|PUERTA|CODIGO_POSTAL|MUNICIPIO|PROVINCIA|VIA)($|_)');


insert into tdm_regla(regla_id,identificador,tipo_regla,expresion,puntuacion,prioridad,muestra_min,descripcion)
select seq_dm_regla.nextval,'IDENTIFICADOR_BANCARIO','DATA_PATTERN','^[SN]$',-260,1,10,'Bandera S/N, no cuenta bancaria' from dual
where not exists (select 1 from tdm_regla where identificador='IDENTIFICADOR_BANCARIO' and tipo_regla='DATA_PATTERN' and expresion='^[SN]$');

/* 2026-03-10 16:05 Ajuste recall personal: variantes explícitas de apellido */
insert into tdm_regla(regla_id,identificador,tipo_regla,expresion,puntuacion,prioridad,descripcion)
select seq_dm_regla.nextval,'IDENTIFICADOR_PERSONAL','COLUMN_NAME','(^|_)(APELLIDO_PRIMERO|APELLIDO_SEGUNDO|PRIMER_APELLIDO|SEGUNDO_APELLIDO)($|_)',95,8,'Variantes explícitas de apellido personal' from dual
where not exists (select 1 from tdm_regla where identificador='IDENTIFICADOR_PERSONAL' and tipo_regla='COLUMN_NAME' and expresion='(^|_)(APELLIDO_PRIMERO|APELLIDO_SEGUNDO|PRIMER_APELLIDO|SEGUNDO_APELLIDO)($|_)');


/* 2026-03-10 16:05 Ajuste precisión bancario: sufijo _ID en CCC/CUENTA suele ser código, no cuenta real */
insert into tdm_regla(regla_id,identificador,tipo_regla,expresion,puntuacion,prioridad,descripcion)
select seq_dm_regla.nextval,'IDENTIFICADOR_BANCARIO','COLUMN_NAME','(^|_)(CCC|CUENTA|IBAN|SWIFT)_ID($|_)',-320,1,'Identificador/código de cuenta, no cuenta bancaria sensible' from dual
where not exists (select 1 from tdm_regla where identificador='IDENTIFICADOR_BANCARIO' and tipo_regla='COLUMN_NAME' and expresion='(^|_)(CCC|CUENTA|IBAN|SWIFT)_ID($|_)');

/* 2026-03-10 16:05 Ajuste precisión bancario: códigos numéricos cortos no son cuenta */
insert into tdm_regla(regla_id,identificador,tipo_regla,expresion,puntuacion,prioridad,muestra_min,descripcion)
select seq_dm_regla.nextval,'IDENTIFICADOR_BANCARIO','DATA_PATTERN','^[0-9]{1,3}$',-260,1,10,'Código corto numérico, no cuenta/IBAN' from dual
where not exists (select 1 from tdm_regla where identificador='IDENTIFICADOR_BANCARIO' and tipo_regla='DATA_PATTERN' and expresion='^[0-9]{1,3}$');

/* 2026-03-10 16:25 Afinado precisión personal: NOMBRE_BANCO no es nombre humano */
insert into tdm_regla(regla_id,identificador,tipo_regla,expresion,puntuacion,prioridad,descripcion)
select seq_dm_regla.nextval,'IDENTIFICADOR_PERSONAL','COLUMN_NAME','(^|_)(NOMBRE_BANCO|BANCO_NOMBRE|NOMBRE_ENTIDAD_BANCARIA)($|_)',-320,1,'Nombre de entidad bancaria, no dato personal' from dual
where not exists (select 1 from tdm_regla where identificador='IDENTIFICADOR_PERSONAL' and tipo_regla='COLUMN_NAME' and expresion='(^|_)(NOMBRE_BANCO|BANCO_NOMBRE|NOMBRE_ENTIDAD_BANCARIA)($|_)');

/* 2026-03-10 16:25 Afinado precisión dirección: AYUDA_DOMICILIO es flag de ayuda, no dirección */
insert into tdm_regla(regla_id,identificador,tipo_regla,expresion,puntuacion,prioridad,descripcion)
select seq_dm_regla.nextval,'IDENTIFICADOR_DIRECCION','COLUMN_NAME','(^|_)(AYUDA_DOMICILIO|AYUDA_DIRECCION)($|_)',-320,1,'Campo de ayuda/flag sobre domicilio, no dirección sensible' from dual
where not exists (select 1 from tdm_regla where identificador='IDENTIFICADOR_DIRECCION' and tipo_regla='COLUMN_NAME' and expresion='(^|_)(AYUDA_DOMICILIO|AYUDA_DIRECCION)($|_)');

/* 2026-03-10 16:25 Afinado precisión dirección: bandera S/N no es dirección */
insert into tdm_regla(regla_id,identificador,tipo_regla,expresion,puntuacion,prioridad,muestra_min,descripcion)
select seq_dm_regla.nextval,'IDENTIFICADOR_DIRECCION','DATA_PATTERN','^[SN]$',-260,1,10,'Bandera S/N, no dirección' from dual
where not exists (select 1 from tdm_regla where identificador='IDENTIFICADOR_DIRECCION' and tipo_regla='DATA_PATTERN' and expresion='^[SN]$');

insert into tdm_regla(regla_id, identificador, tipo_regla, expresion,puntuacion, prioridad, descripcion)
select seq_dm_regla.nextval, 'IDENTIFICADOR_PERSONAL', 'COLUMN_NAME', '(^|_)(NOM|NOMSO|NOMSOL|NOMARR|NOMUEC|ACU_NOMBRE|USU_LT_USU|UNIFAM_APENU)($|_)',
       92, 8, 'Alias funcionales de nombre personal' from dual where not exists (select 1 from tdm_regla where identificador = 'IDENTIFICADOR_PERSONAL'
      and tipo_regla = 'COLUMN_NAME' and expresion = '(^|_)(NOMSO|NOMSOL|NOMARR|NOMUEC|ACU_NOMBRE|USU_LT_USU|UNIFAM_APENU)($|_)');

insert into tdm_regla(regla_id, identificador, tipo_regla, expresion, puntuacion, prioridad, descripcion)select seq_dm_regla.nextval,
       'IDENTIFICADOR_PERSONAL','COLUMN_NAME', '(^|_)(AP1SO|AP2SO|AP1SOL|AP2SOL|AP1ARR|AP2ARR|APENU1|APENU2|APENU01|APENU02)($|_)',
       95, 8, 'Alias funcionales de apellido personal' from dual where not exists (select 1 from tdm_regla where identificador = 'IDENTIFICADOR_PERSONAL'
      and tipo_regla = 'COLUMN_NAME' and expresion = '(^|_)(AP1SO|AP2SO|AP1SOL|AP2SOL|AP1ARR|AP2ARR|APENU1|APENU2|APENU01|APENU02)($|_)');


insert into tdm_regla(regla_id, identificador, tipo_regla, expresion,puntuacion, prioridad, descripcion) select seq_dm_regla.nextval,
       'IDENTIFICADOR_IDENTIDAD', 'COLUMN_NAME', '(^|_)(DNISO|DNIPEN|DNIARR|DNIUEC|DNISO01|DNIUEC01|ALQU_DNIPEN|ARR_DNIARR)($|_)',
       100,  8, 'Alias funcionales de DNI en modelos de negocio' from dual where not exists ( select 1 from tdm_regla
    where identificador = 'IDENTIFICADOR_IDENTIDAD'   and tipo_regla = 'COLUMN_NAME'  and expresion = '(^|_)(DNISO|DNIPEN|DNIARR|DNIUEC|DNISO01|DNIUEC01|ALQU_DNIPEN|ARR_DNIARR)($|_)');


insert into tdm_regla(regla_id, identificador, tipo_regla, expresion, puntuacion, prioridad, descripcion)select seq_dm_regla.nextval,
       'IDENTIFICADOR_DIRECCION','COLUMN_NAME','(^|_)(DOMISO|VIASO)($|_)', 82, 8,   'Alias funcionales de domicilio y vía' from dual
where not exists ( select 1    from tdm_regla   where identificador = 'IDENTIFICADOR_DIRECCION' and tipo_regla    = 'COLUMN_NAME'
       and expresion     = '(^|_)(DOMISO|VIASO)($|_)');

insert into tdm_regla( regla_id, identificador, tipo_regla, expresion, puntuacion, prioridad, descripcion) select seq_dm_regla.nextval,
       'IDENTIFICADOR_PERSONAL', 'COLUMN_NAME', '(^|_)(ARR_NOMARR|COP_NOMSOL|ALQU_NOMUEC|NOMSO)($|_)',  110, 7,
       'Campos funcionales de nombre personal del modelo PNCSS' from dual where not exists (select 1
      from tdm_regla  where identificador = 'IDENTIFICADOR_PERSONAL'  and tipo_regla = 'COLUMN_NAME' and expresion = '(^|_)(ARR_NOMARR|COP_NOMSOL|ALQU_NOMUEC|NOMSO)($|_)');


 insert into tdm_regla(regla_id,identificador, tipo_regla, expresion,puntuacion, prioridad,descripcion) select seq_dm_regla.nextval, 
 'IDENTIFICADOR_PERSONAL','COLUMN_NAME','(^|_)(NOMINA|NOMINAS|NOMINA_PER|NOM_PER|NOM_PAGA|NOM_PAGALAM)($|_)',-320, 1,'Negativa NOMINA'
 from dual where not exists (select 1 from tdm_regla  where identificador = 'IDENTIFICADOR_PERSONAL' and tipo_regla = 'COLUMN_NAME'
 and expresion = '((^|_)(NOMINA|NOMINAS|NOMINA_PER|NOM_PER|NOM_PAGA|NOM_PAGALAM)($|_))');

/* 2026-03-24 Ajuste precisión identidad: indicadores/cambios sobre NIF/NIE/DNI/CIF no son documento real */
insert into tdm_regla(regla_id,identificador,tipo_regla,expresion,puntuacion,prioridad,descripcion)
select seq_dm_regla.nextval,  'IDENTIFICADOR_IDENTIDAD',  'COLUMN_NAME',
  '(^|_)(CAMBIO|CHECK|FLAG|IND|MARCA|SW)_(NIF|NIE|DNI|NIFNIE|CIF)($|_)|(^|_)(NIF|NIE|DNI|NIFNIE|CIF)_(CAMBIO|CHECK|FLAG|IND|MARCA|SW)($|_)', -320,  1,       
   'Indicadores, checks o marcas sobre identidad; no contienen el documento real' from dual where not exists ( select 1 from tdm_regla 
 where identificador='IDENTIFICADOR_IDENTIDAD'   and tipo_regla='COLUMN_NAME'
  and expresion='(^|_)(CAMBIO|CHECK|FLAG|IND|MARCA|SW)_(NIF|NIE|DNI|NIFNIE|CIF)($|_)|(^|_)(NIF|NIE|DNI|NIFNIE|CIF)_(CAMBIO|CHECK|FLAG|IND|MARCA|SW)($|_)');

/* 2026-03-24 Recalibración identidad: patrón laxo 7-8 dígitos + letra queda como apoyo y no como señal fuerte */
update tdm_regla
   set puntuacion = 25,
       descripcion = 'Documento nacional de 7-8 digitos + letra (regla laxa, solo apoyo)'
 where identificador = 'IDENTIFICADOR_IDENTIDAD'
   and tipo_regla    = 'DATA_PATTERN'
   and expresion     = '^[0-9]{7,8}[A-Z]$';

/*reglas sigad */
insert into tdm_regla(regla_id, identificador, tipo_regla, expresion, puntuacion, prioridad, descripcion) select seq_dm_regla.nextval,
       'IDENTIFICADOR_PERSONAL','COLUMN_NAME','(^|_)(NOMBRE|APELLIDO1|APELLIDO2)(ELIMINAR|MANTENER)($|_)',    105,    6,  'Campos de nombre/apellidos en procesos de unificacion'
from dual where not exists ( select 1  from tdm_regla where identificador = 'IDENTIFICADOR_PERSONAL'  and tipo_regla = 'COLUMN_NAME' and expresion = '(^|_)(NOMBRE|APELLIDO1|APELLIDO2)(ELIMINAR|MANTENER)($|_)');

insert into tdm_regla(regla_id, identificador, tipo_regla, expresion, puntuacion, prioridad, descripcion) select seq_dm_regla.nextval,
       'IDENTIFICADOR_BANCARIO', 'COLUMN_NAME','(^|_)(NOMBRE|APELLIDO1|APELLIDO2)(ELIMINAR|MANTENER)($|_)', -320,   1, 'No es bancario: nombres/apellidos en procesos de unificacion'
from dual where not exists (select 1 from tdm_regla where identificador = 'IDENTIFICADOR_BANCARIO'  and tipo_regla = 'COLUMN_NAME'
      and expresion = '(^|_)(NOMBRE|APELLIDO1|APELLIDO2)(ELIMINAR|MANTENER)($|_)');
	  

insert into tdm_regla(regla_id, identificador, tipo_regla, expresion, puntuacion, prioridad, descripcion) select seq_dm_regla.nextval,
       'IDENTIFICADOR_PERSONAL', 'COLUMN_NAME', '(^|_)(ALUMNO|ALUMNA|ESTUDIANTE|DISCENTE|DOCENTE)($|_)',   82,    9,    'Roles personales del dominio educacion'
from dual where not exists (select 1 from tdm_regla where identificador = 'IDENTIFICADOR_PERSONAL'  and tipo_regla = 'COLUMN_NAME' and expresion = '(^|_)(ALUMNO|ALUMNA|ESTUDIANTE|DISCENTE|DOCENTE)($|_)');

insert into tdm_regla(regla_id, identificador, tipo_regla, expresion, puntuacion, prioridad, descripcion) select seq_dm_regla.nextval,
       'IDENTIFICADOR_DIRECCION', 'COLUMN_NAME',  '(^|_)(DOMICILIOSOCIAL(_APA[12])?|NOMBREVIA|RESTDIR)($|_)',   88,     8,  'Campos de direccion frecuentes en SIGAD educacion'
from dual where not exists ( select 1  from tdm_regla where identificador = 'IDENTIFICADOR_DIRECCION'  and tipo_regla = 'COLUMN_NAME' and expresion = '(^|_)(DOMICILIOSOCIAL(_APA[12])?|NOMBREVIA|RESTDIR)($|_)');

update tdm_regla   set expresion = '(^|_)(EMAIL|MAIL|CORREO)([0-9]{1,2})?($|_)',
       descripcion = 'Correo electrónico incluyendo variantes numeradas'
 where identificador = 'IDENTIFICADOR_EMAIL'
   and tipo_regla    = 'COLUMN_NAME'
   and expresion     = '(^|_)(EMAIL|MAIL|CORREO)($|_)';
   
   commit;