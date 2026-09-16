Rem pkg_dm_descubrimiento.sql
Rem
Rem
Rem    NOMBRE
Rem      pkg_dm_descubrimiento.sql - Motor de Descubrimiento de Datos Sensibles
Rem
Rem    DESCRIPCIÓN
Rem      Este paquete implementa un motor de descubrimiento y clasificación
Rem      de datos sensibles en bases de datos Oracle.
Rem      Permite identificar información sensible mediante reglas semánticas,
Rem      validación de patrones, contexto de datos y análisis de contenido.
Rem      Uilizando un enfoque basado en puntuación (scoring), combinando:
Rem
Rem        - Reglas por nombre de columna (tdm_regla)
Rem        - Contexto de tabla
Rem        - Comentarios de columna
Rem        - Validación de patrones de datos
Rem        - Análisis semántico
Rem
Rem      El motor soporta:
Rem        - Clasificación determinista
Rem        - Reducción de falsos positivos
Rem        - Excepciones manuales (FORCE / EXCLUDE)
Rem        - Integración con procesos de enmascaramiento
Rem
Rem    NOTAS
Rem      - Diseñado para Oracle 11g en adelante
Rem      - Uso de SQL dinámico con muestreo
Rem      - Optimizado para esquemas grandes
Rem      - Soporte de validación de DNI/NIE
Rem
Rem    MODIFICADO   (MM/DD/YY)
Rem    epurisaca    07/15/25 - Versión inicial del motor de descubrimiento
Rem                           Basado en reglas simples por nombre de columna

Rem    epurisaca    08/10/25 - Se añade scoring por TABLE_NAME y COLUMN_COMMENT
Rem                           Introducción de modelo de puntuación ponderado

Rem    epurisaca    09/02/25 - Implementación de DATA_PATTERN con regexp_like
Rem                           Introducción de muestreo de datos (rownum)

Rem    epurisaca    09/18/25 - Integración de validación real de DNI/NIE
Rem                           Mejora en detección de identificadores personales

Rem    epurisaca    10/05/25 - Creación de tdm_regla como motor dinámico
Rem                           Permite modificar reglas sin cambiar código

Rem    epurisaca    10/22/25 - Introducción de prioridades y umbrales de confianza
Rem                           Mejora en normalización de scoring

Rem    epurisaca    11/12/25 - Se añade validación semántica de nombres humanos
Rem                           Reducción de falsos positivos en texto genérico

Rem    epurisaca    12/03/25 - Introducción de contexto de tabla (PERSONA, TITULAR)
Rem                           Mejora en clasificación contextual

Rem    epurisaca    12/20/25 - Exclusión de columnas técnicas (ID, COD, FLAG, etc.)
Rem                           Mejora en limpieza de resultados

Rem    epurisaca    01/08/26 - Creación de tdm_excepcion_col
Rem                           Soporte para reglas manuales FORCE / EXCLUDE

Rem    epurisaca    01/25/26 - Alineación con enmascaramiento determinista
Rem                           Consistencia entre tablas relacionadas

Rem    epurisaca    02/05/26 - Optimización de rendimiento en muestreo
Rem                           Mejora en ejecución sobre grandes volúmenes

Rem    epurisaca    02/18/26 - Penalización por falta de contexto de persona
Rem                           Reducción de falsos positivos en direcciones y bancos

Rem    epurisaca    02/26/26 - Introducción de ratio semántico de nombres
Rem                           Validación de contenido tipo nombre humano

Rem    epurisaca    03/05/26 - Integración con flujo de enmascaramiento
Rem                           Similar a Oracle Cloud Control

Rem    epurisaca    03/10/26 - Ajustes en reglas de COLUMN_NAME
Rem                           Mejora en detección de nomenclaturas legacy

Rem    epurisaca    03/14/26 - Rediseño versión 7 del motor
Rem                           Refactorización del flujo de scoring

Rem    epurisaca    03/17/26 - Identificación de falsos positivos por uso de NOM
Rem                           Ejemplo: NOMINA, NOMINA_PER mal clasificados

Rem    epurisaca    03/18/26 - Refinamiento de reglas IDENTIFICADOR_PERSONAL
Rem                           - Eliminación de NOM como indicador fuerte
Rem                           - Inclusión de reglas negativas para NOMINA
Rem                           - Ajuste de compuerta en func_dm_score_patron

Rem    epurisaca    03/18/26 - Mejora en control de falsos positivos
Rem                           Balance entre reglas y lógica de negocio

Rem    epurisaca    03/21/26 - Control de ejecución maestra base
Rem                           Se bloquea nueva ejecución con FORZAR_FULL = 'N'
Rem                           si ya existe una ejecución previa base del esquema
Rem                           Para reejecución se requiere FORZAR_FULL = 'Y'

Rem    epurisaca    03/25/26 - Versión estable v7
Rem                           Motor alineado a producción con mayor precisión
Rem    epurisaca    04/20/26 - Ajuste de política operativa de dependencias
Rem                           Sync de tdm_dependencia_final alineado con PRE/POST
Rem                           Preserva estado real ENABLED/DISABLED en triggers y constraints
Rem                           FK/CONSTRAINT y TRIGGER normales con política automática
Rem                           Objetos Oracle Text DR$ se mantienen como revisión especial

/*
g_version constant varchar2(30) := 'v7.0.20260421';procedure version is
begin
  dbms_output.put_line('pkg_dm_descubrimiento - versión: ' || g_version);
end;
*/
-----------------------------------------------------------------------------------------
-- (13) PAQUETE DESCUBRIMIENTO
-- Rediseño de las reglas de descubrimiento
-- v7.0.2
----------------------------------------------------------------------------------------
create or replace package pkg_dm_descubrimiento as
  procedure p_dm_descubrimiento(
      p_esquema          in varchar2,
      p_sample_rows      in number default 500,
      p_forzar_full      in char default 'N'
  );

  procedure p_dm_descubrimiento(
      p_esquema          in varchar2,
      p_forzar_full      in char
  );

  procedure p_dm_reanudar(
      p_ejecucion_id     in number,
      p_sample_rows      in number default 500,
      p_commit_lote      in number default 100
  );

  procedure p_dm_cancelar(
      p_ejecucion_id in number
  );

  procedure proc_dm_propaga_dominios(
      p_esquema      in varchar2,
      p_solicitud_id in number default null,
      p_ejecucion_id in number default null
  );

end pkg_dm_descubrimiento;
/

--------------------------------------------------------------------------------
-- 14) PACKAGE BODY
--------------------------------------------------------------------------------
create or replace package body pkg_dm_descubrimiento as

-- =========================================================
-- VALIDACION REAL DNI/NIE
-- =========================================================
function fn_es_dni_nie_valido(p_valor varchar2)
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
end fn_es_dni_nie_valido;

------------------------------------------------------------------------------
-- LOG DE ERRORES (autonomous)
------------------------------------------------------------------------------
procedure proc_dm_log_error(
    p_ejecucion_id in number,
    p_owner        in varchar2,
    p_tabla        in varchar2,
    p_columna      in varchar2,
    p_etapa        in varchar2,
    p_code         in number,
    p_msg          in varchar2
) is
  pragma autonomous_transaction;
begin
  insert into tdm_ejecucion_error(
    error_id, ejecucion_id, owner_name, table_name, column_name,
    etapa, codigo_error, mensaje_error, backtrace
  ) values (
    seq_dm_ejecucion_err.nextval, p_ejecucion_id, p_owner, p_tabla, p_columna,
    p_etapa, p_code, substr(p_msg,1,3900), substr(dbms_utility.format_error_backtrace,1,3900)
  );

  commit;
end proc_dm_log_error;

------------------------------------------------------------------------------
-- Normaliza tamaño de muestra 10 - 500 filas
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
-- Captura datos de sesión
------------------------------------------------------------------------------
procedure proc_dm_refresca_sesion(
    p_ejecucion_id in number
) is
  l_sid    number;
  l_serial number;
  l_inst   number;
begin
  begin
    select s.sid, s.serial#, s.inst_id
      into l_sid, l_serial, l_inst
      from gv$session s
     where s.audsid = sys_context('USERENV','SESSIONID')
       and s.username = sys_context('USERENV','SESSION_USER')
       and rownum = 1;
  exception
    when others then
      l_sid := null;
      l_serial := null;
      l_inst := null;
  end;

  update tdm_ejecucion
     set sesion_audsid  = sys_context('USERENV','SESSIONID'),
         sesion_sid     = l_sid,
         sesion_serial  = l_serial,
         sesion_inst_id = l_inst,
         heartbeat_ts   = systimestamp
   where ejecucion_id = p_ejecucion_id;
end proc_dm_refresca_sesion;

------------------------------------------------------------------------------
-- Auto-cancelación de ejecuciones huérfanas
------------------------------------------------------------------------------
procedure proc_dm_autocancel_huerfanas(
    p_minutos_inactividad in number default 15,
    p_forzar_sin_vsession in char default 'N'
) is
  l_cnt number;
  l_limite interval day to second := numtodsinterval(greatest(nvl(p_minutos_inactividad,15),1), 'MINUTE');
begin
  for e in (
    select ejecucion_id, ejecutado_por, fecha_inicio, sesion_audsid, sesion_sid, sesion_serial, sesion_inst_id, heartbeat_ts
      from tdm_ejecucion
     where estado = 'EJECUTANDO'
  ) loop
    begin
      if e.sesion_inst_id is not null and e.sesion_sid is not null and e.sesion_serial is not null then
        select count(*)
          into l_cnt
          from gv$session s
         where s.inst_id = e.sesion_inst_id
           and s.sid = e.sesion_sid
           and s.serial# = e.sesion_serial
           and nvl(s.status,'ACTIVE') not in ('KILLED','SNIPED');
      elsif e.sesion_audsid is not null then
        select count(*)
          into l_cnt
          from gv$session s
         where s.audsid = e.sesion_audsid
           and nvl(s.status,'ACTIVE') not in ('KILLED','SNIPED');
      else
        select count(*)
          into l_cnt
          from gv$session s
         where s.username = e.ejecutado_por
           and nvl(s.status,'ACTIVE') not in ('KILLED','SNIPED');
      end if;

      if l_cnt = 0 then
        update tdm_ejecucion
           set estado = 'ABORTADA',
               fecha_fin = systimestamp,
               ultimo_paso = 'AUTO_ABORTADA_SESION_NO_VIVA'
         where ejecucion_id = e.ejecucion_id
           and estado = 'EJECUTANDO';
      elsif nvl(e.heartbeat_ts, e.fecha_inicio) < systimestamp - l_limite then
        update tdm_ejecucion
           set estado = 'ABORTADA',
               fecha_fin = systimestamp,
               ultimo_paso = 'AUTO_ABORTADA_HEARTBEAT_TIMEOUT'
         where ejecucion_id = e.ejecucion_id
           and estado = 'EJECUTANDO';
      end if;
    exception
      when others then
        if upper(nvl(p_forzar_sin_vsession,'N')) = 'Y' then
          update tdm_ejecucion
             set estado = 'ABORTADA',
                 fecha_fin = systimestamp,
                 ultimo_paso = 'AUTO_ABORTADA_HEARTBEAT_TIMEOUT'
           where ejecucion_id = e.ejecucion_id
             and estado = 'EJECUTANDO';
        end if;
    end;
  end loop;

  commit;
end proc_dm_autocancel_huerfanas;

------------------------------------------------------------------------------
-- Verifica si la sesión sigue viva
------------------------------------------------------------------------------
function func_dm_sesion_viva(
    p_ejecucion_id in number
) return number is
  l_cnt number := 0;
begin
  begin
    select count(*)
      into l_cnt
      from tdm_ejecucion e
      join gv$session s
        on (
             (e.sesion_inst_id is not null and e.sesion_sid is not null and e.sesion_serial is not null
              and s.inst_id = e.sesion_inst_id and s.sid = e.sesion_sid and s.serial# = e.sesion_serial)
             or
             (e.sesion_inst_id is null and e.sesion_sid is null and e.sesion_serial is null
              and e.sesion_audsid is not null and s.audsid = e.sesion_audsid)
           )
     where e.ejecucion_id = p_ejecucion_id
       and nvl(s.status,'ACTIVE') not in ('KILLED','SNIPED');
  exception
    when others then
      l_cnt := 0;
  end;

  return case when l_cnt > 0 then 1 else 0 end;
end func_dm_sesion_viva;

------------------------------------------------------------------------------
-- Evalúa conflictos EJECUTANDO por esquema/tabla
------------------------------------------------------------------------------
function func_dm_conflicto_running(
    p_esquema    in varchar2,
    p_tablas_csv in varchar2
) return number is
  l_conflicto number := 0;
begin
  proc_dm_autocancel_huerfanas(5, 'Y');

  for r in (
    select e.ejecucion_id
      from tdm_ejecucion e
     where e.esquema_objetivo = upper(p_esquema)
       and e.estado = 'EJECUTANDO'
  ) loop
    if p_tablas_csv is null then
      l_conflicto := 1;
    else
      select case
               when not exists (select 1 from tdm_ejecucion_scope s where s.ejecucion_id = r.ejecucion_id) then 1
               when exists (select 1 from tdm_ejecucion_scope s where s.ejecucion_id = r.ejecucion_id and s.table_name = '*') then 1
               when exists (
                    select 1
                      from tdm_ejecucion_scope s
                     where s.ejecucion_id = r.ejecucion_id
                       and s.owner_name = upper(p_esquema)
                       and s.table_name in (
                             select upper(trim(regexp_substr(p_tablas_csv, '[^,]+', 1, level)))
                               from dual
                             connect by regexp_substr(p_tablas_csv, '[^,]+', 1, level) is not null
                           )
               ) then 1
               else 0
             end
        into l_conflicto
        from dual;
    end if;

    if l_conflicto = 1 then
      return 1;
    end if;
  end loop;

  return 0;
end func_dm_conflicto_running;

------------------------------------------------------------------------------
-- Registra scope de ejecución
------------------------------------------------------------------------------
procedure proc_dm_registra_scope(
    p_ejecucion_id in number,
    p_esquema      in varchar2,
    p_tablas_csv   in varchar2
) is
begin
  proc_dm_autocancel_huerfanas(15, 'Y');

  if p_tablas_csv is null then
    insert into tdm_ejecucion_scope(scope_id, ejecucion_id, owner_name, table_name, column_name)
    values (seq_dm_ejecucion_scope.nextval, p_ejecucion_id, upper(p_esquema), '*', null);
  else
    for t in (
      select distinct upper(trim(regexp_substr(p_tablas_csv, '[^,]+', 1, level))) table_name
        from dual
      connect by regexp_substr(p_tablas_csv, '[^,]+', 1, level) is not null
    ) loop
      insert into tdm_ejecucion_scope(scope_id, ejecucion_id, owner_name, table_name, column_name)
      values (seq_dm_ejecucion_scope.nextval, p_ejecucion_id, upper(p_esquema), t.table_name, null);
    end loop;
  end if;
end proc_dm_registra_scope;

------------------------------------------------------------------------------
-- SCORE por tipo de regla textual
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
function func_dm_score_patron(
    p_owner         in varchar2,
    p_tabla         in varchar2,
    p_columna       in varchar2,
    p_identificador in varchar2,
    p_sample_rows   in number,
    p_rows_out      out number,
    p_match_out     out number,
    p_ratio_out     out number
) return number is
  l_sql       varchar2(32767);
  l_rows      number := 0;
  l_matches   number := 0;
  l_ratio     number := 0;
  l_score     number := 0;
  l_rc        sys_refcursor;
  l_valor     varchar2(4000);
  l_es_regla_dni_nie number := 0;
begin
  p_rows_out  := 0;
  p_match_out := 0;
  p_ratio_out := 0;

  if (
       regexp_like(p_columna, '(^|_)(ID|COD|CODIGO|TIPO|FLAG|ESTADO|IND|SEQ|ORDEN|VERSION|HASH|TOKEN|UUID|PK|FK)($|_)', 'i')
       or regexp_like(p_columna, '^(ID|COD|CODIGO|TIPO|FLAG|ESTADO|IND|SEQ|ORDEN|VERSION|HASH|TOKEN|UUID|PK|FK)[A-Z0-9_]+$', 'i')
     )
     and not regexp_like(p_columna,
       '(^|_)(NIF|NIE|DNI|DOC|DOCUMENTO|NDOCUMENTO|NUM_DOCUMENTO|NRO_DOCUMENTO|IBAN|CUENTA|EMAIL|MAIL|TFNO|TELEF|MOVIL|DOMICILIO|DIRECCION|OBS|NOTA|DESCRIPCION|CONSULTA|RESPUESTA)($|_)', 'i')
  then
    return 0;
  end if;

if p_identificador = 'IDENTIFICADOR_PERSONAL'
   and not regexp_like(p_columna,
     '(^|_)(NOMBRE|ACU_NOMBRE|USU_LT_USU|UNIFAM_APENU|APE1|APE2|APELLIDO|APELLIDOS|APELLIDO1|APELLIDO2|AP1|AP2|APENU|TITULAR|SOLICITANTE|INTERESAD|BENEFICIARI|DECLARANTE|REPRESENTANTE|NOMSO|NOMSOL|NOMARR|NOMUEC|NOMBRE_COMPLETO|APELLIDOS_NOMBRE)($|_)',
     'i')
then
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
           nvl(confianza_min, 0) confianza_min
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

    if l_es_regla_dni_nie = 1 then
      l_sql := 'select to_char(' || dbms_assert.enquote_name(p_columna, false) || ') ' ||
               'from ' || dbms_assert.enquote_name(p_owner, false) || '.' || dbms_assert.enquote_name(p_tabla, false) ||
               ' where ' || dbms_assert.enquote_name(p_columna, false) || ' is not null and rownum <= :1';

      open l_rc for l_sql using p_sample_rows;
      loop
        fetch l_rc into l_valor;
        exit when l_rc%notfound;

        l_rows := l_rows + 1;
        if fn_es_dni_nie_valido(l_valor) = 1 then
          l_matches := l_matches + 1;
        end if;
      end loop;
      close l_rc;
    else
      l_sql := 'select count(*), sum(case when regexp_like(to_char(' ||
               dbms_assert.enquote_name(p_columna, false) || '), :1) then 1 else 0 end) ' ||
               'from (select ' || dbms_assert.enquote_name(p_columna, false) ||
               ' from ' || dbms_assert.enquote_name(p_owner, false) || '.' || dbms_assert.enquote_name(p_tabla, false) ||
               ' where ' || dbms_assert.enquote_name(p_columna, false) || ' is not null and rownum <= :2)';

      execute immediate l_sql into l_rows, l_matches using r.expresion, p_sample_rows;
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

  return l_score;

exception
  when others then
    if l_rc%isopen then
      close l_rc;
    end if;

    p_rows_out  := 0;
    p_match_out := 0;
    p_ratio_out := 0;
    return 0;
end func_dm_score_patron;

------------------------------------------------------------------------------
-- Ratio de nulos
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
     and (
       c.column_name in ('APE1','APE2','APELLIDO','APELLIDO1','APELLIDO2','APELLIDOS',
                         'NIF','NIE','DNI','DOCUMENTO','NDOCUMENTO','EMAIL','MAIL',
                         'TFNO','TELEFONO','TELEF','MOVIL','DOMICILIO')
       or c.column_name like '%\_APE1' escape '\'
       or c.column_name like '%\_APE2' escape '\'
       or c.column_name like '%\_APELLIDO' escape '\'
       or c.column_name like '%\_APELLIDO1' escape '\'
       or c.column_name like '%\_APELLIDO2' escape '\'
       or c.column_name like '%\_APELLIDOS' escape '\'
       or c.column_name like '%\_NIF' escape '\'
       or c.column_name like '%\_NIE' escape '\'
       or c.column_name like '%\_DNI' escape '\'
       or c.column_name like '%\_DOCUMENTO' escape '\'
       or c.column_name like '%\_NDOCUMENTO' escape '\'
       or c.column_name like '%\_EMAIL' escape '\'
       or c.column_name like '%\_MAIL' escape '\'
       or c.column_name like '%\_TFNO' escape '\'
       or c.column_name like '%\_TELEF' escape '\'
       or c.column_name like '%\_MOVIL' escape '\'
       or c.column_name like '%\_DOMICILIO' escape '\'
       or c.column_name like 'APE1\_%' escape '\'
       or c.column_name like 'APE2\_%' escape '\'
       or c.column_name like 'APELLIDO\_%' escape '\'
       or c.column_name like 'APELLIDO1\_%' escape '\'
       or c.column_name like 'APELLIDO2\_%' escape '\'
       or c.column_name like 'APELLIDOS\_%' escape '\'
       or c.column_name like 'NIF\_%' escape '\'
       or c.column_name like 'NIE\_%' escape '\'
       or c.column_name like 'DNI\_%' escape '\'
       or c.column_name like 'DOCUMENTO\_%' escape '\'
       or c.column_name like 'NDOCUMENTO\_%' escape '\'
       or c.column_name like 'EMAIL\_%' escape '\'
       or c.column_name like 'MAIL\_%' escape '\'
       or c.column_name like 'TFNO\_%' escape '\'
       or c.column_name like 'TELEF\_%' escape '\'
       or c.column_name like 'MOVIL\_%' escape '\'
       or c.column_name like 'DOMICILIO\_%' escape '\'
     );

  return l_cnt;
exception
  when others then
    return 0;
end func_dm_tiene_ctx_persona;

------------------------------------------------------------------------------
-- Señal estricta: apellidos
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
     and (
       c.column_name in ('APE1','APE2','APELLIDO1','APELLIDO2','APELLIDOS')
       or c.column_name like '%\_APE1' escape '\'
       or c.column_name like '%\_APE2' escape '\'
       or c.column_name like '%\_APELLIDO1' escape '\'
       or c.column_name like '%\_APELLIDO2' escape '\'
       or c.column_name like '%\_APELLIDOS' escape '\'
       or c.column_name like 'APE1\_%' escape '\'
       or c.column_name like 'APE2\_%' escape '\'
       or c.column_name like 'APELLIDO1\_%' escape '\'
       or c.column_name like 'APELLIDO2\_%' escape '\'
       or c.column_name like 'APELLIDOS\_%' escape '\'
     );

  return l_cnt;
exception
  when others then
    return 0;
end func_dm_tiene_apellidos;

------------------------------------------------------------------------------
-- Recolecta dependencias
------------------------------------------------------------------------------
procedure proc_dm_recolecta_dep(
    p_ejecucion_id in number,
    p_owner        in varchar2,
    p_tabla        in varchar2,
    p_columna      in varchar2
) is
begin
  insert into tdm_dependencia_hist(
    dependencia_id, ejecucion_id, owner_name, table_name, column_name,
    tipo_dependencia, dependencia_owner, dependencia_objeto, detalle
  )
  select seq_dm_dependencia_hist.nextval, p_ejecucion_id, p_owner, p_tabla, p_columna,
         case when c.constraint_type = 'R' then 'FK' else 'CONSTRAINT' end,
         c.owner,
         c.constraint_name,
         'Constraint/FK sobre columna'
    from dba_cons_columns cc
    join dba_constraints c
      on c.owner = cc.owner
     and c.constraint_name = cc.constraint_name
   where cc.owner = p_owner
     and cc.table_name = p_tabla
     and cc.column_name = p_columna
     and c.constraint_type in ('P','R','U','C');

  insert into tdm_dependencia_hist(
    dependencia_id, ejecucion_id, owner_name, table_name, column_name,
    tipo_dependencia, dependencia_owner, dependencia_objeto, detalle
  )
  select seq_dm_dependencia_hist.nextval, p_ejecucion_id, p_owner, p_tabla, p_columna,
         'TRIGGER', t.owner, t.trigger_name,
         'Trigger asociado a la tabla'
    from dba_triggers t
   where t.table_owner = p_owner
     and t.table_name = p_tabla;

exception
  when others then
    proc_dm_log_error(p_ejecucion_id, p_owner, p_tabla, p_columna, 'DEPENDENCIAS', sqlcode, sqlerrm);
end proc_dm_recolecta_dep;

------------------------------------------------------------------------------
-- Excepción manual
------------------------------------------------------------------------------
procedure proc_dm_aplica_excepcion(
    p_owner         in varchar2,
    p_tabla         in varchar2,
    p_columna       in varchar2,
    p_identificador in out nocopy varchar2,
    p_score_total   in out nocopy number,
    p_forzar_mask   in out nocopy char
) is
  l_accion        tdm_excepcion_col.accion%type;
  l_ident_forzado tdm_excepcion_col.identificador_forz%type;
begin
  select accion, identificador_forz
    into l_accion, l_ident_forzado
    from tdm_excepcion_col
   where owner_name = p_owner
     and table_name = p_tabla
     and column_name = p_columna
     and activa = 'Y';

  if l_accion = 'EXCLUDE' then
    p_score_total := -999;
    p_forzar_mask := 'N';
  elsif l_accion = 'FORCE' then
    p_identificador := nvl(l_ident_forzado, p_identificador);
    p_score_total := greatest(p_score_total, 95);
    p_forzar_mask := 'Y';
  end if;
exception
  when no_data_found then
    null;
end proc_dm_aplica_excepcion;

------------------------------------------------------------------------------
-- Prepara objetos
------------------------------------------------------------------------------
procedure proc_dm_prepara_objetos(
    p_esquema      in varchar2,
    p_ejecucion_id in number,
    p_forzar_full  in char
) is
begin
  for t in (
    select o.owner, o.object_name table_name, o.object_id, o.last_ddl_time,
           (select count(*) from dba_tab_columns c where c.owner = o.owner and c.table_name = o.object_name) column_count
      from dba_objects o
      join dba_tables tb
        on tb.owner = o.owner
       and tb.table_name = o.object_name
     where o.owner = upper(p_esquema)
       and o.object_type = 'TABLE'
       and tb.temporary = 'N'
       and (
         not exists (
           select 1
             from tdm_ejecucion_scope sc
            where sc.ejecucion_id = p_ejecucion_id
              and sc.owner_name = upper(p_esquema)
         )
         or exists (
           select 1
             from tdm_ejecucion_scope sc
            where sc.ejecucion_id = p_ejecucion_id
              and sc.owner_name = upper(p_esquema)
              and sc.table_name in ('*', o.object_name)
         )
       )
  ) loop
    update tdm_objeto_ctrl dc
       set dc.object_id = t.object_id,
           dc.last_ddl_time = t.last_ddl_time,
           dc.column_count = t.column_count,
           dc.firma_txt = t.owner || '|' || t.table_name || '|' || t.last_ddl_time || '|' || t.column_count,
           dc.estado_objeto = case
                                when regexp_like(t.table_name, '(^|_)(TMP|TEMP|LOG|TRAZA|ERROR|PARAM|CAT|CATALOG|CONFIG|LOOKUP|LOV|BATCH|JOB|MVIEW|MV_)', 'i') then 'OMITIDO'
                                when p_forzar_full = 'Y' then 'PENDIENTE'
                                when dc.last_ddl_time != t.last_ddl_time or nvl(dc.column_count,-1) != nvl(t.column_count,-1) then 'PENDIENTE'
                                else dc.estado_objeto
                              end,
           dc.motivo_estado = case
                                when regexp_like(t.table_name, '(^|_)(TMP|TEMP|LOG|TRAZA|ERROR|PARAM|CAT|CATALOG|CONFIG|LOOKUP|LOV|BATCH|JOB|MVIEW|MV_)', 'i') then 'TABLA_TECNICA_SISTEMA'
                                else null
                              end
     where dc.owner_name = t.owner
       and dc.table_name = t.table_name;

    if sql%rowcount = 0 then
      insert into tdm_objeto_ctrl(
        owner_name, table_name, object_id, last_ddl_time, column_count,
        firma_txt, ultimo_run_id, estado_objeto, motivo_estado
      ) values (
        t.owner, t.table_name, t.object_id, t.last_ddl_time, t.column_count,
        t.owner || '|' || t.table_name || '|' || t.last_ddl_time || '|' || t.column_count,
        null,
        case when regexp_like(t.table_name, '(^|_)(TMP|TEMP|LOG|TRAZA|ERROR|PARAM|CAT|CATALOG|CONFIG|LOOKUP|LOV|BATCH|JOB|MVIEW|MV_)', 'i') then 'OMITIDO' else 'PENDIENTE' end,
        case when regexp_like(t.table_name, '(^|_)(TMP|TEMP|LOG|TRAZA|ERROR|PARAM|CAT|CATALOG|CONFIG|LOOKUP|LOV|BATCH|JOB|MVIEW|MV_)', 'i') then 'TABLA_TECNICA_SISTEMA' else null end
      );
    end if;
  end loop;

  update tdm_ejecucion e
     set tablas_total = (
           select count(*)
             from tdm_objeto_ctrl dc
            where dc.owner_name = upper(p_esquema)
              and dc.estado_objeto = 'PENDIENTE'
              and (
                not exists (select 1 from tdm_ejecucion_scope sc where sc.ejecucion_id = p_ejecucion_id and sc.owner_name = upper(p_esquema))
                or exists (select 1 from tdm_ejecucion_scope sc where sc.ejecucion_id = p_ejecucion_id and sc.owner_name = upper(p_esquema) and sc.table_name in ('*', dc.table_name))
              )
         ),
         columnas_total = (
           select nvl(sum(dc.column_count),0)
             from tdm_objeto_ctrl dc
            where dc.owner_name = upper(p_esquema)
              and dc.estado_objeto = 'PENDIENTE'
              and (
                not exists (select 1 from tdm_ejecucion_scope sc where sc.ejecucion_id = p_ejecucion_id and sc.owner_name = upper(p_esquema))
                or exists (select 1 from tdm_ejecucion_scope sc where sc.ejecucion_id = p_ejecucion_id and sc.owner_name = upper(p_esquema) and sc.table_name in ('*', dc.table_name))
              )
         ),
         ultimo_paso = 'OBJETOS_PREPARADOS'
   where e.ejecucion_id = p_ejecucion_id;

  commit;
end proc_dm_prepara_objetos;

------------------------------------------------------------------------------
-- Resolvedor de componentes conexos por FK (Union-Find)
-- Propaga enmascarar = 'Y', identificador y dominio compartido a todo el grupo conexo.
------------------------------------------------------------------------------
procedure proc_dm_propaga_dominios(
    p_esquema      in varchar2,
    p_solicitud_id in number default null,
    p_ejecucion_id in number default null
) is
  type t_node is record (
    parent_node   varchar2(500),
    identificador varchar2(50),
    enmascarar    char(1)
  );
  type t_node_map is table of t_node index by varchar2(500);
  l_nodes t_node_map;

  type t_component is record (
    has_enmascarar char(1) := 'N',
    identificador  varchar2(50) := null,
    min_node       varchar2(500) := null
  );
  type t_comp_map is table of t_component index by varchar2(500);
  l_comps t_comp_map;

  l_esquema varchar2(128) := upper(trim(p_esquema));
  l_key     varchar2(500);
  l_root    varchar2(500);
  l_own     varchar2(128);
  l_tab     varchar2(128);
  l_col     varchar2(128);
  l_first_dot  number;
  l_second_dot number;

  -- Union-Find Find
  function find_root(p_node in varchar2) return varchar2 is
    l_curr varchar2(500) := p_node;
  BEGIN
    if not l_nodes.exists(l_curr) then
      l_nodes(l_curr).parent_node := l_curr;
      l_nodes(l_curr).enmascarar  := 'N';
      l_nodes(l_curr).identificador := null;
      return l_curr;
    end if;

    while l_nodes(l_curr).parent_node <> l_curr loop
      l_curr := l_nodes(l_curr).parent_node;
    end loop;
    return l_curr;
  END;

  -- Union-Find Union
  procedure union_nodes(p_node1 in varchar2, p_node2 in varchar2) is
    l_r1 varchar2(500) := find_root(p_node1);
    l_r2 varchar2(500) := find_root(p_node2);
  BEGIN
    if l_r1 <> l_r2 then
      l_nodes(l_r1).parent_node := l_r2;
    end if;
  END;

  -- Ranking de prioridad de identificadores para dominios referenciales (menor ranking = mayor especificidad/prioridad)
  function f_rank_ident(p_ident in varchar2) return number is
  begin
    return case upper(trim(p_ident))
             when 'IDENTIFICADOR_IDENTIDAD'  then 10
             when 'IDENTIFICADOR_DOCUMENTO'  then 10
             when 'IDENTIFICADOR_IBAN'       then 20
             when 'IDENTIFICADOR_BANCARIO'   then 20
             when 'IDENTIFICADOR_PERSONAL'   then 50
             else 90
           end;
  end;

begin
  -- 1) Cargar nodos iniciales desde tdm_columna_final
  for rc in (
    select owner_name, table_name, column_name, identificador, enmascarar
      from tdm_columna_final
     where owner_name = l_esquema
  ) loop
    l_key := rc.owner_name||'.'||rc.table_name||'.'||rc.column_name;
    l_nodes(l_key).parent_node := l_key;
    l_nodes(l_key).identificador := rc.identificador;
    l_nodes(l_key).enmascarar := nvl(rc.enmascarar,'N');
  end loop;

  -- 2) Cargar relaciones FK y hacer UNION de nodos
  for fk in (
    select cc_c.owner  child_owner,  cc_c.table_name child_table,  cc_c.column_name child_col,
           cc_p.owner  parent_owner, cc_p.table_name parent_table, cc_p.column_name parent_col
      from dba_constraints  c
      join dba_cons_columns cc_c on cc_c.owner = c.owner    and cc_c.constraint_name   = c.constraint_name
      join dba_cons_columns cc_p on cc_p.owner = c.r_owner  and cc_p.constraint_name   = c.r_constraint_name
                                and cc_p.position = cc_c.position
     where c.constraint_type = 'R'
       and c.owner = l_esquema
  ) loop
    union_nodes(
      fk.child_owner||'.'||fk.child_table||'.'||fk.child_col,
      fk.parent_owner||'.'||fk.parent_table||'.'||fk.parent_col
    );
  end loop;

  -- 3) Agrupar y resolver propiedades del componente (has_enmascarar, identificador por ranking, nodo mínimo)
  l_key := l_nodes.first;
  while l_key is not null loop
    l_root := find_root(l_key);
    
    -- Inicializar l_comps(l_root) de forma segura para evitar ORA-01403
    if not l_comps.exists(l_root) then
      l_comps(l_root).has_enmascarar := 'N';
      l_comps(l_root).identificador  := null;
      l_comps(l_root).min_node       := null;
    end if;

    if l_nodes(l_key).enmascarar = 'Y' then
      l_comps(l_root).has_enmascarar := 'Y';
    end if;

    if l_nodes(l_key).identificador is not null then
      if l_comps(l_root).identificador is null
         or f_rank_ident(l_nodes(l_key).identificador) < f_rank_ident(l_comps(l_root).identificador) then
        l_comps(l_root).identificador := l_nodes(l_key).identificador;
      end if;
    end if;

    -- M-1: Resolver nombre de dominio lexicográficamente menor de forma estable
    if l_comps(l_root).min_node is null or l_key < l_comps(l_root).min_node then
      l_comps(l_root).min_node := l_key;
    end if;

    l_key := l_nodes.next(l_key);
  end loop;

  -- 4) Propagar resultados y persistir dominio en tdm_columna_final (forzar homogeneidad determinista)
  l_key := l_nodes.first;
  while l_key is not null loop
    l_root := find_root(l_key);
    
    if l_comps.exists(l_root) and l_comps(l_root).has_enmascarar = 'Y' then
      l_first_dot  := instr(l_key, '.');
      l_second_dot := instr(l_key, '.', 1, 2);
      l_own := substr(l_key, 1, l_first_dot - 1);
      l_tab := substr(l_key, l_first_dot + 1, l_second_dot - l_first_dot - 1);
      l_col := substr(l_key, l_second_dot + 1);

      -- A.2: Traza dinámica de re-inclusión de columnas por integridad referencial
      declare
        l_curr_enm varchar2(1) := null;
      begin
        select enmascarar into l_curr_enm
          from tdm_columna_final
         where owner_name = l_own
           and table_name = l_tab
           and column_name = l_col;

        if l_curr_enm = 'N' then
          begin
            execute immediate
              'begin pkg_dm_enmascarar.proc_dm_trace(:1, :2, ''PROPAGACION'', ''RI_REINCLUYE'', :3); end;'
              using p_solicitud_id, p_ejecucion_id,
                    l_own||'.'||l_tab||'.'||l_col||' re-incluida (Y) por integridad referencial del dominio '||l_comps(l_root).min_node;
          exception
            when others then null;
          end;
        end if;
      exception
        when others then null;
      end;

      merge into tdm_columna_final u
      using (
        select l_own as owner_name,
               l_tab as table_name,
               l_col as column_name,
               l_comps(l_root).identificador as identificador,
               case when upper(trim(l_comps(l_root).identificador)) = 'IDENTIFICADOR_OBS' then null else l_comps(l_root).min_node end as dominio
          from dual
      ) h
      on (u.owner_name = h.owner_name and u.table_name = h.table_name and u.column_name = h.column_name)
      when matched then
        update set u.enmascarar = 'Y',
                   u.identificador = h.identificador, -- Forzar el identificador de mayor prioridad en todo el componente
                   u.dominio = h.dominio
      when not matched then
        insert (owner_name, table_name, column_name, identificador, enmascarar, dominio)
        values (h.owner_name, h.table_name, h.column_name, h.identificador, 'Y', h.dominio);
    end if;

    l_key := l_nodes.next(l_key);
  end loop;
end proc_dm_propaga_dominios;

------------------------------------------------------------------------------
-- Sync catálogo final
------------------------------------------------------------------------------
procedure proc_dm_sync_col_final(
    p_ejecucion_id in number
) is
begin
  merge into tdm_columna_final u
  using (
    select owner_name, table_name, column_name, identificador, enmascarar
      from tdm_columna_hist
     where ejecucion_id = p_ejecucion_id
       and enmascarar = 'Y'
  ) h
     on (u.owner_name = h.owner_name and u.table_name = h.table_name and u.column_name = h.column_name)
  when matched then
    update set u.identificador = h.identificador,
               u.enmascarar    = h.enmascarar
  when not matched then
    insert (owner_name, table_name, column_name, identificador, enmascarar)
    values (h.owner_name, h.table_name, h.column_name, h.identificador, h.enmascarar);

  delete from tdm_columna_final u
   where exists (
         select 1
           from tdm_columna_hist h
          where h.ejecucion_id = p_ejecucion_id
            and h.owner_name = u.owner_name
            and h.table_name = u.table_name
            and h.column_name = u.column_name
            and nvl(h.enmascarar,'N') <> 'Y'
   );

  -- Resolver componentes conexos por FK y propagar dominios lógicos
  declare
    l_esquema varchar2(128);
  begin
    select esquema_objetivo into l_esquema
      from tdm_ejecucion
     where ejecucion_id = p_ejecucion_id;
    proc_dm_propaga_dominios(l_esquema);
  exception
    when others then
      -- R3: No silenciar el fallo de propagación en la sincronización del catálogo
      begin
        execute immediate
          'begin pkg_dm_enmascarar.proc_dm_trace(-1, -1, ''DISCOVERY'', ''PROPAGA_DOMINIOS_ERR'', :1); end;'
          using 'Fallo propagando dominios FK para '||l_esquema||': '||sqlerrm;
      exception
        when others then
          null; -- Evitar fallas de referencia cruzada si pkg_dm_enmascarar no está compilado
      end;
  end;
end proc_dm_sync_col_final;

------------------------------------------------------------------------------
-- Sync dependencias final
------------------------------------------------------------------------------
procedure proc_dm_sync_dep_final(
    p_ejecucion_id in number
) is
begin
  merge into tdm_dependencia_final u
  using (
    with dep_base as (
      select owner_name,
             table_name,
             column_name,
             tipo_dependencia,
             nvl(dependencia_owner,'-') dependencia_owner,
             nvl(dependencia_objeto,'-') dependencia_objeto,
             max(detalle) detalle
        from tdm_dependencia_hist
       where ejecucion_id = p_ejecucion_id
         and tipo_dependencia in ('FK','CONSTRAINT','TRIGGER')
       group by owner_name, table_name, column_name, tipo_dependencia,
                nvl(dependencia_owner,'-'), nvl(dependencia_objeto,'-')
    )
    select b.owner_name,
           b.table_name,
           b.column_name,
           b.tipo_dependencia,
           b.dependencia_owner,
           b.dependencia_objeto,
           case
             when upper(trim(b.tipo_dependencia)) in ('FK','CONSTRAINT','R','FOREIGN KEY')
               then 'INTEGRIDAD'
             when upper(trim(b.tipo_dependencia)) in ('PK_REFERENCIADA','P','PRIMARY KEY','UK_REFERENCIADA','U','UNIQUE')
               then 'INTEGRIDAD'
             else 'OPERATIVA'
           end categoria_uso,
           case
             when upper(trim(b.tipo_dependencia)) in ('FK','CONSTRAINT','R','FOREIGN KEY')
               then case when nvl(c.status,'ENABLED') = 'ENABLED' then 'DISABLE' else 'SIN_ACCION' end
             when upper(trim(b.tipo_dependencia)) = 'TRIGGER'
               then case when nvl(t.status,'ENABLED') = 'ENABLED' then 'DISABLE' else 'SIN_ACCION' end
             when upper(trim(b.tipo_dependencia)) in ('PK_REFERENCIADA','P','PRIMARY KEY','UK_REFERENCIADA','U','UNIQUE')
               then 'SOLO_INFORMATIVO'
             else 'SOLO_INFORMATIVO'
           end accion_pre_mask,
           case
             when upper(trim(b.tipo_dependencia)) in ('FK','CONSTRAINT','R','FOREIGN KEY')
               then case when nvl(c.status,'ENABLED') = 'ENABLED' then 'ENABLE_NOVALIDATE' else 'SIN_ACCION' end
             when upper(trim(b.tipo_dependencia)) = 'TRIGGER'
               then case when nvl(t.status,'ENABLED') = 'ENABLED' then 'ENABLE' else 'SIN_ACCION' end
             when upper(trim(b.tipo_dependencia)) in ('PK_REFERENCIADA','P','PRIMARY KEY','UK_REFERENCIADA','U','UNIQUE')
               then 'REVISAR'
             else 'SIN_ACCION'
           end accion_post_mask,
           b.detalle
      from dep_base b
      left join dba_constraints c
        on upper(trim(b.tipo_dependencia)) in ('FK','CONSTRAINT','R','FOREIGN KEY')
       and c.owner = b.dependencia_owner
       and c.constraint_name = b.dependencia_objeto
      left join dba_triggers t
        on upper(trim(b.tipo_dependencia)) = 'TRIGGER'
       and t.owner = b.dependencia_owner
       and t.trigger_name = b.dependencia_objeto
  ) d
     on (u.owner_name = d.owner_name
         and u.table_name = d.table_name
         and u.column_name = d.column_name
         and u.tipo_dependencia = d.tipo_dependencia
         and nvl(u.dependencia_owner,'-') = d.dependencia_owner
         and nvl(u.dependencia_objeto,'-') = d.dependencia_objeto)
  when matched then
    update set u.categoria_uso    = d.categoria_uso,
               u.accion_pre_mask  = d.accion_pre_mask,
               u.accion_post_mask = d.accion_post_mask,
               u.detalle          = d.detalle
  when not matched then
    insert (
      owner_name, table_name, column_name, tipo_dependencia,
      dependencia_owner, dependencia_objeto,
      categoria_uso, accion_pre_mask, accion_post_mask, detalle
    )
    values (
      d.owner_name, d.table_name, d.column_name, d.tipo_dependencia,
      d.dependencia_owner, d.dependencia_objeto,
      d.categoria_uso, d.accion_pre_mask, d.accion_post_mask, d.detalle
    );
end proc_dm_sync_dep_final;

------------------------------------------------------------------------------
-- PROCESO CENTRAL
-- Ajuste importante:
-- 1) si no hay evidencia mínima, la columna NO se inserta en histórico
-- 2) si sí hay evidencia, el identificador nunca queda NULL
------------------------------------------------------------------------------
procedure proc_dm_procesa_desc(
    p_ejecucion_id in number,
    p_sample_rows  in number,
    p_commit_lote  in number
) is
  l_esquema           tdm_ejecucion.esquema_objetivo%type;
  l_estado            tdm_ejecucion.estado%type;
  l_cols_lote         number := 0;
  l_comment           varchar2(4000);
  l_best_id           varchar2(50);
  l_best_score        number;
  l_score_nombre      number;
  l_score_coment      number;
  l_score_patron      number;
  l_score_tabla       number;
  l_score_total       number;
  l_rows              number;
  l_matches           number;
  l_ratio             number;
  l_null_ratio        number;
  l_rows_total        number;
  l_sem_rows          number;
  l_sem_matches       number;
  l_ratio_semantica   number;
  l_motivo_descarte   varchar2(2000);
  l_estado_final      varchar2(20);
  l_enmascarar        char(1);
  l_force_mask        char(1);
  l_ctx_persona       number;
  l_ctx_persona_tab   number := 0;
  l_ctx_apellidos_tab number := 0;
  l_tiene_evidencia   number := 0;
begin
  select esquema_objetivo, estado
    into l_esquema, l_estado
    from tdm_ejecucion
   where ejecucion_id = p_ejecucion_id
   for update;

  if l_estado not in ('EJECUTANDO','PAUSADO') then
    raise_application_error(-20010, 'La ejecución no está disponible para procesar');
  end if;

  update tdm_ejecucion
     set estado = 'EJECUTANDO',
         fase_proceso = 'DESCUBRIMIENTO',
         ultimo_paso = 'PROCESANDO_TABLAS',
         heartbeat_ts = systimestamp
   where ejecucion_id = p_ejecucion_id;

  commit;

  for t in (
    select tctl.owner_name, tctl.table_name
      from tdm_objeto_ctrl tctl
     where tctl.owner_name = l_esquema
       and tctl.estado_objeto = 'PENDIENTE'
       and (
         not exists (select 1 from tdm_ejecucion_scope sc where sc.ejecucion_id = p_ejecucion_id and sc.owner_name = l_esquema)
         or exists (select 1 from tdm_ejecucion_scope sc where sc.ejecucion_id = p_ejecucion_id and sc.owner_name = l_esquema and sc.table_name in ('*', tctl.table_name))
       )
     order by tctl.table_name
  ) loop
    select estado into l_estado
      from tdm_ejecucion
     where ejecucion_id = p_ejecucion_id;

    if l_estado in ('CANCELADO','ABORTADA') then
      return;
    end if;

    if func_dm_tabla_tiene_filas(t.owner_name, t.table_name) = 0 then
      update tdm_objeto_ctrl
         set estado_objeto = 'OMITIDO',
             motivo_estado = 'TABLA_SIN_FILAS',
             fecha_ult_analisis = systimestamp,
             ultimo_run_id = p_ejecucion_id
       where owner_name = t.owner_name
         and table_name = t.table_name;

      update tdm_ejecucion
         set tablas_proc = nvl(tablas_proc,0) + 1,
             progreso_pct = case when nvl(tablas_total,0) > 0 then round((nvl(tablas_proc,0)+1)/tablas_total*100,2) else progreso_pct end,
             ultimo_objeto = t.owner_name || '.' || t.table_name,
             ultimo_paso = 'TABLA_OMITIDA_SIN_FILAS',
             heartbeat_ts = systimestamp
       where ejecucion_id = p_ejecucion_id;

      commit;
      continue;
    end if;

    delete from tdm_dependencia_hist
     where ejecucion_id = p_ejecucion_id
       and owner_name = t.owner_name
       and table_name = t.table_name;

    delete from tdm_columna_hist
     where ejecucion_id = p_ejecucion_id
       and owner_name = t.owner_name
       and table_name = t.table_name;

    update tdm_ejecucion
       set ultimo_objeto = t.owner_name || '.' || t.table_name,
           ultimo_paso = 'LECTURA_COLUMNAS'
     where ejecucion_id = p_ejecucion_id;

    l_ctx_persona_tab   := func_dm_tiene_ctx_persona(t.owner_name, t.table_name);
    l_ctx_apellidos_tab := func_dm_tiene_apellidos(t.owner_name, t.table_name);

    for c in (
      select c.owner, c.table_name, c.column_name, c.data_type,
             c.data_length, c.data_precision, c.data_scale
        from dba_tab_columns c
       where c.owner = t.owner_name
         and c.table_name = t.table_name
         and (
           c.data_type in ('CHAR','NCHAR','VARCHAR2','NVARCHAR2','CLOB')
           or (
             c.data_type = 'NUMBER'
             and regexp_like(c.column_name,
               '(^|_)(CUENTA|IBAN|CCC|SWIFT|NIF|NIE|DNI|DOC|DOCUMENTO|TELEFONO|TFNO|MOVIL|TEL|CP|CODIGO_POSTAL)($|_)', 'i')
           )
         )
       order by c.column_id
    ) loop
      begin
        l_best_id         := null;
        l_best_score      := -99999;
        l_comment         := func_dm_get_col_comment(c.owner, c.table_name, c.column_name);
        l_tiene_evidencia := 0;
        l_rows_total      := 0;
        l_matches         := 0;
        l_ratio           := 0;

        for idn in (
          select distinct identificador
            from tdm_regla
           where activa = 'Y'
        ) loop
          l_score_nombre := func_dm_score_texto(idn.identificador, 'COLUMN_NAME', c.column_name);
          l_score_coment := func_dm_score_texto(idn.identificador, 'COLUMN_COMMENT', l_comment);
          l_score_tabla  := func_dm_score_texto(idn.identificador, 'TABLE_NAME', c.table_name);

          if regexp_like(c.column_name, '^(ID|COD|CODIGO|TIPO|FLAG|ESTADO|IND|SEQ|ORDEN|VERSION|HASH|TOKEN|UUID)[A-Z0-9_]+$', 'i')
             and idn.identificador not in ('IDENTIFICADOR_IDENTIDAD','IDENTIFICADOR_BANCARIO') then
            l_score_patron := 0;
            l_rows := 0;
            l_matches := 0;
            l_ratio := 0;
          elsif (l_score_nombre + l_score_coment + l_score_tabla) >= -30 then
            l_score_patron := func_dm_score_patron(
                                c.owner,
                                c.table_name,
                                c.column_name,
                                idn.identificador,
                                p_sample_rows,
                                l_rows,
                                l_matches,
                                l_ratio
                              );
          else
            l_score_patron := 0;
            l_rows := 0;
            l_matches := 0;
            l_ratio := 0;
          end if;

          l_score_total := l_score_nombre + l_score_coment + l_score_tabla + l_score_patron;

          if func_dm_tiene_evid_min(
               idn.identificador,
               l_score_nombre,
               l_score_coment,
               l_score_tabla,
               l_score_patron
             ) = 1 then
            l_tiene_evidencia := 1;
          end if;

          if l_score_total > l_best_score then
            l_best_score := l_score_total;
            l_best_id    := idn.identificador;
          end if;
        end loop;

        if l_tiene_evidencia = 0 then
          l_best_id := func_dm_identificador_base(c.column_name, c.table_name, l_comment);
          if l_best_id is not null then
            l_tiene_evidencia := 1;
          end if;
        end if;

        if l_tiene_evidencia = 0 or l_best_id is null then
          continue;
        end if;

        l_score_nombre := func_dm_score_texto(l_best_id, 'COLUMN_NAME', c.column_name);
        l_score_coment := func_dm_score_texto(l_best_id, 'COLUMN_COMMENT', l_comment);
        l_score_tabla  := func_dm_score_texto(l_best_id, 'TABLE_NAME', c.table_name);
        l_score_patron := func_dm_score_patron(
                            c.owner,
                            c.table_name,
                            c.column_name,
                            l_best_id,
                            p_sample_rows,
                            l_rows,
                            l_matches,
                            l_ratio
                          );

        l_score_total    := l_score_nombre + l_score_coment + l_score_tabla + l_score_patron;
        l_force_mask     := 'N';
        l_motivo_descarte := null;
        l_sem_rows       := null;
        l_sem_matches    := null;
        l_ratio_semantica := null;
        l_null_ratio     := func_dm_null_ratio_muestra(c.owner, c.table_name, c.column_name, p_sample_rows, l_rows_total);

        proc_dm_aplica_excepcion(c.owner, c.table_name, c.column_name, l_best_id, l_score_total, l_force_mask);

        if l_best_id = 'IDENTIFICADOR_IDENTIDAD'
           and regexp_like(c.column_name, '(^|_)(TIPO|COD|CODIGO|CLASE|ENUM|FLAG|ESTADO)_?(NIF|NIE|DNI|CIF)?($|_)', 'i')
        then
          l_score_total := l_score_total - 250;
          l_motivo_descarte := nvl(l_motivo_descarte, 'CAMPO_TECNICO_IDENTIDAD');
        end if;

        if l_best_id = 'IDENTIFICADOR_DIRECCION'
           and regexp_like(c.column_name, '(^|_)(CODIGO_VIA|NUMERO_VIA|CODIGO|NUMERO)(_VIA|_R)?($|_)', 'i')
        then
          l_score_total := l_score_total - 220;
          l_motivo_descarte := nvl(l_motivo_descarte, 'CAMPO_NUMERICO_TECNICO_DIRECCION');
        end if;

        if l_best_id = 'IDENTIFICADOR_PERSONAL'
           and (
                regexp_like(c.column_name, '(^|_)(NOMBRE|NOMBRE_ALT|NOMBRE_USUARIO|US_NOMBRE)($|_)', 'i')
                or regexp_like(c.column_name, '(^|_)(NOM|NOMSO|NOMSOL|NOMARR|NOMUEC|ACU_NOMBRE|USU_LT_USU|UNIFAM_APENU|APELLIDOS_NOMBRE|NOMBRE_COMPLETO)($|_)', 'i')
              )
        then
          l_ctx_persona := l_ctx_persona_tab;
          if l_ctx_persona = 0 then
            l_score_total := l_score_total - 90;
            l_motivo_descarte := nvl(l_motivo_descarte, 'NOMBRE_SIN_CONTEXTO_PERSONA');
          end if;

          if l_ctx_apellidos_tab = 0 then
            l_score_total := l_score_total - 220;
            l_motivo_descarte := nvl(l_motivo_descarte, 'NOMBRE_SIN_APELLIDOS_TABLA');

            l_ratio_semantica := func_dm_ratio_nombre_sem(
                                  c.owner,
                                  c.table_name,
                                  c.column_name,
                                  p_sample_rows,
                                  l_sem_rows,
                                  l_sem_matches
                                );

            if nvl(l_sem_rows,0) >= 10 and nvl(l_ratio_semantica,0) >= 0.70 then
              l_score_total := l_score_total + 170;
              l_motivo_descarte := null;
            end if;
          end if;
        end if;

        proc_dm_clasifica(l_score_total, l_estado_final, l_enmascarar);

        if l_best_id = 'IDENTIFICADOR_PERSONAL'
           and l_score_nombre >= 85
           and l_force_mask <> 'Y'
           and (l_rows_total is null or l_null_ratio is null)
           and l_score_total >= 65
        then
          l_estado_final := case when l_score_total >= 85 then 'CONFIRMADO' else 'PROBABLE' end;
          l_enmascarar := 'Y';
          l_motivo_descarte := null;
        end if;

        if l_best_id = 'IDENTIFICADOR_PERSONAL'
           and (
                regexp_like(c.column_name, '(^|_)(NOMBRE|NOMBRE_ALT|NOMBRE_USUARIO|US_NOMBRE)($|_)', 'i')
                or regexp_like(c.column_name, '(^|_)(NOM|NOMSO|NOMSOL|NOMARR|NOMUEC|ACU_NOMBRE|USU_LT_USU|UNIFAM_APENU|APELLIDOS_NOMBRE|NOMBRE_COMPLETO)($|_)', 'i')
              )
           and l_ctx_apellidos_tab = 0
           and l_force_mask <> 'Y'
           and (nvl(l_sem_rows,0) < 10 or nvl(l_ratio_semantica,0) < 0.70)
        then
          l_estado_final := 'REVISAR';
          l_enmascarar   := 'N';
          l_motivo_descarte := 'NOMBRE_SIN_SEMANTICA_PERSONA';
        end if;

        if l_best_id = 'IDENTIFICADOR_TELEFONO'
           and l_force_mask <> 'Y'
           and l_score_nombre >= 70
           and nvl(l_rows_total,0) >= 10
           and (
                nvl(l_ratio,0) >= 0.45
                or nvl(l_score_patron,0) >= 25
               )
        then
          l_estado_final := case when l_score_total >= 65 then 'PROBABLE' else 'REVISAR' end;
          l_enmascarar := 'Y';
          l_motivo_descarte := null;
        end if;

        if l_force_mask <> 'Y'
           and l_best_id in ('IDENTIFICADOR_BANCARIO','IDENTIFICADOR_IDENTIDAD')
           and l_score_nombre >= 90
           and l_score_total >= 85
           and (l_rows_total is not null and l_rows_total < 10)
        then
          l_estado_final := 'PROBABLE';
          l_enmascarar := 'Y';
          l_motivo_descarte := null;
        end if;

        if l_rows_total is not null
           and l_rows_total < 10
           and l_force_mask <> 'Y'
           and not (
             l_best_id in ('IDENTIFICADOR_BANCARIO','IDENTIFICADOR_IDENTIDAD')
             and l_score_nombre >= 90
             and l_score_total >= 85
           )
        then
          l_estado_final := 'DESCARTADO';
          l_enmascarar := 'N';
          l_motivo_descarte := 'MUESTRA_INSUFICIENTE_MIN_10';
        elsif l_null_ratio is not null
           and l_null_ratio >= 0.995
           and l_force_mask <> 'Y'
           and not (
             l_best_id in ('IDENTIFICADOR_BANCARIO','IDENTIFICADOR_IDENTIDAD')
             and l_score_nombre >= 90
             and l_score_total >= 85
           )
        then
          l_estado_final := 'DESCARTADO';
          l_enmascarar := 'N';
          l_motivo_descarte := 'ALTA_NULIDAD_EN_MUESTRA';
        end if;

        if l_force_mask = 'Y' then
          l_enmascarar := 'Y';
          l_estado_final := 'CONFIRMADO';
          l_motivo_descarte := null;
        end if;

        insert into tdm_columna_hist(
          hist_id, ejecucion_id, owner_name, table_name, column_name,
          data_type, data_length, data_precision, data_scale,
          column_comment, identificador,
          score_nombre, score_comentario, score_patron, score_tabla, score_total,
          sample_rows, matched_rows, ratio_match, ratio_null,
          estado_final, motivo_descarte, enmascarar, hash_reglas
        ) values (
          seq_dm_columna_hist.nextval, p_ejecucion_id, c.owner, c.table_name, c.column_name,
          c.data_type, c.data_length, c.data_precision, c.data_scale,
          l_comment, l_best_id,
          l_score_nombre, l_score_coment, l_score_patron, l_score_tabla, l_score_total,
          l_rows_total, l_matches, l_ratio, l_null_ratio,
          l_estado_final, l_motivo_descarte, l_enmascarar,
          to_char(ora_hash(c.owner || '|' || c.table_name || '|' || c.column_name || '|' || l_best_id || '|' || l_score_total))
        );

        if l_enmascarar = 'Y' then
          proc_dm_recolecta_dep(p_ejecucion_id, c.owner, c.table_name, c.column_name);
        end if;

        l_cols_lote := l_cols_lote + 1;

        update tdm_ejecucion
           set columnas_proc = nvl(columnas_proc,0) + 1,
               progreso_pct = case
                 when columnas_total > 0 then round(((nvl(columnas_proc,0)+1) / columnas_total) * 100, 2)
                 else 100
               end,
               ultimo_objeto = c.owner || '.' || c.table_name || '.' || c.column_name,
               ultimo_paso = 'COLUMNA_PROCESADA',
               heartbeat_ts = systimestamp
         where ejecucion_id = p_ejecucion_id;

        if mod(l_cols_lote, p_commit_lote) = 0 then
          commit;
        end if;

      exception
        when others then
          proc_dm_log_error(p_ejecucion_id, c.owner, c.table_name, c.column_name, 'PROCESA_COLUMNA', sqlcode, sqlerrm);
      end;
    end loop;

    update tdm_objeto_ctrl
       set estado_objeto = 'PROCESADO',
           motivo_estado = null,
           ultimo_run_id = p_ejecucion_id,
           fecha_ult_analisis = systimestamp
     where owner_name = t.owner_name
       and table_name = t.table_name;

    update tdm_ejecucion
       set tablas_proc = nvl(tablas_proc,0) + 1,
           ultimo_paso = 'TABLA_FINALIZADA',
           heartbeat_ts = systimestamp
     where ejecucion_id = p_ejecucion_id;

    commit;
  end loop;

  proc_dm_sync_col_final(p_ejecucion_id);
  proc_dm_sync_dep_final(p_ejecucion_id);

  update tdm_ejecucion
     set estado = 'FINALIZADO',
         fase_proceso = 'DESCUBRIMIENTO',
         fecha_fin = systimestamp,
         progreso_pct = 100,
         ultimo_paso = 'FINALIZADO'
   where ejecucion_id = p_ejecucion_id;

  commit;
exception
  when others then
    proc_dm_log_error(p_ejecucion_id, l_esquema, null, null, 'PROCESO_GENERAL', sqlcode, sqlerrm);
    update tdm_ejecucion
       set estado = 'ERROR',
           fecha_fin = systimestamp,
           ultimo_paso = 'ERROR_FATAL'
     where ejecucion_id = p_ejecucion_id;
    commit;
    raise;
end proc_dm_procesa_desc;

------------------------------------------------------------------------------
-- API pública: ejecutar
------------------------------------------------------------------------------
------------------------------------------------------------------------------
-- API pública: ejecutar
------------------------------------------------------------------------------
procedure p_dm_descubrimiento(
    p_esquema          in varchar2,
    p_sample_rows      in number default 500,
    p_forzar_full      in char default 'N'
) is
  l_running      number;
  l_run_id       number;
  l_ejec_base_id number;
begin
  proc_dm_autocancel_huerfanas(15, 'Y');
  l_running := func_dm_conflicto_running(upper(p_esquema), null);

  if l_running > 0 then
    raise_application_error(-20011, 'Existe una ejecución EJECUTANDO en curso para el esquema/alcance');
  end if;

  if upper(nvl(p_forzar_full,'N')) <> 'Y' then
    begin
      select max(ejecucion_id)
        into l_ejec_base_id
        from tdm_ejecucion
       where esquema_objetivo = upper(p_esquema)
         and fase_proceso in ('DESCUBRIMIENTO','ENMASCARAMIENTO')
         and nvl(forzar_full,'N') = 'N'
         and estado in ('FINALIZADO')
         and columnas_total > 0;

    exception
      when no_data_found then
        l_ejec_base_id := null;
    end;

    if l_ejec_base_id is not null then
      raise_application_error(
        -20014,
        'El esquema ' || upper(p_esquema) ||
        ' ya tiene una ejecución maestra registrada con FORZAR_FULL = N. ' ||
        'Para volver a ejecutar debe usar p_dm_descubrimiento(''' ||
        upper(p_esquema) || ''',''Y'').'
      );
    end if;
  end if;

  BEGIN
    insert into tdm_ejecucion(
      ejecucion_id, esquema_objetivo, ejecutado_por, fase_proceso, estado,
      fecha_inicio, ultimo_paso, forzar_full, sesion_audsid, heartbeat_ts
    ) values (
      seq_dm_ejecucion.nextval, upper(p_esquema), sys_context('USERENV','SESSION_USER'),
      'DESCUBRIMIENTO', 'EJECUTANDO',
      systimestamp,
      case when upper(nvl(p_forzar_full,'N'))='Y' then 'INICIADO_FORZAR_FULL' else 'INICIADO' end,
      case when upper(nvl(p_forzar_full,'N'))='Y' then 'Y' else 'N' end,
      sys_context('USERENV','SESSIONID'),
      systimestamp
    )
    returning ejecucion_id into l_run_id;
  EXCEPTION
    WHEN DUP_VAL_ON_INDEX THEN
      raise_application_error(-20011, 'Existe una ejecución EJECUTANDO en curso para el esquema/alcance');
  END;

  proc_dm_registra_scope(l_run_id, upper(p_esquema), null);
  proc_dm_refresca_sesion(l_run_id);

  commit;

  proc_dm_prepara_objetos(
    upper(p_esquema),
    l_run_id,
    case when upper(nvl(p_forzar_full,'N'))='Y' then 'Y' else 'N' end
  );

  proc_dm_procesa_desc(l_run_id, func_dm_normaliza_sample(p_sample_rows), 100);
end p_dm_descubrimiento;
------------------------------------------------------------------------------
-- API pública: sobrecarga
------------------------------------------------------------------------------
procedure p_dm_descubrimiento(
    p_esquema     in varchar2,
    p_forzar_full in char
) is
begin
  p_dm_descubrimiento(
    p_esquema     => p_esquema,
    p_sample_rows => 500,
    p_forzar_full => p_forzar_full
  );
end p_dm_descubrimiento;

------------------------------------------------------------------------------
-- API pública: reanudar
------------------------------------------------------------------------------
procedure p_dm_reanudar(
    p_ejecucion_id in number,
    p_sample_rows  in number default 500,
    p_commit_lote  in number default 100
) is
  l_estado      tdm_ejecucion.estado%type;
  l_heartbeat   tdm_ejecucion.heartbeat_ts%type;
  l_sesion_viva number := 0;
begin
  proc_dm_autocancel_huerfanas(5, 'Y');

  select estado, heartbeat_ts
    into l_estado, l_heartbeat
    from tdm_ejecucion
   where ejecucion_id = p_ejecucion_id
   for update;

  if l_estado = 'EJECUTANDO' then
    l_sesion_viva := func_dm_sesion_viva(p_ejecucion_id);

    if l_sesion_viva = 0 then
      update tdm_ejecucion
         set estado = 'ABORTADA',
             fecha_fin = systimestamp,
             ultimo_paso = 'AUTO_ABORTADA_REANUDAR_SESION_CAIDA'
       where ejecucion_id = p_ejecucion_id
         and estado = 'EJECUTANDO';
      l_estado := 'ABORTADA';
    elsif nvl(l_heartbeat, systimestamp - numtodsinterval(9999,'MINUTE')) < systimestamp - numtodsinterval(5,'MINUTE') then
      update tdm_ejecucion
         set estado = 'ABORTADA',
             fecha_fin = systimestamp,
             ultimo_paso = 'AUTO_ABORTADA_REANUDAR_STALE'
       where ejecucion_id = p_ejecucion_id
         and estado = 'EJECUTANDO';
      l_estado := 'ABORTADA';
    end if;
  end if;

  if l_estado in ('FINALIZADO','CANCELADO') then
    raise_application_error(-20012, 'La ejecución no puede reanudarse por estado final');
  elsif l_estado = 'EJECUTANDO' then
    raise_application_error(-20013, 'La ejecución sigue activa');
  end if;

  update tdm_ejecucion
     set estado = 'EJECUTANDO',
         fecha_fin = null,
         ultimo_paso = 'REANUDADO'
   where ejecucion_id = p_ejecucion_id;

  proc_dm_refresca_sesion(p_ejecucion_id);

  commit;

  proc_dm_procesa_desc(p_ejecucion_id, func_dm_normaliza_sample(p_sample_rows), p_commit_lote);
end p_dm_reanudar;

------------------------------------------------------------------------------
-- API pública: cancelar
------------------------------------------------------------------------------
procedure p_dm_cancelar(
    p_ejecucion_id in number
) is
begin
  update tdm_ejecucion
     set estado = 'CANCELADO',
         fecha_fin = systimestamp,
         ultimo_paso = 'CANCELADO',
         heartbeat_ts = systimestamp,
         sesion_sid = null,
         sesion_serial = null,
         sesion_inst_id = null
   where ejecucion_id = p_ejecucion_id
     and estado in ('EJECUTANDO','PAUSADO','ERROR','ABORTADA');

  delete from tdm_dependencia_hist where ejecucion_id = p_ejecucion_id;
  delete from tdm_columna_hist     where ejecucion_id = p_ejecucion_id;

  commit;
end p_dm_cancelar;

end pkg_dm_descubrimiento;
/



