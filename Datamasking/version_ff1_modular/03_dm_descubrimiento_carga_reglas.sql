--------------------------------------------------------------------------------
-- 03_dm_descubrimiento_carga_reglas.sql
-- Carga del catalogo de reglas del motor de descubrimiento (TDM_REGLA).
--
-- * SOLO INSERT. Sin UPDATE, DELETE ni MERGE: el archivo es una siembra, no un parche.
--   Cada INSERT agrega unicamente lo que falta (clave: identificador + tipo_regla +
--   expresion), asi que se puede ejecutar varias veces. Cambiar una regla existente se
--   hace con una fila nueva y retirando la anterior fuera de este archivo (reinstalacion
--   o script de migracion).
-- * Organizacion: BLOQUE A (genericas) y BLOQUE B (negocio actual, DGA); dentro de cada
--   bloque un INSERT por identificador, en orden alfabetico; dentro de cada INSERT las
--   reglas van por tipo (COLUMN_NAME, COLUMN_COMMENT, TABLE_NAME, DATA_PATTERN) y, dentro
--   de cada tipo, primero los descartes (puntuacion negativa) y luego la evidencia.
--   El orden no cambia ningun score: el motor suma las reglas que coinciden.
-- * BLOQUE A sirve en cualquier organizacion; los patrones DATA_PATTERN de DNI/NIE/CIF,
--   IBAN ES, telefono ES y tipos de via INE son de localizacion Espana; hay nombres de
--   columna en espanol e ingles.
-- * BLOQUE B: alias y convenciones propias del negocio actual. Es lo unico que se
--   sustituye al instalar en otra organizacion.
-- * Puntuaciones negativas = descartes (la regla resta al score del identificador).
--   Umbrales: >= 85 CONFIRMADO, >= 65 PROBABLE (ambos se enmascaran), >= 45 REVISAR.
--
-- MODIFICADO   (MM/DD/YY)
-- epurisaca    10/10/26 - Reorganizacion por bloque/identificador/tipo; se retiran los DELETE de
--                         reparacion. Reglas de direccion en ingles (ADDRESS, STREET), tipos de via
--                         abreviados, sufijo numerico en nombres/apellidos ingleses y comentarios de
--                         email y apellido
-- epurisaca    10/10/26 - Seccion "CONFIGURACION SIN PUNTUACION" (NUMBER_ADMITIDO, NOMBRE_CANDIDATO,
--                         NOMBRE_PERSONAL, NOMBRE_GENERICO, CTX_PERSONA, CTX_APELLIDO): listas que
--                         antes vivian en el codigo, con puntuacion 0
-- epurisaca    10/11/26 - Cobertura de telefono y de texto libre en ingles y plural (7 reglas):
--                         TELEFONO (PHONE, MOBILE, CELL...) con descarte de flags, OBS, y
--                         NUMBER_ADMITIDO: CELULAR. Ninguna regla existente cambia
--------------------------------------------------------------------------------

-- ##############################  BLOQUE A: GENERICAS  ##############################

--------------------------------------------------------------------------------
-- A) BANCARIO (IBAN/CCC)
--------------------------------------------------------------------------------
insert into tdm_regla (regla_id, identificador, tipo_regla, expresion, puntuacion, prioridad, confianza_min, muestra_min, descripcion)
select seq_dm_regla.nextval, v.identificador, v.tipo_regla, v.expresion, v.puntuacion, v.prioridad, v.confianza_min, v.muestra_min, v.descripcion
  from (
        select 'IDENTIFICADOR_BANCARIO' identificador, 'COLUMN_NAME' tipo_regla, '(^|_)(SW|FLAG|IND|MARCA)_(.*)?(CUENTA|IBAN|CCC|SWIFT)($|_)' expresion, -320 puntuacion, 1 prioridad, to_number(null) confianza_min, to_number(null) muestra_min, 'Indicadores/flags sobre cuenta, no cuenta bancaria' descripcion from dual
        union all
        select 'IDENTIFICADOR_BANCARIO' identificador, 'COLUMN_NAME' tipo_regla, '(^|_)(CCC|CUENTA|IBAN|SWIFT)_ID($|_)' expresion, -320 puntuacion, 1 prioridad, to_number(null) confianza_min, to_number(null) muestra_min, 'Identificador/código de cuenta, no cuenta bancaria sensible' descripcion from dual
        union all
        select 'IDENTIFICADOR_BANCARIO' identificador, 'COLUMN_NAME' tipo_regla, '(^|_)(TIPO|ESTADO|CLASE|GRUPO|CATEGORIA|MONEDA|DIVISA)_(CUENTA|IBAN|CCC)($|_)|(^|_)(CUENTA|IBAN|CCC)_(TIPO|ESTADO|CLASE|GRUPO|CATEGORIA|MONEDA|DIVISA)($|_)' expresion, -320 puntuacion, 1 prioridad, to_number(null) confianza_min, to_number(null) muestra_min, 'Descarte de tipos o metadatos de cuenta bancaria' descripcion from dual
        union all
        select 'IDENTIFICADOR_BANCARIO' identificador, 'COLUMN_NAME' tipo_regla, '(^|_)(IBAN|CUENTA|CCC|SWIFT)($|_)' expresion, 95 puntuacion, 10 prioridad, to_number(null) confianza_min, to_number(null) muestra_min, 'Cuenta bancaria/IBAN' descripcion from dual
        union all
        select 'IDENTIFICADOR_BANCARIO' identificador, 'DATA_PATTERN' tipo_regla, '^[SN]$' expresion, -260 puntuacion, 1 prioridad, to_number(null) confianza_min, 10 muestra_min, 'Bandera S/N, no cuenta bancaria' descripcion from dual
        union all
        select 'IDENTIFICADOR_BANCARIO' identificador, 'DATA_PATTERN' tipo_regla, '^[0-9]{1,3}$' expresion, -260 puntuacion, 1 prioridad, to_number(null) confianza_min, 10 muestra_min, 'Código corto numérico, no cuenta/IBAN' descripcion from dual
        union all
        select 'IDENTIFICADOR_BANCARIO' identificador, 'DATA_PATTERN' tipo_regla, '^ES[0-9]{22}$' expresion, 65 puntuacion, 20 prioridad, 1 confianza_min, 10 muestra_min, 'IBAN español' descripcion from dual
        union all
        select 'IDENTIFICADOR_BANCARIO' identificador, 'DATA_PATTERN' tipo_regla, '^ES[0-9A-Z]{2,22}$' expresion, 45 puntuacion, 22 prioridad, 1 confianza_min, 10 muestra_min, 'IBAN parcial o truncado (migraciones/cambios)' descripcion from dual
        union all
        select 'IDENTIFICADOR_BANCARIO' identificador, 'DATA_PATTERN' tipo_regla, '^[0-9]{10,24}$' expresion, 35 puntuacion, 23 prioridad, 1 confianza_min, 10 muestra_min, 'Número de cuenta numérico (sin prefijo país)' descripcion from dual
       ) v
 where not exists (select 1 from tdm_regla r
                    where r.identificador = v.identificador
                      and r.tipo_regla    = v.tipo_regla
                      and r.expresion     = v.expresion);

--------------------------------------------------------------------------------
-- A) DIRECCION
--------------------------------------------------------------------------------
-- Reglas de refutacion por contenido: el token 'DIRECCION' suma 85 aunque los valores sean IPs.
-- Una direccion postal no tiene formato que la confirme por contenido, pero si se puede refutar:
-- si los valores tienen forma de IP, correo o URL el dato manda sobre el nombre (puntuacion
-- negativa, proporcional a las filas que cumplen la forma). La regla de nombre cubre
-- IP_* / DIRECCION_IP|MAC|WEB|URL|CORREO... aunque la columna este vacia.
-- Ingles: ADDRESS (85) con sus refutaciones tecnicas (IP_ADDRESS, EMAIL_ADDRESS, ADDRESS_TYPE...),
-- STREET (40, necesita datos) y tipos de via abreviados (CL, AV, PS, PZ).
insert into tdm_regla (regla_id, identificador, tipo_regla, expresion, puntuacion, prioridad, confianza_min, muestra_min, descripcion)
select seq_dm_regla.nextval, v.identificador, v.tipo_regla, v.expresion, v.puntuacion, v.prioridad, v.confianza_min, v.muestra_min, v.descripcion
  from (
        select 'IDENTIFICADOR_DIRECCION' identificador, 'COLUMN_NAME' tipo_regla, '(^|_)(AYUDA_DOMICILIO|AYUDA_DIRECCION)($|_)' expresion, -320 puntuacion, 1 prioridad, to_number(null) confianza_min, to_number(null) muestra_min, 'Campo de ayuda/flag sobre domicilio, no dirección sensible' descripcion from dual
        union all
        select 'IDENTIFICADOR_DIRECCION' identificador, 'COLUMN_NAME' tipo_regla, '(^|_)(OBS|OBSERVACION|OBSERVACIONES|COMENTARIO|REV).*(_)?(DOMICILIO|DIRECCION)($|_)' expresion, -260 puntuacion, 1 prioridad, to_number(null) confianza_min, to_number(null) muestra_min, 'Observación de domicilio no es dato dirección estructurada' descripcion from dual
        union all
        select 'IDENTIFICADOR_DIRECCION' identificador, 'COLUMN_NAME' tipo_regla, '(^|_)(TIPO_DOMICILIO|TIPO_VIA|ID_VIA(_ACCESO)?|ID_TIPO_PLAZA)($|_)' expresion, -260 puntuacion, 1 prioridad, to_number(null) confianza_min, to_number(null) muestra_min, 'Campos tipo/código/ID no son dirección sensible' descripcion from dual
        union all
        select 'IDENTIFICADOR_DIRECCION' identificador, 'COLUMN_NAME' tipo_regla, '(^|_)(VIA)_(PAGO|COBRO|COMUNICACION|ACCESO|TRANSMISION|RECLAMACION|CONTACTO)($|_)' expresion, -260 puntuacion, 1 prioridad, to_number(null) confianza_min, to_number(null) muestra_min, 'Descarte de canales técnicos (no son vías de domicilio)' descripcion from dual
        union all
        select 'IDENTIFICADOR_DIRECCION' identificador, 'COLUMN_NAME' tipo_regla, '(^|_)(DESCRI(_)?VIA|DESC(_)?VIA|TIPO(_)?VIA|ABREV(_)?VIA|NOMTIPOVIA)($|_)' expresion, -240 puntuacion, 1 prioridad, to_number(null) confianza_min, to_number(null) muestra_min, 'Descripción/abreviatura de tipo de vía, no dirección de persona' descripcion from dual
        union all
        select 'IDENTIFICADOR_DIRECCION' identificador, 'COLUMN_NAME' tipo_regla, '(^|_)(CODIGO_VIA|NUMERO_VIA|DEN_CP|CP)($|_)' expresion, -230 puntuacion, 1 prioridad, to_number(null) confianza_min, to_number(null) muestra_min, 'Campos técnicos de vía/código postal' descripcion from dual
        union all
        select 'IDENTIFICADOR_DIRECCION' identificador, 'COLUMN_NAME' tipo_regla, '(^|_)(DEN_CP|CP|CODIGO_POSTAL)($|_)' expresion, -220 puntuacion, 1 prioridad, to_number(null) confianza_min, to_number(null) muestra_min, 'Código postal: no enmascarar como dirección sensible' descripcion from dual
        union all
        select 'IDENTIFICADOR_DIRECCION' identificador, 'COLUMN_NAME' tipo_regla, '(^|_)CHECK_' expresion, -220 puntuacion, 1 prioridad, to_number(null) confianza_min, to_number(null) muestra_min, 'Campo técnico de validación/check, no dirección' descripcion from dual
        union all
        select 'IDENTIFICADOR_DIRECCION' identificador, 'COLUMN_NAME' tipo_regla, '(^|_)(CALLE|VIA)($|_)' expresion, -50 puntuacion, 3 prioridad, to_number(null) confianza_min, to_number(null) muestra_min, 'Nombre de columna genérico, requiere soporte por patrón/contexto' descripcion from dual
        union all
        select 'IDENTIFICADOR_DIRECCION' identificador, 'COLUMN_NAME' tipo_regla, '(^|_)(IP|IPV4|IPV6|MAC)($|_)|(^|_)(DIRECCION|DIR)_(IP|IPV4|IPV6|MAC|WEB|URL|HOST|CORREO|EMAIL|MAIL)($|_)' expresion, -260 puntuacion, 1 prioridad, to_number(null) confianza_min, to_number(null) muestra_min, 'Direccion IP/MAC/web/correo: no es domicilio postal' descripcion from dual
        union all
        select 'IDENTIFICADOR_DIRECCION' identificador, 'COLUMN_NAME' tipo_regla, '(^|_)(IP|MAC|EMAIL|MAIL|WEB|URL|HOST|REMOTE|CLIENT|SERVER|SRC|SOURCE|DST|DEST)_(ADDRESS|ADDR)($|_)|(^|_)(ADDRESS|ADDR)_(IP|MAC|EMAIL|MAIL|WEB|URL|HOST|TYPE|ID|CODE|STATUS|FLAG)($|_)' expresion, -260 puntuacion, 1 prioridad, to_number(null) confianza_min, to_number(null) muestra_min, 'Address tecnica (IP/MAC/web/correo/host) o metadato de address (ingles): no es domicilio postal' descripcion from dual
        union all
        select 'IDENTIFICADOR_DIRECCION' identificador, 'COLUMN_NAME' tipo_regla, '(^|_)(NOMVIA|NOMBRE_VIA|NOM_VIA|DIR_NOMVIA)($|_)' expresion, 78 puntuacion, 9 prioridad, to_number(null) confianza_min, to_number(null) muestra_min, 'Nombre de vía/dirección sin token literal DIRECCION' descripcion from dual
        union all
        select 'IDENTIFICADOR_DIRECCION' identificador, 'COLUMN_NAME' tipo_regla, '(^|_)(DIRECCION|DOMICILIO|CALLE|VIA|AVENIDA|PLAZA|CP|CODIGO_POSTAL)($|_)' expresion, 85 puntuacion, 10 prioridad, to_number(null) confianza_min, to_number(null) muestra_min, 'Dirección' descripcion from dual
        union all
        select 'IDENTIFICADOR_DIRECCION' identificador, 'COLUMN_NAME' tipo_regla, '(^|_)(ADDRESS|(HOME|POSTAL|MAILING|BILLING|SHIPPING|STREET)_ADDR)([0-9]{1,2})?($|_)' expresion, 85 puntuacion, 10 prioridad, to_number(null) confianza_min, to_number(null) muestra_min, 'Direccion postal (ingles): ADDRESS, ADDRESS1/2, HOME_ADDRESS, STREET_ADDRESS' descripcion from dual
        union all
        select 'IDENTIFICADOR_DIRECCION' identificador, 'COLUMN_NAME' tipo_regla, '(^|_)(STREET|STREETNAME)($|_)' expresion, 40 puntuacion, 8 prioridad, to_number(null) confianza_min, to_number(null) muestra_min, 'Calle (ingles): evidencia debil, requiere soporte por patron de datos' descripcion from dual
        union all
        select 'IDENTIFICADOR_DIRECCION' identificador, 'COLUMN_COMMENT' tipo_regla, '(DIRECCI[OÓ]N|ADDRESS)[[:space:]]+(IP|MAC|WEB|URL|EMAIL|E-MAIL|DE[[:space:]]+CORREO|DE[[:space:]]+EMAIL)|(IP|MAC|WEB|URL|EMAIL|E-MAIL)[[:space:]]+ADDRESS' expresion, -260 puntuacion, 1 prioridad, to_number(null) confianza_min, to_number(null) muestra_min, 'Comentario: direccion IP/MAC/web/correo, no domicilio postal' descripcion from dual
        union all
        select 'IDENTIFICADOR_DIRECCION' identificador, 'COLUMN_COMMENT' tipo_regla, '(^|[^[:alpha:]])(DIRECCI[OÓ]N|DOMICILIO|ADDRESS)([^[:alpha:]]|$)' expresion, 40 puntuacion, 12 prioridad, to_number(null) confianza_min, to_number(null) muestra_min, 'Comentario que menciona direccion/domicilio/address: evidencia de apoyo' descripcion from dual
        union all
        select 'IDENTIFICADOR_DIRECCION' identificador, 'TABLE_NAME' tipo_regla, '(^|_)(TIPOS?VIA|TIPO_VIA|CAT(ALOGO)?|MAESTR[OA]|PARAM|LOOKUP|DICCIONARIO|LOV|LISTA)($|_)' expresion, -220 puntuacion, 2 prioridad, to_number(null) confianza_min, to_number(null) muestra_min, 'Tablas de tipo vía/catálogo no son dirección personal' descripcion from dual
        union all
        select 'IDENTIFICADOR_DIRECCION' identificador, 'DATA_PATTERN' tipo_regla, '^[SN]$' expresion, -260 puntuacion, 1 prioridad, to_number(null) confianza_min, 10 muestra_min, 'Bandera S/N, no dirección' descripcion from dual
        union all
        select 'IDENTIFICADOR_DIRECCION' identificador, 'DATA_PATTERN' tipo_regla, '^[0-9]{1,6}$' expresion, -220 puntuacion, 1 prioridad, to_number(null) confianza_min, 10 muestra_min, 'Contenido numérico puro, no dirección textual' descripcion from dual
        union all
        select 'IDENTIFICADOR_DIRECCION' identificador, 'DATA_PATTERN' tipo_regla, '^[0-9]{1,3}(\.[0-9]{1,3}){3}$' expresion, -260 puntuacion, 1 prioridad, to_number(null) confianza_min, 10 muestra_min, 'Valor con forma de IPv4, no domicilio' descripcion from dual
        union all
        select 'IDENTIFICADOR_DIRECCION' identificador, 'DATA_PATTERN' tipo_regla, '^[0-9A-F]{0,4}(:[0-9A-F]{0,4}){2,7}$' expresion, -260 puntuacion, 1 prioridad, to_number(null) confianza_min, 10 muestra_min, 'Valor con forma de IPv6, no domicilio' descripcion from dual
        union all
        select 'IDENTIFICADOR_DIRECCION' identificador, 'DATA_PATTERN' tipo_regla, '^[^@[:space:]]+@[^@[:space:]]+\.[A-Z]{2,}$' expresion, -260 puntuacion, 1 prioridad, to_number(null) confianza_min, 10 muestra_min, 'Valor con forma de correo electronico, no domicilio' descripcion from dual
        union all
        select 'IDENTIFICADOR_DIRECCION' identificador, 'DATA_PATTERN' tipo_regla, '^(HTTPS?|FTP)://' expresion, -260 puntuacion, 1 prioridad, to_number(null) confianza_min, 10 muestra_min, 'Valor con forma de URL, no domicilio' descripcion from dual
        union all
        select 'IDENTIFICADOR_DIRECCION' identificador, 'DATA_PATTERN' tipo_regla, '(^|[[:space:]])(C/|CALLE|AVDA|AVENIDA|PASEO|PLAZA|RONDA|CAMINO|TRAVESIA|TRAVESÍA)([[:space:]]|$)' expresion, 45 puntuacion, 16 prioridad, to_number(null) confianza_min, 10 muestra_min, 'Tokens direccionales típicos en contenido' descripcion from dual
        union all
        select 'IDENTIFICADOR_DIRECCION' identificador, 'DATA_PATTERN' tipo_regla, '(^|[[:space:]])(CL|AV|AVD|PS|PZ|PZA|CTRA|CMNO|URB|GTA|TRVA|RDA)([[:space:].]|$)' expresion, 45 puntuacion, 17 prioridad, to_number(null) confianza_min, 10 muestra_min, 'Tipo de via abreviado (CL, AV, PS, PZ...) al inicio de la direccion: formato INE' descripcion from dual
        union all
        select 'IDENTIFICADOR_DIRECCION' identificador, 'DATA_PATTERN' tipo_regla, '(^|[[:space:]])(STREET|AVENUE|AVE|ROAD|LANE|BLVD|BOULEVARD)([[:space:].,]|$)' expresion, 45 puntuacion, 18 prioridad, to_number(null) confianza_min, 10 muestra_min, 'Tokens direccionales en ingles (STREET, AVENUE, ROAD...)' descripcion from dual
       ) v
 where not exists (select 1 from tdm_regla r
                    where r.identificador = v.identificador
                      and r.tipo_regla    = v.tipo_regla
                      and r.expresion     = v.expresion);

--------------------------------------------------------------------------------
-- A) EMAIL
--------------------------------------------------------------------------------
-- Nombre en ingles ya cubierto: EMAIL, MAIL, E_MAIL, EMAIL_ADDRESS, CORREO (+ sufijo numerico).
-- Una columna de email con muchos nulos se descarta por nulidad (ALTA_NULIDAD_EN_MUESTRA, ver 22).
insert into tdm_regla (regla_id, identificador, tipo_regla, expresion, puntuacion, prioridad, confianza_min, muestra_min, descripcion)
select seq_dm_regla.nextval, v.identificador, v.tipo_regla, v.expresion, v.puntuacion, v.prioridad, v.confianza_min, v.muestra_min, v.descripcion
  from (
        select 'IDENTIFICADOR_EMAIL' identificador, 'COLUMN_NAME' tipo_regla, '(^|_)(EMAIL|MAIL)_(DEFAULT|DEFECTO)$|(^|_)(DEFAULT|DEFECTO)_(EMAIL|MAIL)($|_)' expresion, -260 puntuacion, 1 prioridad, to_number(null) confianza_min, to_number(null) muestra_min, 'Banderas/default de email, no dato personal directo' descripcion from dual
        union all
        select 'IDENTIFICADOR_EMAIL' identificador, 'COLUMN_NAME' tipo_regla, '(^|_)(EMAIL|MAIL|CORREO)([0-9]{1,2})?($|_)' expresion, 90 puntuacion, 10 prioridad, to_number(null) confianza_min, to_number(null) muestra_min, 'Correo electrónico incluyendo variantes numeradas' descripcion from dual
        union all
        select 'IDENTIFICADOR_EMAIL' identificador, 'COLUMN_COMMENT' tipo_regla, '(^|[^[:alpha:]])(E-?MAIL|CORREO([[:space:]]+ELECTR[OÓ]NICO)?)([^[:alpha:]]|$)' expresion, 40 puntuacion, 12 prioridad, to_number(null) confianza_min, to_number(null) muestra_min, 'Comentario que menciona correo electronico/email: evidencia de apoyo' descripcion from dual
        union all
        select 'IDENTIFICADOR_EMAIL' identificador, 'DATA_PATTERN' tipo_regla, '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$' expresion, 55 puntuacion, 20 prioridad, 1 confianza_min, 10 muestra_min, 'Formato email' descripcion from dual
       ) v
 where not exists (select 1 from tdm_regla r
                    where r.identificador = v.identificador
                      and r.tipo_regla    = v.tipo_regla
                      and r.expresion     = v.expresion);

--------------------------------------------------------------------------------
-- A) IDENTIDAD (NIF/NIE/DNI/CIF)
--------------------------------------------------------------------------------
insert into tdm_regla (regla_id, identificador, tipo_regla, expresion, puntuacion, prioridad, confianza_min, muestra_min, descripcion)
select seq_dm_regla.nextval, v.identificador, v.tipo_regla, v.expresion, v.puntuacion, v.prioridad, v.confianza_min, v.muestra_min, v.descripcion
  from (
        select 'IDENTIFICADOR_IDENTIDAD' identificador, 'COLUMN_NAME' tipo_regla, '(^|_)(MARCA_DNI|SW_DNI|FLAG_DNI|IND_DNI|CHECK_DNI)($|_)' expresion, -320 puntuacion, 1 prioridad, to_number(null) confianza_min, to_number(null) muestra_min, 'Marca/flag/check de DNI, no dato identidad' descripcion from dual
        union all
        select 'IDENTIFICADOR_IDENTIDAD' identificador, 'COLUMN_NAME' tipo_regla, '(^|_)(CAMBIO|CHECK|FLAG|IND|MARCA|SW)_(NIF|NIE|DNI|NIFNIE|CIF)($|_)|(^|_)(NIF|NIE|DNI|NIFNIE|CIF)_(CAMBIO|CHECK|FLAG|IND|MARCA|SW)($|_)' expresion, -320 puntuacion, 1 prioridad, to_number(null) confianza_min, to_number(null) muestra_min, 'Indicadores, checks o marcas sobre identidad; no contienen el documento real' descripcion from dual
        union all
        select 'IDENTIFICADOR_IDENTIDAD' identificador, 'COLUMN_NAME' tipo_regla, '(^|_)(IT_DOCUMENTO|TIPO_DOCUMENTO|ID_DOCUMENTO|COD_DOCUMENTO)($|_)' expresion, -300 puntuacion, 1 prioridad, to_number(null) confianza_min, to_number(null) muestra_min, 'Códigos/ítems de documento no son identidad personal' descripcion from dual
        union all
        select 'IDENTIFICADOR_IDENTIDAD' identificador, 'COLUMN_NAME' tipo_regla, '(^|_)(TIPO_NIF|TIPO_DNI|TIPO_NIE|CODIGO_NIF|COD_NIF)($|_)' expresion, -260 puntuacion, 1 prioridad, to_number(null) confianza_min, to_number(null) muestra_min, 'Tipo/código de identidad, no dato sensible directo' descripcion from dual
        union all
        select 'IDENTIFICADOR_IDENTIDAD' identificador, 'COLUMN_NAME' tipo_regla, '(^|_)(IDTIPODOCUMENTO|TIPODOCUMENTO|TIPO_DOCUMENTO|COD_TIPODOC)($|_)' expresion, -260 puntuacion, 1 prioridad, to_number(null) confianza_min, to_number(null) muestra_min, 'Tipo/código de documento, no identidad sensible' descripcion from dual
        union all
        select 'IDENTIFICADOR_IDENTIDAD' identificador, 'COLUMN_NAME' tipo_regla, '(^|_)(NDOCUMENTO|NUM_DOCUMENTO|NRO_DOCUMENTO)($|_)' expresion, 95 puntuacion, 8 prioridad, to_number(null) confianza_min, to_number(null) muestra_min, 'Documento de identidad por nomenclatura NDOCUMENTO/NUM_DOCUMENTO' descripcion from dual
        union all
        select 'IDENTIFICADOR_IDENTIDAD' identificador, 'COLUMN_NAME' tipo_regla, '(^|_)(NUMERO_DOCUMENTO|NUMDOC|DOC_NUMERO)($|_)' expresion, 95 puntuacion, 8 prioridad, to_number(null) confianza_min, to_number(null) muestra_min, 'Variantes explícitas de número de documento' descripcion from dual
        union all
        select 'IDENTIFICADOR_IDENTIDAD' identificador, 'COLUMN_NAME' tipo_regla, '(^|_)(CIF|DOCIDENT|DOC_IDENT|NIF_CIF|CIF_NIF)($|_)' expresion, 95 puntuacion, 9 prioridad, to_number(null) confianza_min, to_number(null) muestra_min, 'CIF y variantes de identificador fiscal/documental' descripcion from dual
        union all
        select 'IDENTIFICADOR_IDENTIDAD' identificador, 'COLUMN_NAME' tipo_regla, '(^|_)(NIF|NIE|DNI|DOC_IDENTIDAD|DOCUMENTO_IDENTIDAD)($|_)' expresion, 110 puntuacion, 10 prioridad, to_number(null) confianza_min, to_number(null) muestra_min, 'Documento de identidad (token explícito)' descripcion from dual
        union all
        select 'IDENTIFICADOR_IDENTIDAD' identificador, 'COLUMN_NAME' tipo_regla, '(^|_)DOC($|_)' expresion, 50 puntuacion, 9 prioridad, to_number(null) confianza_min, to_number(null) muestra_min, 'DOC suelto: evidencia débil, solo confirma si los datos son documentos válidos' descripcion from dual
        union all
        select 'IDENTIFICADOR_IDENTIDAD' identificador, 'TABLE_NAME' tipo_regla, '(^|_)(REFERENCIAS?_PUBLICAS?|DATOS_PUBLICOS|DATASET_PUBLICO)($|_)' expresion, -300 puntuacion, 1 prioridad, to_number(null) confianza_min, to_number(null) muestra_min, 'Tablas de referencia pública: sus documentos no son datos personales a proteger' descripcion from dual
        union all
        select 'IDENTIFICADOR_IDENTIDAD' identificador, 'DATA_PATTERN' tipo_regla, '^[0-9]{1,3}$' expresion, -260 puntuacion, 1 prioridad, to_number(null) confianza_min, 10 muestra_min, 'Código corto numérico, no identidad española' descripcion from dual
        union all
        select 'IDENTIFICADOR_IDENTIDAD' identificador, 'DATA_PATTERN' tipo_regla, '^[SN]$' expresion, -260 puntuacion, 1 prioridad, to_number(null) confianza_min, 10 muestra_min, 'Bandera S/N, no NIF/NIE' descripcion from dual
        union all
        select 'IDENTIFICADOR_IDENTIDAD' identificador, 'DATA_PATTERN' tipo_regla, '^[0-9]{7,8}[A-Z]$' expresion, 25 puntuacion, 14 prioridad, 1 confianza_min, 10 muestra_min, 'Documento nacional de 7-8 digitos + letra (regla laxa, solo apoyo)' descripcion from dual
        union all
        select 'IDENTIFICADOR_IDENTIDAD' identificador, 'DATA_PATTERN' tipo_regla, '^[ABCDEFGHJNPQRSUVW][0-9]{7}[0-9A-J]$' expresion, 50 puntuacion, 18 prioridad, 1 confianza_min, 10 muestra_min, 'Formato CIF/NIF persona jurídica' descripcion from dual
        union all
        select 'IDENTIFICADOR_IDENTIDAD' identificador, 'DATA_PATTERN' tipo_regla, '^[0-9]{8}[A-Z]$|^[XYZ][0-9]{7}[A-Z]$' expresion, 60 puntuacion, 20 prioridad, 1 confianza_min, 10 muestra_min, 'Formato DNI/NIE' descripcion from dual
       ) v
 where not exists (select 1 from tdm_regla r
                    where r.identificador = v.identificador
                      and r.tipo_regla    = v.tipo_regla
                      and r.expresion     = v.expresion);

--------------------------------------------------------------------------------
-- A) OBS (texto libre / observaciones)
--------------------------------------------------------------------------------
insert into tdm_regla (regla_id, identificador, tipo_regla, expresion, puntuacion, prioridad, confianza_min, muestra_min, descripcion)
select seq_dm_regla.nextval, v.identificador, v.tipo_regla, v.expresion, v.puntuacion, v.prioridad, v.confianza_min, v.muestra_min, v.descripcion
  from (
        select 'IDENTIFICADOR_OBS' identificador, 'COLUMN_NAME' tipo_regla, '(^|_)(OBS|OBSERVACION|OBSERVACIONES|COMENTARIO|REV).*(_)?(DOMICILIO|DIRECCION)($|_)' expresion, 95 puntuacion, 5 prioridad, to_number(null) confianza_min, to_number(null) muestra_min, 'Observaciones de domicilio/dirección se tratan como OBS' descripcion from dual
        union all
        select 'IDENTIFICADOR_OBS' identificador, 'COLUMN_NAME' tipo_regla, '(^|_)(NOTA|OBS|OBSERVACION|OBSERVACIONES)($|_)' expresion, 90 puntuacion, 6 prioridad, to_number(null) confianza_min, to_number(null) muestra_min, 'Campos de observaciones/notas a enmascarar' descripcion from dual
        union all
        select 'IDENTIFICADOR_OBS' identificador, 'COLUMN_NAME' tipo_regla, '(^|_)(DESCRIPCION|CONSULTA|RESPUESTA|DETALLE)($|_)' expresion, 55 puntuacion, 7 prioridad, to_number(null) confianza_min, to_number(null) muestra_min, 'Texto libre potencial (requiere validación por patrón de datos)' descripcion from dual
        union all
        select 'IDENTIFICADOR_OBS' identificador, 'COLUMN_NAME' tipo_regla, '(^|_)(MENSAJE|COMENTARIO|OBS|OBSERVACION|OBSERVACIONES|NOTA|TEXTO)($|_)' expresion, 35 puntuacion, 8 prioridad, to_number(null) confianza_min, to_number(null) muestra_min, 'Columna potencial OBS, requiere evidencia de datos' descripcion from dual
        union all
        select 'IDENTIFICADOR_OBS' identificador, 'COLUMN_NAME' tipo_regla, '(^|_)(NOTAS|OBSERV|NOTE|NOTES|REMARK|REMARKS|OBSERVATION|OBSERVATIONS)($|_)' expresion, 90 puntuacion, 6 prioridad, to_number(null) confianza_min, to_number(null) muestra_min, 'Notas/observaciones: plural, abreviatura e ingles' descripcion from dual
        union all
        select 'IDENTIFICADOR_OBS' identificador, 'COLUMN_NAME' tipo_regla, '(^|_)(DESCRIPCIONES|DETALLES|MOTIVO|RESUMEN|JUSTIFICACION|DESCRIPTION|DESCRIPTIONS|DETAIL|DETAILS|RESPONSE|ANSWER)($|_)' expresion, 55 puntuacion, 7 prioridad, to_number(null) confianza_min, to_number(null) muestra_min, 'Texto libre potencial: plural, terminos afines e ingles (requiere validacion por patron de datos)' descripcion from dual
        union all
        select 'IDENTIFICADOR_OBS' identificador, 'COLUMN_NAME' tipo_regla, '(^|_)(COMENTARIOS|MENSAJES|TEXTOS|COMMENT|COMMENTS|MESSAGE|MESSAGES|TEXT|MEMO)($|_)' expresion, 35 puntuacion, 8 prioridad, to_number(null) confianza_min, to_number(null) muestra_min, 'Columna potencial OBS (plural e ingles), requiere evidencia de datos' descripcion from dual
        union all
        select 'IDENTIFICADOR_OBS' identificador, 'TABLE_NAME' tipo_regla, '(^|_)(BAREMO|PESTANAS?|TIPOINGRESO|TIPOID|ROL|ACCION|PARENTESCO)($|_)' expresion, -210 puntuacion, 1 prioridad, to_number(null) confianza_min, to_number(null) muestra_min, 'Tablas de catálogo/listado no suelen contener observaciones sensibles' descripcion from dual
        union all
        select 'IDENTIFICADOR_OBS' identificador, 'TABLE_NAME' tipo_regla, '(^|_)(CAT|CATALOG|CATALOGO|PARAM|TIPO|PARENTESCO|PREGUNTA|PESTANA|PESTAÑA|COMODIN|MAESTRO|DICCIONARIO|LOOKUP|LOV)($|_)' expresion, -180 puntuacion, 2 prioridad, to_number(null) confianza_min, to_number(null) muestra_min, 'Tablas de catálogo/listado/documento con baja probabilidad de OBS sensible' descripcion from dual
        union all
        select 'IDENTIFICADOR_OBS' identificador, 'TABLE_NAME' tipo_regla, '(^|_)(DOCUMENTO|DOCUMENTOS)($|_)' expresion, -100 puntuacion, 2 prioridad, to_number(null) confianza_min, to_number(null) muestra_min, 'Tabla de documentos: penaliza columnas de texto débiles, no las de nombre OBS explícito' descripcion from dual
        union all
        select 'IDENTIFICADOR_OBS' identificador, 'DATA_PATTERN' tipo_regla, '^(APROBADO|DENEGADO|RECHAZADO|ACEPTADO|PENDIENTE|VARIACION|VARIACIÓN)$' expresion, -100 puntuacion, 1 prioridad, to_number(null) confianza_min, 500 muestra_min, 'Estado corto, no observación' descripcion from dual
        union all
        select 'IDENTIFICADOR_OBS' identificador, 'DATA_PATTERN' tipo_regla, '^(OK|KO|SI|SÍ|NO|TRUE|FALSE|APROBADO|DENEGADO|RECHAZADO|ACEPTADO|PENDIENTE|VARIACION|VARIACIÓN)$' expresion, -160 puntuacion, 2 prioridad, to_number(null) confianza_min, 10 muestra_min, 'Estados/respuestas cortas no son observación sensible' descripcion from dual
        union all
        select 'IDENTIFICADOR_OBS' identificador, 'DATA_PATTERN' tipo_regla, '^.{1,20}$' expresion, -45 puntuacion, 3 prioridad, to_number(null) confianza_min, 10 muestra_min, 'Texto corto, normalmente no observación sensible' descripcion from dual
        union all
        select 'IDENTIFICADOR_OBS' identificador, 'DATA_PATTERN' tipo_regla, '^.{40,}$' expresion, 50 puntuacion, 12 prioridad, to_number(null) confianza_min, 10 muestra_min, 'Texto largo compatible con observación sensible' descripcion from dual
        union all
        select 'IDENTIFICADOR_OBS' identificador, 'DATA_PATTERN' tipo_regla, '[0-9]{8}[A-Z]|[XYZ][0-9]{7}[A-Z]|[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}|ES[0-9]{22}' expresion, 60 puntuacion, 11 prioridad, 1 confianza_min, 10 muestra_min, 'PII incrustada en texto libre (DNI/NIE, email o IBAN dentro del texto)' descripcion from dual
       ) v
 where not exists (select 1 from tdm_regla r
                    where r.identificador = v.identificador
                      and r.tipo_regla    = v.tipo_regla
                      and r.expresion     = v.expresion);

--------------------------------------------------------------------------------
-- A) PERSONAL (nombres y apellidos)
--------------------------------------------------------------------------------
-- Nombre completo ('NOMBRE_COMPLETO', 'FULL_NAME'...): la columna ya lleva los apellidos, asi que
-- no le corresponde la penalizacion NOMBRE_SIN_APELLIDOS_TABLA (-220). La regla suma 140: con datos
-- que parecen nombres (rescate semantico +170) sube a CONFIRMADO; sin esa evidencia sigue descartada.
-- Nombres/apellidos inequivocos en ingles (FIRST_NAME, LAST_NAME, SURNAME...); el sufijo numerico
-- (SURNAME2, LASTNAME2) va en regla aparte porque el token termina en digito. 'NAME' a secas puntua
-- 75 (PROBABLE) pero 22 lo somete a una compuerta de datos propia (func_dm_es_nombre_generico): con
-- columna de apellido en la tabla exige ratio semantico >= 0.70; sin ella exige contexto de persona
-- y >= 0.90; si no, queda REVISAR/N (NOMBRE_GENERICO_SIN_SEMANTICA). Para una tabla sin contexto se
-- fuerza con TDM_EXCEPCION_COL.
-- No hay reglas centinela de contenido de nombre: el gate de IDENTIFICADOR_PERSONAL es el nombre de columna.
insert into tdm_regla (regla_id, identificador, tipo_regla, expresion, puntuacion, prioridad, confianza_min, muestra_min, descripcion)
select seq_dm_regla.nextval, v.identificador, v.tipo_regla, v.expresion, v.puntuacion, v.prioridad, v.confianza_min, v.muestra_min, v.descripcion
  from (
        select 'IDENTIFICADOR_PERSONAL' identificador, 'COLUMN_NAME' tipo_regla, '(^|_)(TITULAR)_(SIGLA_VIA|NOMBRE_VIA|PRIMERA_LETRA_VIA|SEGUNDA_LETRA_VIA|BLOQUE|ESCALERA|PUERTA|CODIGO_POSTAL|MUNICIPIO|PROVINCIA|VIA)($|_)' expresion, -320 puntuacion, 1 prioridad, to_number(null) confianza_min, to_number(null) muestra_min, 'Componentes de dirección de titular, no identidad personal nominal' descripcion from dual
        union all
        select 'IDENTIFICADOR_PERSONAL' identificador, 'COLUMN_NAME' tipo_regla, '(^|_)(NOMBRE_BANCO|BANCO_NOMBRE|NOMBRE_ENTIDAD_BANCARIA)($|_)' expresion, -320 puntuacion, 1 prioridad, to_number(null) confianza_min, to_number(null) muestra_min, 'Nombre de entidad bancaria, no dato personal' descripcion from dual
        union all
        select 'IDENTIFICADOR_PERSONAL' identificador, 'COLUMN_NAME' tipo_regla, '(^|_)(NOMINA|NOMINAS|NOMINA_PER|NOM_PER|NOM_PAGA|NOM_PAGALAM)($|_)' expresion, -320 puntuacion, 1 prioridad, to_number(null) confianza_min, to_number(null) muestra_min, 'Negativa NOMINA' descripcion from dual
        union all
        select 'IDENTIFICADOR_PERSONAL' identificador, 'COLUMN_NAME' tipo_regla, '(^|_)(NOMBRE)_(TABLA|COLUMNA|CAMPO|PROCESO|TAREA|JOB|CLASE|METODO|ROL|PERFIL|GRUPO|ESTADO|CATEGORIA|TIPO|PLANTILLA|REPORTE|INFORME|LOG|IMAGEN|RUTA|PATH|ACCION|VALOR|UNIDAD|MEDIDA)($|_)' expresion, -320 puntuacion, 1 prioridad, to_number(null) confianza_min, to_number(null) muestra_min, 'Descarte de nombres de metadatos/procesos técnicos' descripcion from dual
        union all
        select 'IDENTIFICADOR_PERSONAL' identificador, 'COLUMN_NAME' tipo_regla, '(^|_)(NOMBRE_(ENTIDAD|LOCALIDAD|COMARCA|MUNICIPIO|PROVINCIA|PAIS|REGION))($|_)' expresion, -280 puntuacion, 1 prioridad, to_number(null) confianza_min, to_number(null) muestra_min, 'Nombre geográfico/administrativo no personal' descripcion from dual
        union all
        select 'IDENTIFICADOR_PERSONAL' identificador, 'COLUMN_NAME' tipo_regla, '(^|_)(NOMBRE|DENOMINACION)_(MUNICIPIO|PROVINCIA|PAIS|ARCHIVO|FICHERO|PRODUCTO|SERVICIO)($|_)' expresion, -260 puntuacion, 1 prioridad, 70 confianza_min, to_number(null) muestra_min, 'Descarta nombres no personales' descripcion from dual
        union all
        select 'IDENTIFICADOR_PERSONAL' identificador, 'COLUMN_NAME' tipo_regla, '(^|_)(NOMBRE_VIA|NOMBRE_VIA_R|NOMBRE_MUNICIPIO|NOMBRE_ARCHIVO|NOMBRE_DOCUMENTO)($|_)' expresion, -260 puntuacion, 1 prioridad, to_number(null) confianza_min, to_number(null) muestra_min, 'Nombre de vía/objeto/documento no es nombre de persona' descripcion from dual
        union all
        select 'IDENTIFICADOR_PERSONAL' identificador, 'COLUMN_NAME' tipo_regla, '(^|_)(SOLICITANTE|INTERESAD[OA]|BENEFICIARI[OA]|DECLARANTE|REPRESENTANTE)($|_)' expresion, 88 puntuacion, 8 prioridad, to_number(null) confianza_min, to_number(null) muestra_min, 'Roles de persona con alta probabilidad de dato personal' descripcion from dual
        union all
        select 'IDENTIFICADOR_PERSONAL' identificador, 'COLUMN_NAME' tipo_regla, '(^|_)(APENOM|APENOMBRE|APELLIDOS_Y_NOMBRE|APE_NOM|RAZON_SOCIAL|DENOMINACION_SOCIAL)($|_)' expresion, 90 puntuacion, 8 prioridad, to_number(null) confianza_min, to_number(null) muestra_min, 'Apellidos y nombre / razón social en un solo campo' descripcion from dual
        union all
        select 'IDENTIFICADOR_PERSONAL' identificador, 'COLUMN_NAME' tipo_regla, '(^|_)(NOMBRE_USUARIO|APE1_USUARIO|APE2_USUARIO|NIF_USUARIO|US_NOMBRE|US_APELLIDO)($|_)' expresion, 95 puntuacion, 8 prioridad, to_number(null) confianza_min, to_number(null) muestra_min, 'Campos usuario/persona frecuentes' descripcion from dual
        union all
        select 'IDENTIFICADOR_PERSONAL' identificador, 'COLUMN_NAME' tipo_regla, '(^|_)(APELLIDO_PRIMERO|APELLIDO_SEGUNDO|PRIMER_APELLIDO|SEGUNDO_APELLIDO)($|_)' expresion, 95 puntuacion, 8 prioridad, to_number(null) confianza_min, to_number(null) muestra_min, 'Variantes explícitas de apellido personal' descripcion from dual
        union all
        select 'IDENTIFICADOR_PERSONAL' identificador, 'COLUMN_NAME' tipo_regla, '(^|_)(TITULAR|NOMBRE_TITULAR|TITULAR_NOMBRE|TITULAR_APELLIDOS?)($|_)' expresion, 85 puntuacion, 9 prioridad, 55 confianza_min, 10 muestra_min, 'Titular/nombre titular con alta probabilidad de dato personal' descripcion from dual
        union all
        select 'IDENTIFICADOR_PERSONAL' identificador, 'COLUMN_NAME' tipo_regla, '(^|_)(NOMBRE|APE1|APE2|APELLIDO1|APELLIDO2|APELLIDOS)($|_)' expresion, 90 puntuacion, 10 prioridad, 60 confianza_min, to_number(null) muestra_min, 'Nombre/apellidos persona' descripcion from dual
        union all
        select 'IDENTIFICADOR_PERSONAL' identificador, 'COLUMN_NAME' tipo_regla, '(^|_)(NOMBRE_COMPLETO|APELLIDOS_NOMBRE|APELLIDOS_Y_NOMBRE|NOMBRE_Y_APELLIDOS|APENOM|APENOMBRE|FULL_NAME|FULLNAME)($|_)' expresion, 140 puntuacion, 9 prioridad, to_number(null) confianza_min, to_number(null) muestra_min, 'Nombre completo: ya incluye apellidos, compensa NOMBRE_SIN_APELLIDOS_TABLA' descripcion from dual
        union all
        select 'IDENTIFICADOR_PERSONAL' identificador, 'COLUMN_NAME' tipo_regla, '(^|_)(FIRST_NAME|FIRSTNAME|GIVEN_NAME|MIDDLE_NAME|LAST_NAME|LASTNAME|SURNAME|FAMILY_NAME|FORENAME)($|_)' expresion, 90 puntuacion, 10 prioridad, 60 confianza_min, to_number(null) muestra_min, 'Nombre/apellidos persona (ingles)' descripcion from dual
        union all
        select 'IDENTIFICADOR_PERSONAL' identificador, 'COLUMN_NAME' tipo_regla, '(^|_)(SURNAME|LASTNAME|LAST_NAME|FAMILY_NAME|FIRST_NAME|FIRSTNAME|GIVEN_NAME|MIDDLE_NAME|FORENAME)[0-9]{1,2}($|_)' expresion, 90 puntuacion, 10 prioridad, 60 confianza_min, to_number(null) muestra_min, 'Nombre/apellidos persona (ingles) con sufijo numerico: SURNAME2, LASTNAME2' descripcion from dual
        union all
        select 'IDENTIFICADOR_PERSONAL' identificador, 'COLUMN_NAME' tipo_regla, '^NAME$' expresion, 75 puntuacion, 11 prioridad, to_number(null) confianza_min, to_number(null) muestra_min, 'NAME a secas: ambiguo, 22 exige evidencia en datos (apellido en tabla y ratio semantico)' descripcion from dual
        union all
        select 'IDENTIFICADOR_PERSONAL' identificador, 'COLUMN_COMMENT' tipo_regla, '(^|[^[:alpha:]])(APELLIDOS?|SURNAME|LAST[[:space:]_]NAME|FAMILY[[:space:]_]NAME)([^[:alpha:]]|$)' expresion, 40 puntuacion, 12 prioridad, to_number(null) confianza_min, to_number(null) muestra_min, 'Comentario que menciona apellido/surname: evidencia de apoyo' descripcion from dual
        union all
        select 'IDENTIFICADOR_PERSONAL' identificador, 'DATA_PATTERN' tipo_regla, '(\.pdf$|\.xml$|\.docx?$|\.xlsx?$|\.zip$|\.csv$|\.json$)' expresion, -220 puntuacion, 1 prioridad, to_number(null) confianza_min, 10 muestra_min, 'Nombre de archivo/documento, no personal' descripcion from dual
       ) v
 where not exists (select 1 from tdm_regla r
                    where r.identificador = v.identificador
                      and r.tipo_regla    = v.tipo_regla
                      and r.expresion     = v.expresion);

--------------------------------------------------------------------------------
-- A) TELEFONO
--------------------------------------------------------------------------------
insert into tdm_regla (regla_id, identificador, tipo_regla, expresion, puntuacion, prioridad, confianza_min, muestra_min, descripcion)
select seq_dm_regla.nextval, v.identificador, v.tipo_regla, v.expresion, v.puntuacion, v.prioridad, v.confianza_min, v.muestra_min, v.descripcion
  from (
        select 'IDENTIFICADOR_TELEFONO' identificador, 'COLUMN_NAME' tipo_regla, '(^|_)(TIPO|COD|ID|FLAG|CHECK|SW|IND|VALIDO)_(TEL|TELEFONO|TFNO|MOVIL)($|_)|(^|_)(TEL|TELEFONO|TFNO|MOVIL)_(TIPO|COD|ID|FLAG|CHECK|SW|IND|VALIDO)($|_)' expresion, -300 puntuacion, 1 prioridad, to_number(null) confianza_min, to_number(null) muestra_min, 'Descarte de metadatos o flags de teléfono' descripcion from dual
        union all
        select 'IDENTIFICADOR_TELEFONO' identificador, 'COLUMN_NAME' tipo_regla, '(^|_)(TYPE|CODE|ID|FLAG|CHECK|IND|VALID|IS|HAS)_(PHONE|TELEPHONE|MOBILE|CELL|CELLPHONE)($|_)|(^|_)(PHONE|TELEPHONE|MOBILE|CELL|CELLPHONE)_(TYPE|CODE|ID|FLAG|CHECK|IND|VALID)($|_)' expresion, -300 puntuacion, 1 prioridad, to_number(null) confianza_min, to_number(null) muestra_min, 'Descarte de metadatos o flags de telefono (ingles)' descripcion from dual
        union all
        select 'IDENTIFICADOR_TELEFONO' identificador, 'COLUMN_NAME' tipo_regla, '(^|_)(TEL|TELEFONO|TFNO|MOVIL|CELULAR)([0-9]{1,2})($|_)' expresion, 78 puntuacion, 9 prioridad, to_number(null) confianza_min, to_number(null) muestra_min, 'Teléfono con sufijo numérico (ej. TELEFONO1/TELEFONO2)' descripcion from dual
        union all
        select 'IDENTIFICADOR_TELEFONO' identificador, 'COLUMN_NAME' tipo_regla, '(^|_)(TEL|TELEFONO|TFNO|MOVIL|CELULAR)($|_)' expresion, 75 puntuacion, 10 prioridad, to_number(null) confianza_min, to_number(null) muestra_min, 'Teléfono' descripcion from dual
        union all
        select 'IDENTIFICADOR_TELEFONO' identificador, 'COLUMN_NAME' tipo_regla, '(^|_)(PHONE|TELEPHONE|MOBILE|CELL|CELLPHONE)([0-9]{1,2})($|_)' expresion, 78 puntuacion, 9 prioridad, to_number(null) confianza_min, to_number(null) muestra_min, 'Phone con sufijo numerico (ej. PHONE1/PHONE2)' descripcion from dual
        union all
        select 'IDENTIFICADOR_TELEFONO' identificador, 'COLUMN_NAME' tipo_regla, '(^|_)(PHONE|TELEPHONE|MOBILE|CELL|CELLPHONE)($|_)' expresion, 75 puntuacion, 10 prioridad, to_number(null) confianza_min, to_number(null) muestra_min, 'Telefono (ingles)' descripcion from dual
        union all
        select 'IDENTIFICADOR_TELEFONO' identificador, 'DATA_PATTERN' tipo_regla, '^(\+34)?[ -]?[6789][0-9]{8}$' expresion, 50 puntuacion, 20 prioridad, 1 confianza_min, 10 muestra_min, 'Teléfono ES' descripcion from dual
        union all
        select 'IDENTIFICADOR_TELEFONO' identificador, 'DATA_PATTERN' tipo_regla, '^(\+?34)?[ .-]?[6789]([ .-]?[0-9]){8}$' expresion, 42 puntuacion, 21 prioridad, 1 confianza_min, 10 muestra_min, 'Teléfono ES con espacios/puntos/guiones' descripcion from dual
       ) v
 where not exists (select 1 from tdm_regla r
                    where r.identificador = v.identificador
                      and r.tipo_regla    = v.tipo_regla
                      and r.expresion     = v.expresion);

--------------------------------------------------------------------------------
-- A) CONFIGURACION (sin puntuacion: puntuacion 0, no suman ni restan score)
--    Antes eran listas escritas dentro de pkg_dm_desc_puntuacion y proc_dm_procesa_desc.
--    El contenido es el mismo; ahora se cambia con una fila, sin recompilar.
--    Los tipos CTX_* son expresiones regulares sensibles a mayusculas aplicadas al
--    nombre de columna del diccionario; los demas son alternativas separadas por |.
--------------------------------------------------------------------------------
insert into tdm_regla (regla_id, identificador, tipo_regla, expresion, puntuacion, prioridad, confianza_min, muestra_min, descripcion)
select seq_dm_regla.nextval, v.identificador, v.tipo_regla, v.expresion, v.puntuacion, v.prioridad, v.confianza_min, v.muestra_min, v.descripcion
  from (
        select 'IDENTIFICADOR_PERSONAL' identificador, 'NUMBER_ADMITIDO' tipo_regla, 'CUENTA|IBAN|CCC|SWIFT|NIF|NIE|DNI|DOC|DOCUMENTO|TELEFONO|TFNO|MOVIL|TEL|CP|CODIGO_POSTAL' expresion, 0 puntuacion, 1 prioridad, to_number(null) confianza_min, to_number(null) muestra_min, 'Nombres (por palabra) de columna NUMBER que SI se evaluan: documento, cuenta, telefono, codigo postal (espanol)' descripcion from dual
        union all
        select 'IDENTIFICADOR_PERSONAL' identificador, 'NUMBER_ADMITIDO' tipo_regla, 'PHONE|TELEPHONE|MOBILE|CELL|CELLPHONE|IDNUMBER|ID_NUMBER' expresion, 0 puntuacion, 2 prioridad, to_number(null) confianza_min, to_number(null) muestra_min, 'Nombres (por palabra) de columna NUMBER que SI se evaluan: equivalentes en ingles' descripcion from dual
        union all
        select 'IDENTIFICADOR_PERSONAL' identificador, 'NUMBER_ADMITIDO' tipo_regla, 'CELULAR' expresion, 0 puntuacion, 3 prioridad, to_number(null) confianza_min, to_number(null) muestra_min, 'Nombres (por palabra) de columna NUMBER que SI se evaluan: celular' descripcion from dual
        union all
        select 'IDENTIFICADOR_PERSONAL' identificador, 'NOMBRE_CANDIDATO' tipo_regla, 'NOMBRE|NOMBRE_ALT|NOMBRE_USUARIO|US_NOMBRE|NOM|APELLIDOS_NOMBRE|NOMBRE_COMPLETO' expresion, 0 puntuacion, 1 prioridad, to_number(null) confianza_min, to_number(null) muestra_min, 'Palabras que hacen a una columna candidata a nombre de persona (compuertas de nombre; se suman los ALIAS_NOMBRE)' descripcion from dual
        union all
        select 'IDENTIFICADOR_PERSONAL' identificador, 'NOMBRE_PERSONAL' tipo_regla, 'NOMBRE|APE1|APE2|APELLIDO|APELLIDOS|APELLIDO1|APELLIDO2|AP1|AP2|APENU|TITULAR|SOLICITANTE|INTERESAD|BENEFICIARI|DECLARANTE|REPRESENTANTE|NOMBRE_COMPLETO|APELLIDOS_NOMBRE' expresion, 0 puntuacion, 1 prioridad, to_number(null) confianza_min, to_number(null) muestra_min, 'Palabras que permiten a una columna ser IDENTIFICADOR_PERSONAL (se suman los ALIAS_NOMBRE)' descripcion from dual
        union all
        select 'IDENTIFICADOR_PERSONAL' identificador, 'NOMBRE_GENERICO' tipo_regla, 'NAME' expresion, 0 puntuacion, 1 prioridad, to_number(null) confianza_min, to_number(null) muestra_min, 'Columna de nombre ambigua cuya decision depende del contexto de la tabla' descripcion from dual
        union all
        select 'IDENTIFICADOR_PERSONAL' identificador, 'CTX_PERSONA' tipo_regla, '^(APE1|APE2|APELLIDO|APELLIDO1|APELLIDO2|APELLIDOS|NIF|NIE|DNI|DOCUMENTO|NDOCUMENTO|EMAIL|MAIL|TFNO|TELEFONO|TELEF|MOVIL|DOMICILIO|SURNAME|SURNAME2|LASTNAME|LASTNAME2|LAST_NAME|FAMILYNAME|FAMILY_NAME|IDNUMBER|ID_NUMBER|PHONE|TELEPHONE|MOBILE|CELLPHONE|ADDRESS|ADDRESS1|ADDRESS2)$' expresion, 0 puntuacion, 1 prioridad, to_number(null) confianza_min, to_number(null) muestra_min, 'Contexto de persona en la tabla: nombre de columna exacto (sensible a mayusculas)' descripcion from dual
        union all
        select 'IDENTIFICADOR_PERSONAL' identificador, 'CTX_PERSONA' tipo_regla, '_(SURNAME|LASTNAME|PHONE|MOBILE|APE1|APE2|APELLIDO|APELLIDO1|APELLIDO2|APELLIDOS|NIF|NIE|DNI|DOCUMENTO|NDOCUMENTO|EMAIL|MAIL|TFNO|TELEF|MOVIL|DOMICILIO)$' expresion, 0 puntuacion, 2 prioridad, to_number(null) confianza_min, to_number(null) muestra_min, 'Contexto de persona en la tabla: columna que termina en _PALABRA' descripcion from dual
        union all
        select 'IDENTIFICADOR_PERSONAL' identificador, 'CTX_PERSONA' tipo_regla, '^(APE1|APE2|APELLIDO|APELLIDO1|APELLIDO2|APELLIDOS|NIF|NIE|DNI|DOCUMENTO|NDOCUMENTO|EMAIL|MAIL|TFNO|TELEF|MOVIL|DOMICILIO)_' expresion, 0 puntuacion, 3 prioridad, to_number(null) confianza_min, to_number(null) muestra_min, 'Contexto de persona en la tabla: columna que empieza por PALABRA_' descripcion from dual
        union all
        select 'IDENTIFICADOR_PERSONAL' identificador, 'CTX_APELLIDO' tipo_regla, '^(APE1|APE2|APELLIDO1|APELLIDO2|APELLIDOS|SURNAME|SURNAME2|LASTNAME|LASTNAME2|LAST_NAME|FAMILYNAME|FAMILY_NAME)$' expresion, 0 puntuacion, 1 prioridad, to_number(null) confianza_min, to_number(null) muestra_min, 'Apellidos en la tabla: nombre de columna exacto (sensible a mayusculas)' descripcion from dual
        union all
        select 'IDENTIFICADOR_PERSONAL' identificador, 'CTX_APELLIDO' tipo_regla, '_(SURNAME|LASTNAME|APE1|APE2|APELLIDO1|APELLIDO2|APELLIDOS)$' expresion, 0 puntuacion, 2 prioridad, to_number(null) confianza_min, to_number(null) muestra_min, 'Apellidos en la tabla: columna que termina en _PALABRA' descripcion from dual
        union all
        select 'IDENTIFICADOR_PERSONAL' identificador, 'CTX_APELLIDO' tipo_regla, '^(APE1|APE2|APELLIDO1|APELLIDO2|APELLIDOS)_' expresion, 0 puntuacion, 3 prioridad, to_number(null) confianza_min, to_number(null) muestra_min, 'Apellidos en la tabla: columna que empieza por PALABRA_' descripcion from dual
       ) v
 where not exists (select 1 from tdm_regla r
                    where r.identificador = v.identificador
                      and r.tipo_regla    = v.tipo_regla
                      and r.expresion     = v.expresion);

-- ##############################  BLOQUE B: NEGOCIO ACTUAL (DGA)  ##############################

--------------------------------------------------------------------------------
-- B) BANCARIO (IBAN/CCC)
--------------------------------------------------------------------------------
insert into tdm_regla (regla_id, identificador, tipo_regla, expresion, puntuacion, prioridad, confianza_min, muestra_min, descripcion)
select seq_dm_regla.nextval, v.identificador, v.tipo_regla, v.expresion, v.puntuacion, v.prioridad, v.confianza_min, v.muestra_min, v.descripcion
  from (
        select 'IDENTIFICADOR_BANCARIO' identificador, 'COLUMN_NAME' tipo_regla, '(^|_)(NOMBRE|APELLIDO1|APELLIDO2)(ELIMINAR|MANTENER)($|_)' expresion, -320 puntuacion, 1 prioridad, to_number(null) confianza_min, to_number(null) muestra_min, 'No es bancario: nombres/apellidos en procesos de unificacion' descripcion from dual
        union all
        select 'IDENTIFICADOR_BANCARIO' identificador, 'COLUMN_NAME' tipo_regla, '(^|_)(CUENTA_NEW|IBAN_NEW)($|_)' expresion, 95 puntuacion, 8 prioridad, to_number(null) confianza_min, to_number(null) muestra_min, 'Variantes bancarias reales' descripcion from dual
       ) v
 where not exists (select 1 from tdm_regla r
                    where r.identificador = v.identificador
                      and r.tipo_regla    = v.tipo_regla
                      and r.expresion     = v.expresion);

--------------------------------------------------------------------------------
-- B) DIRECCION
--------------------------------------------------------------------------------
insert into tdm_regla (regla_id, identificador, tipo_regla, expresion, puntuacion, prioridad, confianza_min, muestra_min, descripcion)
select seq_dm_regla.nextval, v.identificador, v.tipo_regla, v.expresion, v.puntuacion, v.prioridad, v.confianza_min, v.muestra_min, v.descripcion
  from (
        select 'IDENTIFICADOR_DIRECCION' identificador, 'COLUMN_NAME' tipo_regla, '(^|_)(DEN_DOMICILIO|DOMICILIO|NOMBRE_VIA_R)($|_)' expresion, 120 puntuacion, 7 prioridad, to_number(null) confianza_min, to_number(null) muestra_min, 'Dirección explícita en dominios ICSS/PCSS' descripcion from dual
        union all
        select 'IDENTIFICADOR_DIRECCION' identificador, 'COLUMN_NAME' tipo_regla, '(^|_)(DOMISO|VIASO)($|_)' expresion, 82 puntuacion, 8 prioridad, to_number(null) confianza_min, to_number(null) muestra_min, 'Alias funcionales de domicilio y vía' descripcion from dual
        union all
        select 'IDENTIFICADOR_DIRECCION' identificador, 'COLUMN_NAME' tipo_regla, '(^|_)(DOMICILIOSOCIAL(_APA[12])?|NOMBREVIA|RESTDIR)($|_)' expresion, 88 puntuacion, 8 prioridad, to_number(null) confianza_min, to_number(null) muestra_min, 'Campos de direccion frecuentes del negocio' descripcion from dual
       ) v
 where not exists (select 1 from tdm_regla r
                    where r.identificador = v.identificador
                      and r.tipo_regla    = v.tipo_regla
                      and r.expresion     = v.expresion);

--------------------------------------------------------------------------------
-- B) EMAIL
--------------------------------------------------------------------------------
insert into tdm_regla (regla_id, identificador, tipo_regla, expresion, puntuacion, prioridad, confianza_min, muestra_min, descripcion)
select seq_dm_regla.nextval, v.identificador, v.tipo_regla, v.expresion, v.puntuacion, v.prioridad, v.confianza_min, v.muestra_min, v.descripcion
  from (
        select 'IDENTIFICADOR_EMAIL' identificador, 'COLUMN_NAME' tipo_regla, '(^|_)(DEN_EMAIL|MAIL)($|_)' expresion, 90 puntuacion, 8 prioridad, to_number(null) confianza_min, to_number(null) muestra_min, 'Correos con variantes de nombre' descripcion from dual
       ) v
 where not exists (select 1 from tdm_regla r
                    where r.identificador = v.identificador
                      and r.tipo_regla    = v.tipo_regla
                      and r.expresion     = v.expresion);

--------------------------------------------------------------------------------
-- B) IDENTIDAD (NIF/NIE/DNI/CIF)
--------------------------------------------------------------------------------
insert into tdm_regla (regla_id, identificador, tipo_regla, expresion, puntuacion, prioridad, confianza_min, muestra_min, descripcion)
select seq_dm_regla.nextval, v.identificador, v.tipo_regla, v.expresion, v.puntuacion, v.prioridad, v.confianza_min, v.muestra_min, v.descripcion
  from (
        select 'IDENTIFICADOR_IDENTIDAD' identificador, 'COLUMN_NAME' tipo_regla, '(^|_)(NIFNIE|NIF_ACTUAL|NIF_ANTERIOR|NIF_INVOCA|CUENTA_TITU_NIF)($|_)' expresion, 115 puntuacion, 7 prioridad, to_number(null) confianza_min, to_number(null) muestra_min, 'Variantes NIF/NIE de negocio' descripcion from dual
        union all
        select 'IDENTIFICADOR_IDENTIDAD' identificador, 'COLUMN_NAME' tipo_regla, '(^|_)(DNISO|DNIPEN|DNIARR|DNIUEC[0-9]{0,2}|DNI_UEC[0-9]{0,2}|DNISO[0-9]{0,2}|ALQU_DNIPEN|ARR_DNIARR|P[0-9]{2}_IDENTIFICACION)($|_)' expresion, 100 puntuacion, 8 prioridad, to_number(null) confianza_min, to_number(null) muestra_min, 'Alias funcionales de identidad personal' descripcion from dual
        union all
        select 'IDENTIFICADOR_IDENTIDAD' identificador, 'COLUMN_NAME' tipo_regla, '(^|_)(DNISO|DNIPEN|DNIARR|DNIUEC|DNISO01|DNIUEC01|ALQU_DNIPEN|ARR_DNIARR)($|_)' expresion, 100 puntuacion, 8 prioridad, to_number(null) confianza_min, to_number(null) muestra_min, 'Alias funcionales de DNI en modelos de negocio' descripcion from dual
       ) v
 where not exists (select 1 from tdm_regla r
                    where r.identificador = v.identificador
                      and r.tipo_regla    = v.tipo_regla
                      and r.expresion     = v.expresion);

--------------------------------------------------------------------------------
-- B) PERSONAL (nombres y apellidos)
--------------------------------------------------------------------------------
insert into tdm_regla (regla_id, identificador, tipo_regla, expresion, puntuacion, prioridad, confianza_min, muestra_min, descripcion)
select seq_dm_regla.nextval, v.identificador, v.tipo_regla, v.expresion, v.puntuacion, v.prioridad, v.confianza_min, v.muestra_min, v.descripcion
  from (
        select 'IDENTIFICADOR_PERSONAL' identificador, 'COLUMN_NAME' tipo_regla, '(^|_)(NOMBRE|APELLIDO1|APELLIDO2)(ELIMINAR|MANTENER)($|_)' expresion, 105 puntuacion, 6 prioridad, to_number(null) confianza_min, to_number(null) muestra_min, 'Campos de nombre/apellidos en procesos de unificacion' descripcion from dual
        union all
        select 'IDENTIFICADOR_PERSONAL' identificador, 'COLUMN_NAME' tipo_regla, '(^|_)(ARR_NOMARR|COP_NOMSOL|ALQU_NOMUEC|NOMSO)($|_)' expresion, 110 puntuacion, 7 prioridad, to_number(null) confianza_min, to_number(null) muestra_min, 'Campos funcionales de nombre personal del modelo PNCSS' descripcion from dual
        union all
        select 'IDENTIFICADOR_PERSONAL' identificador, 'COLUMN_NAME' tipo_regla, '(^|_)(NOMSO|NOMSOL|NOMARR|NOMUEC|ACU_NOMBRE|USU_LT_USU|UNIFAM_APENU|APELLIDOS_NOMBRE|NOMBRE_COMPLETO)($|_)' expresion, 92 puntuacion, 8 prioridad, to_number(null) confianza_min, to_number(null) muestra_min, 'Alias funcionales de nombre personal' descripcion from dual
        union all
        select 'IDENTIFICADOR_PERSONAL' identificador, 'COLUMN_NAME' tipo_regla, '(^|_)(NOM|NOMSO|NOMSOL|NOMARR|NOMUEC|ACU_NOMBRE|USU_LT_USU|UNIFAM_APENU)($|_)' expresion, 92 puntuacion, 8 prioridad, to_number(null) confianza_min, to_number(null) muestra_min, 'Alias funcionales de nombre personal' descripcion from dual
        union all
        select 'IDENTIFICADOR_PERSONAL' identificador, 'ALIAS_NOMBRE' tipo_regla, 'NOMSO|NOMSOL|NOMARR|NOMUEC|ACU_NOMBRE|USU_LT_USU|UNIFAM_APENU' expresion, 0 puntuacion, 8 prioridad, to_number(null) confianza_min, to_number(null) muestra_min, 'Alias de columna de nombre del cliente DGA: activan las compuertas de nombre (no puntuan)' descripcion from dual
        union all
        select 'IDENTIFICADOR_PERSONAL' identificador, 'COLUMN_NAME' tipo_regla, '(^|_)(AP1SO|AP2SO|AP1SOL|AP2SOL|AP1ARR|AP2ARR|APENU[0-9]{1,2}|COP_APENU[0-9]{1,2})($|_)' expresion, 95 puntuacion, 8 prioridad, to_number(null) confianza_min, to_number(null) muestra_min, 'Alias funcionales de apellido personal' descripcion from dual
        union all
        select 'IDENTIFICADOR_PERSONAL' identificador, 'COLUMN_NAME' tipo_regla, '(^|_)(AP1SO|AP2SO|AP1SOL|AP2SOL|AP1ARR|AP2ARR|APENU1|APENU2|APENU01|APENU02)($|_)' expresion, 95 puntuacion, 8 prioridad, to_number(null) confianza_min, to_number(null) muestra_min, 'Alias funcionales de apellido personal' descripcion from dual
        union all
        select 'IDENTIFICADOR_PERSONAL' identificador, 'COLUMN_NAME' tipo_regla, '(^|_)(ALUMNO|ALUMNA|ESTUDIANTE|DISCENTE|DOCENTE)($|_)' expresion, 82 puntuacion, 9 prioridad, to_number(null) confianza_min, to_number(null) muestra_min, 'Roles personales del dominio educacion' descripcion from dual
        union all
        select 'IDENTIFICADOR_PERSONAL' identificador, 'TABLE_NAME' tipo_regla, '(^|_)(ICSS|PCSS|IMVSS)_(DATOS|EXP|SOL|USUARIOS|PERSONA|TITULAR)' expresion, 40 puntuacion, 20 prioridad, to_number(null) confianza_min, to_number(null) muestra_min, 'Contexto funcional alto de datos personales' descripcion from dual
       ) v
 where not exists (select 1 from tdm_regla r
                    where r.identificador = v.identificador
                      and r.tipo_regla    = v.tipo_regla
                      and r.expresion     = v.expresion);

--------------------------------------------------------------------------------
-- B) TELEFONO
--------------------------------------------------------------------------------
insert into tdm_regla (regla_id, identificador, tipo_regla, expresion, puntuacion, prioridad, confianza_min, muestra_min, descripcion)
select seq_dm_regla.nextval, v.identificador, v.tipo_regla, v.expresion, v.puntuacion, v.prioridad, v.confianza_min, v.muestra_min, v.descripcion
  from (
        select 'IDENTIFICADOR_TELEFONO' identificador, 'COLUMN_NAME' tipo_regla, '(^|_)(DEN_TFNO|DEN_TFNO_MOVIL|DEN_TELEF1|DEN_TELEF2|TFNO_MOVIL|TELEF1|TELEF2)($|_)' expresion, 95 puntuacion, 8 prioridad, to_number(null) confianza_min, to_number(null) muestra_min, 'Teléfonos con prefijo DEN_ y variantes' descripcion from dual
       ) v
 where not exists (select 1 from tdm_regla r
                    where r.identificador = v.identificador
                      and r.tipo_regla    = v.tipo_regla
                      and r.expresion     = v.expresion);

commit;
