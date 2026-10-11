set define off

Rem ================================================================================
Rem pkg_dm_desc_puntuacion  --  20_dm_pkg_desc_puntuacion.sql
Rem ================================================================================
Rem Senales y puntuacion de sensibilidad de una columna (nombre, comentario, dato muestreado) y clasificacion.
Rem
Rem Modularizacion 2026-10-10 (R2-R9): rutinas MOVIDAS desde pkg_dm_enmascarar sin cambiar su
Rem logica. Lo unico distinto es el prefijo de paquete en las llamadas a rutinas que viven en
Rem otro paquete. Las firmas y los textos de traza/error no cambian.
Rem
Rem 10/10/26 (auditoria industrial): las listas de palabras de las compuertas de nombre (NOMBRE_CANDIDATO,
Rem NOMBRE_PERSONAL, NOMBRE_GENERICO) y las de contexto de persona y apellidos (CTX_PERSONA, CTX_APELLIDO)
Rem salen del codigo y se leen de TDM_REGLA con puntuacion 0 (sembradas en 03 con el mismo contenido).
Rem Nueva func_dm_lista_regla (cache por sesion). Sin cambio de decision en las columnas ya descubiertas.
Rem ================================================================================

create or replace PACKAGE pkg_dm_desc_puntuacion AS

function func_dm_es_nombre_candidato(p_columna in varchar2) return number;

function func_dm_es_nombre_generico(p_columna in varchar2) return number;

function func_dm_lista_regla(p_tipo in varchar2) return varchar2;

function func_dm_es_dni_nie_valido(p_valor varchar2)
return number;

function func_dm_normaliza_sample(p_sample_rows in number) return number;

function func_dm_score_texto(
    p_identificador in varchar2,
    p_tipo_regla    in varchar2,
    p_texto         in varchar2
) return number;

function func_dm_identificador_base(
    p_columna    in varchar2,
    p_tabla      in varchar2,
    p_comentario in varchar2
) return varchar2;

function func_dm_tiene_evid_min(
    p_identificador in varchar2,
    p_score_nombre  in number,
    p_score_coment  in number,
    p_score_tabla   in number,
    p_score_patron  in number
) return number;

function func_dm_score_patron(
    p_ejecucion_id  in number,
    p_owner         in varchar2,
    p_tabla         in varchar2,
    p_columna       in varchar2,
    p_identificador in varchar2,
    p_sample_rows   in number,
    p_rows_out      out number,
    p_match_out     out number,
    p_ratio_out     out number,
    p_contra_out    out number
) return number;

function func_dm_null_ratio_muestra(
    p_owner       in varchar2,
    p_tabla       in varchar2,
    p_columna     in varchar2,
    p_sample_rows in number,
    p_rows_out    out number
) return number;

function func_dm_ratio_nombre_sem(
    p_owner      in varchar2,
    p_tabla      in varchar2,
    p_columna    in varchar2,
    p_sample_max in number,
    p_rows_out   out number,
    p_match_out  out number
) return number;

procedure proc_dm_clasifica(
    p_score      in number,
    p_estado_out out varchar2,
    p_mask_out   out char
);

function func_dm_get_col_comment(
    p_owner   in varchar2,
    p_tabla   in varchar2,
    p_columna in varchar2
) return varchar2;

function func_dm_tabla_tiene_filas(
    p_owner in varchar2,
    p_tabla in varchar2
) return number;

function func_dm_tiene_ctx_persona(
    p_owner in varchar2,
    p_tabla in varchar2
) return number;

function func_dm_tiene_apellidos(
    p_owner in varchar2,
    p_tabla in varchar2
) return number;

END pkg_dm_desc_puntuacion;
/

create or replace PACKAGE BODY pkg_dm_desc_puntuacion AS

-- 2026-10-10: los alias de negocio de nombre personal ya no viven en el codigo; se leen de TDM_REGLA
-- (identificador IDENTIFICADOR_PERSONAL, tipo_regla ALIAS_NOMBRE, bloque B de 03) y se cachean por sesion
-- (ver func_dm_alias_nombre_negocio). El conjunto cargado por 03 es identico al de la constante anterior.
g_alias_nombre_cache varchar2(1000);
g_alias_nombre_leido boolean := false;

-- 2026-10-10: listas de configuracion sin puntuacion (tipos NUMBER_ADMITIDO, NOMBRE_CANDIDATO,
-- NOMBRE_PERSONAL, NOMBRE_GENERICO) leidas de TDM_REGLA y cacheadas por sesion (ver func_dm_lista_regla).
type t_lista_cache is table of varchar2(2000) index by varchar2(20);
g_lista_cache t_lista_cache;

-- Cache de UNA entrada de la sondeo "la columna tiene algun dato" (ver func_dm_columna_con_datos).
-- Solo evita repetir el mismo sondeo para la misma columna entre los identificadores candidatos.
g_sondeo_clave varchar2(400);
g_sondeo_hay   number;


-- =========================================================
-- BLOQUE B: ALIAS DE NOMBRE PERSONAL PROPIOS DEL NEGOCIO ACTUAL (DGA)
-- =========================================================
-- FIX 2026-09-27 (revision de portabilidad): antes de este fix, estos mismos
-- 7 alias (NOMSO/NOMSOL/NOMARR/NOMUEC/ACU_NOMBRE/USU_LT_USU/UNIFAM_APENU --
-- las mismas convenciones de nombre de columna del esquema PNCSS que ya
-- estan cargadas como reglas de negocio en el BLOQUE B de
-- 03_dm_descubrimiento_carga_reglas.sql) estaban ADEMAS hardcodeados,
-- literalmente, en TRES sitios distintos de este paquete (dos de ellos
-- copias exactas entre si), mezclados con los alias genericos del motor.
--
-- Esta es la UNICA linea de este paquete que hay que revisar/sustituir por
-- los alias de nombre de la organizacion nueva al reinstalar en otro sitio
-- (ademas del Bloque B de 03, que es quien realmente puntua estos alias en
-- el scoring por nombre; esta constante solo alimenta las compuertas de
-- abajo, que deciden si a una columna candidata a IDENTIFICADOR_PERSONAL se
-- le aplica ademas la validacion de contexto/semantica de nombre). Si no
-- hay alias de negocio que anadir, dejar la constante vacia (''): el
-- comportamiento de las 3 compuertas pasa a depender solo de sus alias
-- genericos, sin tocar mas nada.
--

-- FIX 2026-09-27 (portabilidad + deduplicacion): esta misma expresion vivia
-- HARDCODEADA Y DUPLICADA dos veces dentro de proc_dm_procesa_desc (la
-- compuerta de penalizacion por falta de contexto y la compuerta de
-- degradacion a REVISAR) -- exactamente el patron que hace facil corregir
-- una copia y olvidar la otra. Se centraliza en una unica funcion; el
-- conjunto de alias que matchea es IDENTICO, caracter por caracter en su
-- union final, al de las dos expresiones que reemplaza.
------------------------------------------------------------------------------
-- [DOC] function func_dm_alias_nombre_negocio
-- PROPOSITO    : Devuelve la expresion con los alias de columna de nombre personal propios del negocio
--                (en DGA: NOMSO, NOMSOL, NOMARR, NOMUEC, ACU_NOMBRE, USU_LT_USU, UNIFAM_APENU), leidos de
--                TDM_REGLA y cacheados por sesion. Sin filas devuelve un token que ninguna columna real
--                tiene, y las compuertas usan solo los nombres genericos.
-- ENTRADAS     : ninguna. Retorna VARCHAR2 listo para insertar entre parentesis en una regexp.
-- LEE          : TDM_REGLA (identificador IDENTIFICADOR_PERSONAL, tipo_regla ALIAS_NOMBRE, activa Y)
-- ESCRIBE      : ninguno (cache de paquete g_alias_nombre_cache)
-- ERRORES      : ninguno propio
-- LLAMADO DESDE: func_dm_es_nombre_candidato; func_dm_score_patron
------------------------------------------------------------------------------
function func_dm_alias_nombre_negocio return varchar2 is
begin
  if not g_alias_nombre_leido then
    g_alias_nombre_cache := null;
    for r in (
      select expresion
        from tdm_regla
       where activa = 'Y'
         and identificador = 'IDENTIFICADOR_PERSONAL'
         and tipo_regla = 'ALIAS_NOMBRE'
       order by regla_id
    ) loop
      g_alias_nombre_cache := g_alias_nombre_cache
                              || case when g_alias_nombre_cache is not null then '|' end
                              || r.expresion;
    end loop;
    g_alias_nombre_cache := nvl(g_alias_nombre_cache, '__SIN_ALIAS_NEGOCIO__');
    g_alias_nombre_leido := true;
  end if;
  return g_alias_nombre_cache;
end func_dm_alias_nombre_negocio;

------------------------------------------------------------------------------
-- [DOC] function func_dm_lista_regla
-- PROPOSITO    : Devuelve, unidas con |, las expresiones activas de un tipo de regla de configuracion
--                (puntuacion 0) para usarlas como alternativas dentro de una expresion regular. Sustituye a
--                las listas de palabras que estaban escritas dentro del codigo. Se lee una vez por sesion.
-- ENTRADAS     : p_tipo (NUMBER_ADMITIDO, NOMBRE_CANDIDATO, NOMBRE_PERSONAL o NOMBRE_GENERICO).
--                Retorna '__SIN_REGLAS__' (sin cachear) si no hay ninguna fila activa: la expresion no
--                coincide con nada. Los cambios en TDM_REGLA se ven al abrir una sesion nueva.
-- LEE          : TDM_REGLA
-- ESCRIBE      : ninguno (cache de paquete g_lista_cache)
-- ERRORES      : ninguno propio
-- LLAMADO DESDE: func_dm_es_nombre_candidato, func_dm_es_nombre_generico, func_dm_score_patron;
--                proc_dm_procesa_tabla (22)
------------------------------------------------------------------------------
function func_dm_lista_regla(p_tipo in varchar2) return varchar2 is
  l_lista varchar2(2000);
begin
  if g_lista_cache.exists(p_tipo) then
    return g_lista_cache(p_tipo);
  end if;
  for r in (
    select expresion
      from tdm_regla
     where activa = 'Y'
       and tipo_regla = p_tipo
     order by regla_id
  ) loop
    l_lista := l_lista || case when l_lista is not null then '|' end || r.expresion;
  end loop;
  if l_lista is null then
    -- Sin filas activas: no se cachea, para que una siembra posterior de 03 se vea en la misma sesion.
    return '__SIN_REGLAS__';
  end if;
  g_lista_cache(p_tipo) := l_lista;
  return l_lista;
end func_dm_lista_regla;

------------------------------------------------------------------------------
-- [DOC] function func_dm_es_nombre_candidato
-- PROPOSITO    : Indica si un nombre de columna corresponde a un alias de nombre de persona (NOMBRE,
--                NOM, alias de negocio) para activar las compuertas de contexto personal.
-- ENTRADAS     : p_columna: nombre de columna. Retorna 1 si coincide con la regex de alias (incluye
--                la constante g_alias_nombre_negocio), 0 si no.
-- LEE          : ninguno
-- ESCRIBE      : ninguno
-- ERRORES      : ninguno
-- LLAMADO DESDE: proc_dm_procesa_desc (2 compuertas, lineas 2438 y 2488)
------------------------------------------------------------------------------
function func_dm_es_nombre_candidato(p_columna in varchar2) return number is
begin
  if regexp_like(p_columna,
       '(^|_)('||func_dm_lista_regla('NOMBRE_CANDIDATO')||'|'||func_dm_alias_nombre_negocio||')($|_)',
       'i')
  then
    return 1;
  end if;
  return 0;
end func_dm_es_nombre_candidato;

------------------------------------------------------------------------------
-- [DOC] function func_dm_es_nombre_generico
-- PROPOSITO    : Indica si la columna se llama NAME a secas (palabra de la regla NOMBRE_GENERICO). Es ambiguo (nombre de pila, nombre completo,
--                cargo, producto, descripcion), asi que su decision depende del contexto de la tabla.
-- ENTRADAS     : p_columna. Retorna 1 si el nombre es exactamente NAME, 0 si no.
-- LEE          : ninguno
-- ESCRIBE      : ninguno
-- ERRORES      : ninguno
-- LLAMADO DESDE: proc_dm_procesa_desc (compuerta NAME de 22_dm_pkg_descubrimiento.sql)
------------------------------------------------------------------------------
function func_dm_es_nombre_generico(p_columna in varchar2) return number is
begin
  if regexp_like(upper(trim(p_columna)), '^('||func_dm_lista_regla('NOMBRE_GENERICO')||')$') then
    return 1;
  end if;
  return 0;
end func_dm_es_nombre_generico;


-- =========================================================
-- VALIDACION REAL DNI/NIE
-- =========================================================
------------------------------------------------------------------------------
-- [DOC] function func_dm_es_dni_nie_valido
-- PROPOSITO    : Valida un DNI o NIE espanol comprobando formato y letra de control (modulo 23).
-- ENTRADAS     : p_valor: texto a validar. Retorna 1 si es DNI/NIE con letra correcta, 0 en caso
--                contrario.
-- LEE          : ninguno
-- ESCRIBE      : ninguno
-- ERRORES      : Cualquier excepcion interna se traduce en retorno 0 (sin ORA)
-- LLAMADO DESDE: func_dm_score_patron (muestreo de reglas DNI/NIE)
------------------------------------------------------------------------------
function func_dm_es_dni_nie_valido(p_valor varchar2)
return number
is
  v_valor varchar2(50);
  v_num   varchar2(20);
  v_letra char(1);
  v_calc  char(1);
  v_tabla constant varchar2(23) := 'TRWAGMYFPDXBNJZSQVHLCKE';
begin
  v_valor := upper(trim(p_valor));

  if v_valor is null then
    return 0;
  end if;

  if regexp_like(v_valor, '^[0-9]{8}[A-Z]$') then
    v_num   := substr(v_valor, 1, 8);
    v_letra := substr(v_valor, 9, 1);
    v_calc  := substr(v_tabla, mod(to_number(v_num), 23) + 1, 1);
    return case when v_letra = v_calc then 1 else 0 end;

  elsif regexp_like(v_valor, '^[XYZ][0-9]{7}[A-Z]$') then
    v_num :=
      case substr(v_valor, 1, 1)
        when 'X' then '0'
        when 'Y' then '1'
        when 'Z' then '2'
      end || substr(v_valor, 2, 7);

    v_letra := substr(v_valor, 9, 1);
    v_calc  := substr(v_tabla, mod(to_number(v_num), 23) + 1, 1);
    return case when v_letra = v_calc then 1 else 0 end;
  else
    return 0;
  end if;

exception
  when others then
    return 0;
end func_dm_es_dni_nie_valido;


------------------------------------------------------------------------------
-- Normaliza tamaño de muestra 10 - 500 filas
------------------------------------------------------------------------------
------------------------------------------------------------------------------
-- [DOC] function func_dm_normaliza_sample
-- PROPOSITO    : Acota el tamano de muestra por columna al rango 10 a 500 filas (500 si es nulo).
-- ENTRADAS     : p_sample_rows: filas solicitadas. Retorna numero normalizado entre 10 y 500.
-- LEE          : ninguno
-- ESCRIBE      : ninguno
-- ERRORES      : ninguno
-- LLAMADO DESDE: func_dm_score_patron; func_dm_ratio_nombre_sem; proc_dm_descubrimiento_core;
--                proc_dm_reanudar
------------------------------------------------------------------------------
function func_dm_normaliza_sample(p_sample_rows in number) return number is
begin
  if p_sample_rows is null then
    return 500;
  elsif p_sample_rows < 10 then
    return 10;
  elsif p_sample_rows > 500 then
    return 500;
  else
    return trunc(p_sample_rows);
  end if;
end func_dm_normaliza_sample;


------------------------------------------------------------------------------
-- SCORE por tipo de regla textual
------------------------------------------------------------------------------
------------------------------------------------------------------------------
-- [DOC] function func_dm_score_texto
-- PROPOSITO    : Suma la puntuacion de las reglas activas de TDM_REGLA de un identificador y tipo
--                (nombre, comentario o tabla) que coinciden con un texto.
-- ENTRADAS     : p_identificador, p_tipo_regla, p_texto. Retorna la suma de puntuaciones (puede ser
--                negativa).
-- LEE          : TDM_REGLA
-- ESCRIBE      : ninguno
-- ERRORES      : No captura errores: una expresion regular invalida en TDM_REGLA se propagaria al
--                llamador
-- LLAMADO DESDE: func_dm_identificador_base; proc_dm_procesa_desc
------------------------------------------------------------------------------
function func_dm_score_texto(
    p_identificador in varchar2,
    p_tipo_regla    in varchar2,
    p_texto         in varchar2
) return number is
  l_score number := 0;
begin
  for r in (
    select expresion, puntuacion
      from tdm_regla
     where activa = 'Y'
       and identificador = p_identificador
       and tipo_regla = p_tipo_regla
     order by prioridad
  ) loop
    if regexp_like(nvl(p_texto,' '), r.expresion, 'i') then
      l_score := l_score + r.puntuacion;
    end if;
  end loop;

  return l_score;
end func_dm_score_texto;


------------------------------------------------------------------------------
-- Identificador base por evidencia léxica
-- Nunca usa hardcode de dominios concretos; se apoya en tdm_regla.
------------------------------------------------------------------------------
------------------------------------------------------------------------------
-- [DOC] function func_dm_identificador_base
-- PROPOSITO    : Elige el identificador con mayor puntuacion lexica (columna, comentario, tabla) como
--                respaldo cuando ninguno tiene evidencia suficiente.
-- ENTRADAS     : p_columna, p_tabla, p_comentario. Retorna el identificador ganador o null si ninguna
--                puntuacion es positiva.
-- LEE          : TDM_REGLA
-- ESCRIBE      : ninguno
-- ERRORES      : ninguno
-- LLAMADO DESDE: proc_dm_procesa_desc
------------------------------------------------------------------------------
function func_dm_identificador_base(
    p_columna    in varchar2,
    p_tabla      in varchar2,
    p_comentario in varchar2
) return varchar2 is
  l_best_id    varchar2(50);
  l_best_score number := 0;
  l_score      number;
begin
  for r in (
    select distinct identificador
      from tdm_regla
     where activa = 'Y'
  ) loop
    l_score :=
        greatest(func_dm_score_texto(r.identificador, 'COLUMN_NAME',    p_columna), 0)
      + greatest(func_dm_score_texto(r.identificador, 'COLUMN_COMMENT', p_comentario), 0)
      + greatest(func_dm_score_texto(r.identificador, 'TABLE_NAME',     p_tabla), 0);

    if l_score > l_best_score then
      l_best_score := l_score;
      l_best_id := r.identificador;
    end if;
  end loop;

  if l_best_score > 0 then
    return l_best_id;
  end if;

  return null;
end func_dm_identificador_base;


------------------------------------------------------------------------------
-- Determina si la columna tiene evidencia mínima para persistirse en histórico
------------------------------------------------------------------------------
------------------------------------------------------------------------------
-- [DOC] function func_dm_tiene_evid_min
-- PROPOSITO    : Indica si un identificador tiene al menos una puntuacion positiva (nombre,
--                comentario, tabla o patron) que justifique registrarlo.
-- ENTRADAS     : p_identificador y los 4 scores. Retorna 1 si hay evidencia minima, 0 si no.
-- LEE          : ninguno
-- ESCRIBE      : ninguno
-- ERRORES      : ninguno
-- LLAMADO DESDE: proc_dm_procesa_desc
------------------------------------------------------------------------------
function func_dm_tiene_evid_min(
    p_identificador in varchar2,
    p_score_nombre  in number,
    p_score_coment  in number,
    p_score_tabla   in number,
    p_score_patron  in number
) return number is
begin
  if p_identificador is null then
    return 0;
  end if;

  if greatest(nvl(p_score_nombre,0), nvl(p_score_coment,0), nvl(p_score_tabla,0), nvl(p_score_patron,0)) > 0 then
    return 1;
  end if;

  return 0;
end func_dm_tiene_evid_min;


------------------------------------------------------------------------------
-- Score de patrón con ratio y muestra mínima
------------------------------------------------------------------------------
------------------------------------------------------------------------------
-- [DOC] function func_dm_columna_con_datos   (privada)
-- PROPOSITO    : Sondeo barato: 1 si la columna tiene al menos un valor no nulo, 0 si no, null si no se
--                pudo comprobar. Evita que una columna vacia (o casi) se recorra entera una vez por
--                cada regla DATA_PATTERN: sin ningun valor no nulo la consulta de muestreo no puede
--                juntar muestra y lee la tabla completa (GPT3_OWN.SHIFTASSIGNMENT.NAME: 23 lecturas
--                de 5,7 GB para una columna 100 % nula).
-- ENTRADAS     : p_owner, p_tabla, p_columna.
-- LEE          : Tabla de usuario (SELECT dinamico con DBMS_ASSERT.ENQUOTE_NAME, ROWNUM <= 1)
-- ERRORES      : No levanta; ante error retorna null (el llamador muestrea como antes).
-- LLAMADO DESDE: func_dm_score_patron
------------------------------------------------------------------------------
function func_dm_columna_con_datos(
    p_owner   in varchar2,
    p_tabla   in varchar2,
    p_columna in varchar2
) return number is
  l_clave varchar2(400) := p_owner||'.'||p_tabla||'.'||p_columna;
  l_n     number;
begin
  if g_sondeo_clave = l_clave then
    return g_sondeo_hay;
  end if;

  execute immediate
    'select count(*) from (select 1 from ' ||
    dbms_assert.enquote_name(p_owner, false) || '.' || dbms_assert.enquote_name(p_tabla, false) ||
    ' where ' || dbms_assert.enquote_name(p_columna, false) || ' is not null and rownum <= 1)'
    into l_n;

  g_sondeo_clave := l_clave;
  g_sondeo_hay   := case when l_n > 0 then 1 else 0 end;
  return g_sondeo_hay;
exception
  when others then
    return null;
end func_dm_columna_con_datos;


------------------------------------------------------------------------------
-- [DOC] function func_dm_score_patron
-- PROPOSITO    : Calcula la puntuacion por patron de datos de una columna ejecutando reglas
--                DATA_PATTERN sobre una muestra real de filas.
-- ENTRADAS     : p_ejecucion_id, p_owner, p_tabla, p_columna, p_identificador, p_sample_rows; OUT:
--                p_rows_out, p_match_out, p_ratio_out, p_contra_out (1 si el dato contradice los
--                formatos exigentes). Retorna el score acumulado.
-- LEE          : TDM_REGLA; Tabla de usuario muestreada (SELECT dinamico con
--                DBMS_ASSERT.ENQUOTE_NAME)
-- ESCRIBE      : Indirecto: TDM_EJECUCION_ERROR / TDM_MASK_TRACE via proc_dm_log_error
-- ERRORES      : No levanta ORA-2xxxx; ante cualquier error registra etapa
--                SCORE_PATRON:<identificador> y retorna 0 con OUT a cero; Retorna 0 sin muestrear si
--                el nombre de columna parece tecnico (ID/COD/TIPO...) salvo IDENTIDAD, o si
--                IDENTIFICADOR_PERSONAL no tiene nombre de persona o es de nomina
-- LLAMADO DESDE: proc_dm_procesa_desc (2 llamadas: lineas 2312 y 2399)
------------------------------------------------------------------------------
function func_dm_score_patron(
    p_ejecucion_id  in number,
    p_owner         in varchar2,
    p_tabla         in varchar2,
    p_columna       in varchar2,
    p_identificador in varchar2,
    p_sample_rows   in number,
    p_rows_out      out number,
    p_match_out     out number,
    p_ratio_out     out number,
    p_contra_out    out number
) return number is
  l_sql       varchar2(32767);
  l_rows      number := 0;
  l_matches   number := 0;
  l_ratio     number := 0;
  l_score     number := 0;
  l_rc        sys_refcursor;
  l_valor     varchar2(4000);
  l_es_regla_dni_nie number := 0;
  l_hay_     number := 0;
  l__rows    number := 0;
  l__match   number := 0;
  l_hay_dato number;      -- sondeo de datos de la columna (null = no comprobado)
begin
  p_rows_out   := 0;
  p_match_out  := 0;
  p_ratio_out  := 0;
  p_contra_out := 0;

  -- FIX 09/26/26: la compuerta por nombre (ID/COD/...) no se aplica a IDENTIDAD.
  -- Sus patrones de datos validan el digito de control (DNI/NIE), asi que un
  -- codigo que contiene documentos validos debe puntuar por sus datos.
  if p_identificador <> 'IDENTIFICADOR_IDENTIDAD'
     and (
       regexp_like(p_columna, '(^|_)(ID|COD|CODIGO|TIPO|FLAG|ESTADO|IND|SEQ|ORDEN|VERSION|HASH|TOKEN|UUID|PK|FK)($|_)', 'i')
       or regexp_like(p_columna, '^(ID|COD|CODIGO|TIPO|FLAG|ESTADO|IND|SEQ|ORDEN|VERSION|HASH|TOKEN|UUID|PK|FK)[A-Z0-9_]+$', 'i')
     )
     and not regexp_like(p_columna,
       '(^|_)(NIF|NIE|DNI|DOC|DOCUMENTO|NDOCUMENTO|NUM_DOCUMENTO|NRO_DOCUMENTO|IBAN|CUENTA|EMAIL|MAIL|TFNO|TELEF|MOVIL|DOMICILIO|DIRECCION|OBS|NOTA|DESCRIPCION|CONSULTA|RESPUESTA)($|_)', 'i')
  then
    return 0;
  end if;

-- FIX 2026-09-27 (portabilidad): los 7 alias de negocio (NOMSO/NOMSOL/...)
-- se movieron a TDM_REGLA tipo ALIAS_NOMBRE (ver func_dm_alias_nombre_negocio). El
-- conjunto final que matchea esta expresion es IDENTICO al de antes del
-- fix -- unicamente cambio DONDE vive el fragmento de negocio.
if p_identificador = 'IDENTIFICADOR_PERSONAL'
   and not regexp_like(p_columna,
     '(^|_)('||func_dm_lista_regla('NOMBRE_PERSONAL')||'|'||func_dm_alias_nombre_negocio||')($|_)',
     'i')
then
  -- REVERTIDO 2026-10-03 (vespertino): hasta el 02/10/26 este gate hacia
  -- simplemente "return 0" cuando el nombre de columna no matcheaba. Ese
  -- mismo dia se sustituyo por una llamada a func_dm_contenido_parece_persona
  -- ("el dato manda sobre el nombre") para intentar rescatar
  -- EXPEDIENTES.PROMOTOR -- se revierte por completo (ver changelog y el
  -- bloque de comentarios donde antes vivian esas 3 funciones, mas arriba en
  -- este archivo): el mecanismo nunca logro su objetivo (PROMOTOR sigue sin
  -- cruzar el umbral de mascara en ninguna variante medida) y si causo un
  -- falso positivo real sobre columnas de direccion/edificio a escala
  -- SRI2006. Vuelve a ser el gate simple por nombre de columna.
  return 0;
end if;

if p_identificador = 'IDENTIFICADOR_PERSONAL'
   and regexp_like(p_columna,
     '(^|_)(NOMINA|NOMINAS|NOMINA_PER|NOM_PER|NOM_PAGA|NOM_PAGALAM)($|_)',
     'i')
then
  return 0;
end if;

  for r in (
    select expresion,
           puntuacion,
           nvl(muestra_min, 10) muestra_min,
           nvl(confianza_min, 0) confianza_min,
           case when confianza_min is not null and puntuacion > 0 then 1 else 0 end es_
      from tdm_regla
     where activa = 'Y'
       and identificador = p_identificador
       and tipo_regla = 'DATA_PATTERN'
     order by prioridad
  ) loop
    l_rows    := 0;
    l_matches := 0;
    l_ratio   := 0;

    l_es_regla_dni_nie := 0;

    if p_identificador = 'IDENTIFICADOR_IDENTIDAD'
       and r.expresion in (
         '^[0-9]{8}[A-Z]$|^[XYZ][0-9]{7}[A-Z]$',
         '^[0-9]{7,8}[A-Z]$'
       )
    then
      l_es_regla_dni_nie := 1;
    end if;

    -- REVERTIDO 2026-10-03 (vespertino): aqui vivia la deteccion de la regla
    -- sentinela __CONTENIDO_NOMBRE_PERSONA__ (l_es_regla_nombre_persona) y su
    -- rama elsif de scoring completa -- eliminadas junto con las 3 funciones
    -- que las soportaban (ver changelog y bloque de comentarios mas arriba).

    -- FIX 2026-10-10: columna sin ningun valor no nulo -> ninguna regla puede muestrear filas. Se
    -- devuelve el mismo resultado que daria el muestreo (0 filas; coincidencias 0 en DNI/NIE y NULL
    -- en la consulta agregada) sin recorrer la tabla una vez por regla.
    if l_hay_dato is null then
      l_hay_dato := func_dm_columna_con_datos(p_owner, p_tabla, p_columna);
    end if;

    if l_hay_dato = 0 then
      l_rows    := 0;
      l_matches := case when l_es_regla_dni_nie = 1 then 0 else null end;
    elsif l_es_regla_dni_nie = 1 then
    -- FIX 2026-09-27 (incidente SRI2006): to_char(<columna>) sobre un valor real
    -- de mas de 4000 caracteres (CLOB o VARCHAR2 extendido, ej. campos de
    -- descripcion/config) lanza ORA-22835 (buffer demasiado pequeno). Se usa
    -- dbms_lob.substr(to_clob(<columna>),4000,1) en su lugar: to_clob() nunca
    -- desborda (el destino es CLOB, sin techo de 4000) y dbms_lob.substr extrae
    -- de forma segura los primeros 4000 caracteres para el muestreo -- mismo
    -- resultado que to_char() para cualquier valor que ya cabia en 4000.
      -- FIX 2026-10-09: 1000 caracteres (maximo 4000 bytes en UTF-8) en vez de 4000
      -- caracteres, que desbordaba el VARCHAR2 de SQL/l_valor (ORA-06502) con texto
      -- acentuado. Un documento DNI/NIE ocupa menos de 20 caracteres.
      l_sql := 'select dbms_lob.substr(to_clob(' || dbms_assert.enquote_name(p_columna, false) || '),1000,1) ' ||
               'from ' || dbms_assert.enquote_name(p_owner, false) || '.' || dbms_assert.enquote_name(p_tabla, false) ||
               ' where ' || dbms_assert.enquote_name(p_columna, false) || ' is not null and rownum <= :1';

      open l_rc for l_sql using p_sample_rows;
      loop
        fetch l_rc into l_valor;
        exit when l_rc%notfound;

        l_rows := l_rows + 1;
        if func_dm_es_dni_nie_valido(l_valor) = 1 then
          l_matches := l_matches + 1;
        end if;
      end loop;
      close l_rc;
    else
      -- FIX 2026-10-03 (hallazgo real del usuario sobre DATAM_ARCA_OWN.
      -- PRESTAMOS.EDIFICIO, datos reales "Paseo Maria Agustin, 36
      -- (Pignatelli)", "C/ Joaquin Costa, 18"): esta era la UNICA llamada a
      -- regexp_like en todo el paquete sin el match_option 'i' -- todas las
      -- demas (matching por COLUMN_NAME, mas arriba y en otras funciones) ya
      -- lo usan. La regla de contenido de IDENTIFICADOR_DIRECCION (y
      -- cualquier otra regla DATA_PATTERN generica que busque palabras
      -- literales en texto libre) comparaba contra tokens en MAYUSCULA
      -- ('PASEO','CALLE','AVDA',...) pero el dato real de produccion viene en
      -- Title Case/mixto -- "Paseo", no "PASEO". Confirmado reproduciendo el
      -- regex exacto en Python contra las 8 muestras reales que paso el
      -- usuario: sensible a mayusculas solo matchea 2/8 (25%, coherente con
      -- el ratio_match=0,112 real medido sobre 500 filas); insensible a
      -- mayusculas matchea 8/8 (100%). Cambio de alcance GENERAL (no solo
      -- DIRECCION): se aplica aqui porque es el UNICO punto del paquete que
      -- genera el SQL dinamico para TODAS las reglas DATA_PATTERN genericas
      -- de todos los identificadores -- consistente con el resto del
      -- paquete, monotono (solo puede sumar matches, nunca quitarlos) y sin
      -- riesgo conocido: ninguna regla DATA_PATTERN existente depende de que
      -- una letra especifica estuviera en mayuscula para distinguir un
      -- significado distinto (verificado una por una en
      -- 03_dm_descubrimiento_carga_reglas.sql).
      -- FIX 2026-10-09 (GCAA_OWN.LOG_SCAREG.MENSAJE, CLOB): dbms_lob.substr(..,4000,1)
      -- devuelve 4000 CARACTERES, pero en SQL el resultado es un VARCHAR2 de maximo
      -- 4000 BYTES; con texto con acentos (UTF-8) lo anterior lanza ORA-06502 y
      -- func_dm_score_patron devolvia 0 en silencio para TODOS los identificadores
      -- (la columna se descartaba sin evidencia de datos). regexp_like acepta CLOB
      -- directamente, asi que se evalua sobre to_clob(<columna>) completo: sin
      -- limite de bytes y sin perder cobertura (antes solo miraba los primeros 4000).
      l_sql := 'select count(*), sum(case when regexp_like(to_clob(' ||
               dbms_assert.enquote_name(p_columna, false) || '), :1, ''i'') then 1 else 0 end) ' ||
               'from (select ' || dbms_assert.enquote_name(p_columna, false) ||
               ' from ' || dbms_assert.enquote_name(p_owner, false) || '.' || dbms_assert.enquote_name(p_tabla, false) ||
               ' where ' || dbms_assert.enquote_name(p_columna, false) || ' is not null and rownum <= :2)';

      execute immediate l_sql into l_rows, l_matches using r.expresion, p_sample_rows;
    end if;

    -- FIX 09/26/26: regla de formato exigente (confianza_min informado y
    -- puntuacion > 0). Se acumula cuantas filas cumplen alguna de ellas.
    if r.es_ = 1 then
      l_hay_   := 1;
      l__rows  := greatest(l__rows, l_rows);
      l__match := greatest(l__match, nvl(l_matches,0));
    end if;

    if l_rows >= least(r.muestra_min, func_dm_normaliza_sample(p_sample_rows)) then
      l_ratio := nvl(l_matches,0) / l_rows;
      if (l_ratio * 100) >= r.confianza_min and l_ratio > 0 then
        l_score := l_score + (r.puntuacion * least(l_ratio,1));
      end if;
    end if;

    p_rows_out  := greatest(nvl(p_rows_out,0), l_rows);
    p_match_out := greatest(nvl(p_match_out,0), l_matches);
    p_ratio_out := greatest(nvl(p_ratio_out,0), l_ratio);
  end loop;

  -- Contradiccion de datos: con >= 10 filas de muestra, ninguna cumple ninguno de
  -- los formatos exigentes del identificador.
  if l_hay_ = 1 and l__rows >= 10 and l__match = 0 then
    p_contra_out := 1;
  end if;

  return l_score;

exception
  when others then
    if l_rc%isopen then
      close l_rc;
    end if;

    -- FIX 09/26/26: antes este handler devolvia 0 en silencio ante
    -- cualquier error (dynamic SQL, regexp_like invalido, etc.), sin dejar
    -- rastro. Ahora se registra en TDM_EJECUCION_ERROR para poder
    -- diagnosticar directamente en vez de tener que reconstruir el
    -- score a mano columna por columna.
    pkg_dm_trazabilidad.proc_dm_log_error(
      p_ejecucion_id, p_owner, p_tabla, p_columna,
      'SCORE_PATRON:' || p_identificador, sqlcode, sqlerrm
    );

    p_rows_out   := 0;
    p_match_out  := 0;
    p_ratio_out  := 0;
    p_contra_out := 0;
    return 0;
end func_dm_score_patron;


------------------------------------------------------------------------------
-- Ratio de nulos
------------------------------------------------------------------------------
------------------------------------------------------------------------------
-- [DOC] function func_dm_null_ratio_muestra
-- PROPOSITO    : Calcula la proporcion de nulos de una columna sobre una muestra de filas y el numero
--                de filas muestreadas.
-- ENTRADAS     : p_owner, p_tabla, p_columna, p_sample_rows; OUT p_rows_out. Retorna ratio 0..1 (1 si
--                no hay filas, null si falla).
-- LEE          : Tabla de usuario muestreada (SELECT dinamico)
-- ESCRIBE      : ninguno
-- ERRORES      : No levanta ORA-2xxxx; ante error retorna null y p_rows_out null sin registrar nada
-- LLAMADO DESDE: proc_dm_procesa_desc
------------------------------------------------------------------------------
function func_dm_null_ratio_muestra(
    p_owner       in varchar2,
    p_tabla       in varchar2,
    p_columna     in varchar2,
    p_sample_rows in number,
    p_rows_out    out number
) return number is
  l_sql   varchar2(32767);
  l_rows  number := 0;
  l_nulls number := 0;
begin
  l_sql := 'select count(*), sum(case when ' || dbms_assert.enquote_name(p_columna, false) ||
           ' is null then 1 else 0 end) from (select ' ||
           dbms_assert.enquote_name(p_columna, false) || ' from ' ||
           dbms_assert.enquote_name(p_owner, false) || '.' || dbms_assert.enquote_name(p_tabla, false) ||
           ' where rownum <= :1)';

  execute immediate l_sql into l_rows, l_nulls using p_sample_rows;
  p_rows_out := l_rows;

  if l_rows = 0 then
    return 1;
  end if;

  return nvl(l_nulls,0)/l_rows;
exception
  when others then
    p_rows_out := null;
    return null;
end func_dm_null_ratio_muestra;


------------------------------------------------------------------------------
-- Ratio semántico de nombre completo
------------------------------------------------------------------------------
------------------------------------------------------------------------------
-- [DOC] function func_dm_ratio_nombre_sem
-- PROPOSITO    : Mide que proporcion de la muestra parece nombre de persona (solo letras, sin digitos
--                ni palabras de via) para confirmar columnas de nombre sin apellidos en la tabla.
-- ENTRADAS     : p_owner, p_tabla, p_columna, p_sample_max; OUT p_rows_out, p_match_out. Retorna
--                ratio de coincidencias (0 si no hay filas, null si falla).
-- LEE          : Tabla de usuario muestreada (SELECT dinamico)
-- ESCRIBE      : ninguno
-- ERRORES      : No levanta ORA-2xxxx; ante error retorna null sin registrar nada
-- LLAMADO DESDE: proc_dm_procesa_desc
------------------------------------------------------------------------------
function func_dm_ratio_nombre_sem(
    p_owner      in varchar2,
    p_tabla      in varchar2,
    p_columna    in varchar2,
    p_sample_max in number,
    p_rows_out   out number,
    p_match_out  out number
) return number is
  l_sql    varchar2(32767);
  l_rows   number;
  l_match  number;
  l_sample number := func_dm_normaliza_sample(p_sample_max);
begin
l_sql :=
    'select count(*), ' ||
    'sum(case ' ||
    '      when (' ||
    '           regexp_like(trim('||dbms_assert.enquote_name(p_columna, false)||'),' ||
    q'[ '^[[:alpha:]ÁÉÍÓÚÜÑÇ][[:alpha:]ÁÉÍÓÚÜÑÇ''-]*([[:space:]]+[[:alpha:]ÁÉÍÓÚÜÑÇ][[:alpha:]ÁÉÍÓÚÜÑÇ''-]*){0,3}$' ]' ||
    ', ''i'') ' ||
    '           or regexp_like(trim('||dbms_assert.enquote_name(p_columna, false)||'),' ||
    q'[ '^[[:alpha:]ÁÉÍÓÚÜÑÇ][[:alpha:]ÁÉÍÓÚÜÑÇ''-]*([[:space:]]+[[:alpha:]ÁÉÍÓÚÜÑÇ][[:alpha:]ÁÉÍÓÚÜÑÇ''-]*)+, [[:space:]]*[[:alpha:]ÁÉÍÓÚÜÑÇ][[:alpha:]ÁÉÍÓÚÜÑÇ''-]*([[:space:]]+[[:alpha:]ÁÉÍÓÚÜÑÇ][[:alpha:]ÁÉÍÓÚÜÑÇ''-]*)*$' ]' ||
    ', ''i'') ' ||
    '          ) ' ||
    '       and not regexp_like('||dbms_assert.enquote_name(p_columna, false)||',''[0-9]'') ' ||
    '       and not regexp_like(upper('||dbms_assert.enquote_name(p_columna, false)||'), ' ||
    q'[ '(^|[[:space:]])(CALLE|C/|AVDA|AVENIDA|PASEO|PLAZA|RONDA|CAMINO|TRAVESIA|TRAVESÍA)([[:space:]]|$)' ]' ||
    ') ' ||
    '      then 1 else 0 end) ' ||
    'from (select '||dbms_assert.enquote_name(p_columna, false)||
    '        from '||dbms_assert.enquote_name(p_owner, false)||'.'||dbms_assert.enquote_name(p_tabla, false)||
    '       where '||dbms_assert.enquote_name(p_columna, false)||' is not null and rownum <= :x)';

  execute immediate l_sql into l_rows, l_match using l_sample;

  p_rows_out  := nvl(l_rows,0);
  p_match_out := nvl(l_match,0);

  if nvl(l_rows,0) = 0 then
    return 0;
  end if;

  return l_match / l_rows;
exception
  when others then
    p_rows_out  := null;
    p_match_out := null;
    return null;
end func_dm_ratio_nombre_sem;


------------------------------------------------------------------------------
-- Clasificación final
------------------------------------------------------------------------------
------------------------------------------------------------------------------
-- [DOC] procedure proc_dm_clasifica
-- PROPOSITO    : Traduce un score total a estado final y marca de enmascarado (>=85 CONFIRMADO/Y,
--                >=65 PROBABLE/Y, >=45
-- ENTRADAS     : p_score; OUT p_estado_out, p_mask_out.
-- LEE          : ninguno
-- ESCRIBE      : ninguno
-- ERRORES      : ninguno
-- LLAMADO DESDE: proc_dm_procesa_desc
------------------------------------------------------------------------------
procedure proc_dm_clasifica(
    p_score      in number,
    p_estado_out out varchar2,
    p_mask_out   out char
) is
begin
  if p_score >= 85 then
    p_estado_out := 'CONFIRMADO';
    p_mask_out   := 'Y';
  elsif p_score >= 65 then
    p_estado_out := 'PROBABLE';
    p_mask_out   := 'Y';
  elsif p_score >= 45 then
    p_estado_out := 'REVISAR';
    p_mask_out   := 'N';
  else
    p_estado_out := 'DESCARTADO';
    p_mask_out   := 'N';
  end if;
end proc_dm_clasifica;


------------------------------------------------------------------------------
-- Comentario de columna
------------------------------------------------------------------------------
------------------------------------------------------------------------------
-- [DOC] function func_dm_get_col_comment
-- PROPOSITO    : Obtiene el comentario de una columna del diccionario para usarlo como evidencia
--                lexica.
-- ENTRADAS     : p_owner, p_tabla, p_columna. Retorna el comentario o null si no existe.
-- LEE          : DBA_COL_COMMENTS
-- ESCRIBE      : ninguno
-- ERRORES      : ninguno
-- LLAMADO DESDE: proc_dm_procesa_desc
------------------------------------------------------------------------------
function func_dm_get_col_comment(
    p_owner   in varchar2,
    p_tabla   in varchar2,
    p_columna in varchar2
) return varchar2 is
  l_comment varchar2(4000);
begin
  select comments
    into l_comment
    from dba_col_comments
   where owner = p_owner
     and table_name = p_tabla
     and column_name = p_columna;

  return l_comment;
exception
  when no_data_found then
    return null;
end func_dm_get_col_comment;


------------------------------------------------------------------------------
-- Valida si la tabla tiene filas
------------------------------------------------------------------------------
------------------------------------------------------------------------------
-- [DOC] function func_dm_tabla_tiene_filas
-- PROPOSITO    : Comprueba si una tabla tiene al menos una fila para omitir las vacias del analisis.
-- ENTRADAS     : p_owner, p_tabla. Retorna 1 si hay filas (o si la consulta falla), 0 si esta vacia.
-- LEE          : Tabla de usuario (SELECT dinamico con rownum = 1)
-- ESCRIBE      : ninguno
-- ERRORES      : No levanta ORA-2xxxx; cualquier error distinto de no_data_found retorna 1 (se asume
--                que tiene filas)
-- LLAMADO DESDE: proc_dm_procesa_desc
------------------------------------------------------------------------------
function func_dm_tabla_tiene_filas(
    p_owner in varchar2,
    p_tabla in varchar2
) return number is
  l_sql   varchar2(32767);
  l_dummy number;
begin
  l_sql := 'select 1 from ' || dbms_assert.enquote_name(p_owner, false) || '.' || dbms_assert.enquote_name(p_tabla, false)
        || ' where rownum = 1';
  execute immediate l_sql into l_dummy;
  return 1;
exception
  when no_data_found then
    return 0;
  when others then
    return 1;
end func_dm_tabla_tiene_filas;


------------------------------------------------------------------------------
-- Señal de contexto persona
------------------------------------------------------------------------------
------------------------------------------------------------------------------
-- [DOC] function func_dm_tiene_ctx_persona
-- PROPOSITO    : Cuenta columnas de la tabla que indican contexto de persona (apellidos, documento,
--                email, telefono, domicilio).
-- ENTRADAS     : p_owner, p_tabla. Retorna numero de columnas con senal (0 si ninguna o si hay
--                error).
-- LEE          : DBA_TAB_COLUMNS, TDM_REGLA (tipos CTX_PERSONA / CTX_APELLIDO)
-- ESCRIBE      : ninguno
-- ERRORES      : No levanta ORA-2xxxx; ante error retorna 0
-- LLAMADO DESDE: proc_dm_procesa_desc
------------------------------------------------------------------------------
function func_dm_tiene_ctx_persona(
    p_owner in varchar2,
    p_tabla in varchar2
) return number is
  l_cnt number;
begin
  select count(*)
    into l_cnt
    from dba_tab_columns c
   where c.owner = p_owner
     and c.table_name = p_tabla
     and exists (select 1
                   from tdm_regla r
                  where r.activa = 'Y'
                    and r.tipo_regla = 'CTX_PERSONA'
                    and regexp_like(c.column_name, r.expresion, 'c'));

  return l_cnt;
exception
  when others then
    return 0;
end func_dm_tiene_ctx_persona;


------------------------------------------------------------------------------
-- Señal : apellidos
------------------------------------------------------------------------------
------------------------------------------------------------------------------
-- [DOC] function func_dm_tiene_apellidos
-- PROPOSITO    : Cuenta columnas de apellidos (APE1, APE2, APELLIDO1/2, APELLIDOS y variantes con
--                prefijo/sufijo) en la tabla.
-- ENTRADAS     : p_owner, p_tabla. Retorna numero de columnas de apellidos (0 si ninguna o si hay
--                error).
-- LEE          : DBA_TAB_COLUMNS, TDM_REGLA (tipos CTX_PERSONA / CTX_APELLIDO)
-- ESCRIBE      : ninguno
-- ERRORES      : No levanta ORA-2xxxx; ante error retorna 0
-- LLAMADO DESDE: proc_dm_procesa_desc
------------------------------------------------------------------------------
function func_dm_tiene_apellidos(
    p_owner in varchar2,
    p_tabla in varchar2
) return number is
  l_cnt number;
begin
  select count(*)
    into l_cnt
    from dba_tab_columns c
   where c.owner = p_owner
     and c.table_name = p_tabla
     and exists (select 1
                   from tdm_regla r
                  where r.activa = 'Y'
                    and r.tipo_regla = 'CTX_APELLIDO'
                    and regexp_like(c.column_name, r.expresion, 'c'));

  return l_cnt;
exception
  when others then
    return 0;
end func_dm_tiene_apellidos;

END pkg_dm_desc_puntuacion;
/
