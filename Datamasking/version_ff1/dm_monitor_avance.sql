Rem dm_monitor_avance.sql  (VERSION FF1 - NIST SP 800-38G)
Rem
Rem    NOMBRE
Rem      dm_monitor_avance.sql - Monitor de avance en vivo (segunda sesion)
Rem
Rem    DESCRIPCION
Rem      Script companero de @dm_descubre / @dm_descubre_set / @dm_enmascara.
Rem      Se ejecuta en una SEGUNDA sesion SQL*Plus (otra ventana/conexion),
Rem      mientras la primera sesion sigue bloqueada corriendo el descubrimiento
Rem      o el enmascarado. Consulta TDM_EJECUCION cada N segundos y dibuja una
Rem      barra de progreso ASCII con el avance real (fase en curso -
Rem      DESCUBRIMIENTO o ENMASCARAMIENTO -, tablas y columnas procesadas,
Rem      ultimo paso, ultimo objeto tocado), hasta que la ejecucion llega a
Rem      un estado terminal (FINALIZADO/ERROR/CANCELADO/ABORTADA).
Rem
Rem    POR QUE UNA SEGUNDA SESION (y no una barra "en vivo" dentro de la
Rem    misma sesion que corre el descubrimiento/enmascarado)
Rem      DBMS_OUTPUT solo se entrega al cliente SQL*Plus cuando el bloque
Rem      PL/SQL que lo genero TERMINA de ejecutarse por completo, no linea a
Rem      linea mientras corre. La sesion que ejecuta
Rem      pkg_dm_descubrimiento.p_dm_descubrimiento(...) (o
Rem      pkg_dm_enmascarar.p_dm_enmascara) esta dentro de UN solo bloque
Rem      anonimo que puede tardar de 1 minuto a mas de 1 hora; nada se puede
Rem      imprimir ahi hasta que termine, sea cual sea el mecanismo usado
Rem      (DBMS_OUTPUT, DBMS_APPLICATION_INFO, etc.), porque el bloqueo es del
Rem      lado del CLIENTE, no del servidor. Lo que SI es real y ya se
Rem      actualiza con COMMIT periodicos DURANTE la ejecucion (ver
Rem      04_dm_pkg_descubrimiento.sql, proc_dm_descubrimiento_core, y
Rem      05_dm_pkg_enmascarar.sql, proc_dm_mask_cat: columnas_proc /
Rem      tablas_proc / progreso_pct / ultimo_objeto / fase_proceso se
Rem      actualizan y confirman por cada tabla y cada lote de columnas) es la
Rem      fila de TDM_EJECUCION - y eso SI puede leerlo una sesion DISTINTA en
Rem      cualquier momento, porque ya quedo comprometido (committed). Este
Rem      script explota exactamente eso, con cero cambios al motor.
Rem
Rem    LIMITE DE ANIDAMIENTO DE SQL*PLUS (IMPORTANTE - LEER)
Rem      Este script se relanza a si mismo (@dm_monitor_avance.sql) despues
Rem      de cada pausa, para simular un loop de refresco. SQL*Plus limita el
Rem      anidamiento de scripts (@ / @@) a un numero fijo de niveles
Rem      (historicamente 20, error SP2-0023 al excederlo), y cada
Rem      relanzamiento cuenta como un nivel mas que NO se libera hasta que la
Rem      cadena completa de refrescos termina. Por eso este script NO se
Rem      relanza de forma indefinida: se detiene solo, de forma limpia
Rem      (delegando en dm_monitor_stop.sql - ver mas abajo), tras
Rem      G_MAX_TICKS refrescos consecutivos (constante interna = 15, con
Rem      margen de seguridad bajo el limite real de 20) y le pide al usuario
Rem      volver a lanzarlo con el mismo ejecucion_id (flecha-arriba + Enter
Rem      en la mayoria de terminales).
Rem
Rem    POR QUE HAY UN ARCHIVO dm_monitor_stop.sql SEPARADO
Rem      Version inicial (2026-09-20, primera prueba real): el "loop" decidia
Rem      entre seguir o parar construyendo TODO el siguiente comando (incluido
Rem      el verbo - "@@dm_monitor_avance.sql ..." o "prompt ...") dentro de
Rem      una variable de sustitucion, y ejecutandolo con una linea que era
Rem      solo "&&NEXTCMD". Fallo en produccion con
Rem      "SP2-0042: comando desconocido "&&NEXTCMD"": SQL*Plus reconoce el
Rem      comando ANTES de aplicar sustitucion sobre el resto de la linea -
Rem      sustituir el VERBO completo de un comando (no solo sus argumentos)
Rem      no es fiable. La correccion: mantener el comando siempre literal en
Rem      el texto del script ("@" o "@archivo.sql", nunca sintetizado) y
Rem      sustituir UNICAMENTE su argumento - exactamente el mismo patron ya
Rem      usado en todo este proyecto para &1/&2/&3. Como el "siguiente paso"
Rem      puede ser "seguir" o "parar", y no se puede saltar condicionalmente
Rem      una linea de comando ya escrita, se resuelve invocando a UN archivo
Rem      u OTRO (siempre via "@archivo &&ARGS", nunca sustituyendo el "@" en
Rem      si): "seguir" reinvoca este mismo archivo; "parar" invoca
Rem      dm_monitor_stop.sql, que no contiene ninguna llamada recursiva y por
Rem      lo tanto termina la cadena de forma garantizada.
Rem
Rem    USO
Rem      En una segunda sesion SQL*Plus conectada al mismo ASTSYSADMIN:
Rem        @dm_monitor_avance ESQUEMA
Rem        @dm_monitor_avance ESQUEMA 20
Rem        @dm_monitor_avance 123
Rem        @dm_monitor_avance 123 5
Rem
Rem      Parametro 1 (obligatorio): ejecucion_id NUMERICO, o nombre de
Rem                                 ESQUEMA (se resuelve a la ejecucion mas
Rem                                 reciente en estado EJECUTANDO para ese
Rem                                 esquema; si no hay ninguna EJECUTANDO, a
Rem                                 la mas reciente de cualquier estado).
Rem      Parametro 2 (opcional): intervalo de refresco en segundos.
Rem                              Default 10, minimo 3, maximo 120.
Rem      Parametro 3: USO INTERNO (contador de refrescos para el auto-stop
Rem                   de seguridad). NO indicarlo manualmente.
Rem
Rem    COMPATIBILIDAD
Rem      Oracle 18c en adelante (usa DBMS_SESSION.SLEEP, sin grants extra).
Rem      Confirmado sobre Oracle 19c.
Rem
Rem    MODIFICADO   (MM/DD/YY)
Rem    epurisaca    09/20/26 - Creacion.
Rem    epurisaca    09/20/26 - Fix: reemplazado el mecanismo de auto-refresco
Rem                            ("&&NEXTCMD" como linea completa, SP2-0042 en
Rem                            prueba real) por despacho a archivo literal
Rem                            ("@archivo &&ARGS") + nuevo dm_monitor_stop.sql
Rem                            para el caso de parada. Se agrego fase_proceso
Rem                            (DESCUBRIMIENTO/ENMASCARAMIENTO) al titulo y a
Rem                            cada linea de refresco (pedido del usuario).

set verify off
set feedback off
set heading off
set define on
set linesize 220
set pagesize 0
set trimspool on
set tab off
set termout off

alter session set current_schema = ASTSYSADMIN;

column "2" new_value 2 noprint
select null as "2" from dual where 1=2;

column "3" new_value 3 noprint
select null as "3" from dual where 1=2;

column c_arg1 new_value V_ARG1 noprint
column c_arg2 new_value V_ARG2 noprint
column c_arg3 new_value V_ARG3 noprint

select trim('&1') c_arg1,
       trim('&2') c_arg2,
       trim('&3') c_arg3
  from dual;

set termout on

declare
    g_intervalo_min constant number := 3;
    g_intervalo_max constant number := 120;

    v_arg1      varchar2(200) := '&&V_ARG1';
    v_intervalo number        := nvl(to_number(nullif('&&V_ARG2','')), 10);
begin
    if v_arg1 is null or v_arg1 = '' then
        raise_application_error(-20401,
            'Uso: @dm_monitor_avance ESQUEMA | @dm_monitor_avance EJECUCION_ID  [intervalo_seg]');
    end if;

    if v_intervalo < g_intervalo_min or v_intervalo > g_intervalo_max then
        raise_application_error(-20402,
            'Intervalo invalido (' || v_intervalo || '). Debe estar entre ' ||
            g_intervalo_min || ' y ' || g_intervalo_max || ' segundos.');
    end if;
end;
/

set termout off

column c_ejec_id new_value V_EJEC_ID noprint

select to_char(
         case
           when regexp_like('&&V_ARG1', '^[0-9]+$')
             then to_number('&&V_ARG1')
           else
             nvl(
               (select max(ejecucion_id) from tdm_ejecucion
                 where esquema_objetivo = upper('&&V_ARG1') and estado = 'EJECUTANDO'),
               (select max(ejecucion_id) from tdm_ejecucion
                 where esquema_objetivo = upper('&&V_ARG1'))
             )
         end
       ) as c_ejec_id
  from dual;

set termout on

column c_fase new_value V_FASE noprint

declare
    v_existe number := 0;
    v_fase   varchar2(30);
begin
    if '&&V_EJEC_ID' is null or '&&V_EJEC_ID' = '' then
        raise_application_error(-20403,
            'No se encontro ninguna ejecucion en TDM_EJECUCION para "&&V_ARG1".');
    end if;

    select count(*)
      into v_existe
      from tdm_ejecucion
     where ejecucion_id = &&V_EJEC_ID;

    if v_existe = 0 then
        raise_application_error(-20404,
            'No existe la ejecucion_id &&V_EJEC_ID en TDM_EJECUCION.');
    end if;

    if '&&V_ARG3' is null or '&&V_ARG3' = '' then
        select nvl(fase_proceso,'?') into v_fase from tdm_ejecucion where ejecucion_id = &&V_EJEC_ID;
        dbms_output.put_line('=========================================');
        dbms_output.put_line('Monitor de avance [' || v_fase || '] - ejecucion_id = &&V_EJEC_ID');
        dbms_output.put_line('Refresco cada ' || nvl(to_number(nullif('&&V_ARG2','')),10) ||
                              ' seg. Se detiene solo al terminar, o tras 15 refrescos (ver encabezado del script).');
        dbms_output.put_line('=========================================');
    end if;
end;
/

set heading off
set feedback off

column c_estado_chk new_value V_ESTADO_CHK noprint
column c_fase       new_value V_FASE       noprint
column c_linea      format a220

select estado as c_estado_chk,
       nvl(fase_proceso,'?') as c_fase,
       '[' || nvl(fase_proceso,'?') || '] ' ||
       '[' || rpad(rpad('>', greatest(least(round(nvl(progreso_pct,0)/5),20),0), '>'), 20, '-') || '] ' ||
       lpad(to_char(nvl(progreso_pct,0), '990.00'), 7) || '%   ' ||
       rpad(estado, 11) ||
       '  tablas ' || lpad(nvl(tablas_proc,0),4) || '/' || rpad(nvl(tablas_total,0),4) ||
       '  columnas ' || lpad(nvl(columnas_proc,0),5) || '/' || rpad(nvl(columnas_total,0),5) ||
       '  ' || rpad(substr(nvl(ultimo_paso,'-'), 1, 22), 22) ||
       '  ' || substr(nvl(ultimo_objeto,'-'), 1, 55) as c_linea
  from tdm_ejecucion
 where ejecucion_id = &&V_EJEC_ID;

set termout off

declare
    g_max_ticks constant number := 15;  -- margen de seguridad bajo el limite de 20 niveles de SQL*Plus
    v_tick      number := nvl(to_number('&&V_ARG3'), 0);
begin
    if '&&V_ESTADO_CHK' not in ('FINALIZADO','ERROR','CANCELADO','ABORTADA','ABORTADO')
       and v_tick < g_max_ticks
    then
        dbms_session.sleep(nvl(to_number(nullif('&&V_ARG2','')), 10));
    end if;
end;
/

column c_motivo new_value NEXT_MOTIVO noprint
column c_tick   new_value NEXT_TICK   noprint
column c_pct    new_value NEXT_PCT    noprint
column c_target new_value NEXTFILE    noprint

select motivo as c_motivo,
       tick_next as c_tick,
       progreso as c_pct,
       case
         when motivo in ('FIN','PAUSA')
           then 'dm_monitor_stop.sql &&V_EJEC_ID &&V_FASE ' || motivo || ' &&V_ESTADO_CHK ' || progreso || ' &&V_ARG2'
         else 'dm_monitor_avance.sql &&V_EJEC_ID &&V_ARG2 ' || tick_next
       end as c_target
  from (
        select case
                 when '&&V_ESTADO_CHK' in ('FINALIZADO','ERROR','CANCELADO','ABORTADA','ABORTADO') then 'FIN'
                 when nvl(to_number('&&V_ARG3'),0) + 1 >= 15 then 'PAUSA'
                 else 'SIGUE'
               end as motivo,
               nvl(to_number('&&V_ARG3'),0) + 1 as tick_next,
               (select round(nvl(progreso_pct,0),2) from tdm_ejecucion where ejecucion_id = &&V_EJEC_ID) as progreso
          from dual
       );

set termout on
@@&&NEXTFILE

undefine 1
undefine 2
undefine 3
undefine V_ARG1
undefine V_ARG2
undefine V_ARG3
undefine V_EJEC_ID
undefine V_FASE
undefine V_ESTADO_CHK
undefine NEXT_MOTIVO
undefine NEXT_TICK
undefine NEXT_PCT
undefine NEXTFILE
