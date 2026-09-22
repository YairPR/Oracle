Rem dm_monitor_stop.sql  (VERSION FF1 - NIST SP 800-38G)
Rem
Rem    NOMBRE
Rem      dm_monitor_stop.sql - Punto de salida de dm_monitor_avance.sql
Rem
Rem    DESCRIPCION
Rem      Archivo auxiliar. NO se usa de forma independiente - solo lo invoca
Rem      dm_monitor_avance.sql cuando decide que debe dejar de refrescarse
Rem      (ejecucion llegada a estado terminal, o limite de seguridad de 15
Rem      refrescos alcanzado). Imprime el mensaje final correspondiente.
Rem
Rem      POR QUE ESTE ARCHIVO EXISTE POR SEPARADO (y no un simple "if" al
Rem      final de dm_monitor_avance.sql): SQL*Plus no permite saltar
Rem      condicionalmente una linea de comando ya escrita en el script - solo
Rem      permite sustituir el ARGUMENTO de un comando que ya esta
Rem      textualmente presente (p.ej. "@algo.sql &&VARIABLE" funciona,
Rem      sustituir TODO el comando via una variable en blanco no es fiable:
Rem      ver el comentario dedicado en dm_monitor_avance.sql, seccion final).
Rem      La solucion es que dm_monitor_avance.sql, cuando debe parar, invoque
Rem      a ESTE archivo en vez de volver a invocarse a si mismo - y como este
Rem      archivo no contiene ninguna llamada recursiva, la cadena de
Rem      auto-refresco termina aqui de forma garantizada, sin ambigüedad.
Rem
Rem    USO
Rem      Ninguno directo. Argumentos posicionales que le pasa
Rem      dm_monitor_avance.sql:
Rem        &1 = ejecucion_id
Rem        &2 = fase_proceso (DESCUBRIMIENTO / ENMASCARAMIENTO)
Rem        &3 = motivo (FIN / PAUSA)
Rem        &4 = estado final de TDM_EJECUCION
Rem        &5 = progreso_pct en el momento de parar
Rem        &6 = intervalo de refresco usado (para el mensaje de PAUSA)
Rem
Rem    MODIFICADO   (MM/DD/YY)
Rem    epurisaca    09/20/26 - Creacion, junto con dm_monitor_avance.sql.

set termout on
set feedback off
set verify off
set define on

declare
    v_ejec    varchar2(50)  := '&1';
    v_fase    varchar2(30)  := upper(trim('&2'));
    v_motivo  varchar2(20)  := upper(trim('&3'));
    v_estado  varchar2(30)  := upper(trim('&4'));
    v_pct     varchar2(20)  := '&5';
    v_interv  varchar2(20)  := '&6';
begin
    dbms_output.put_line('=========================================');
    if v_motivo = 'FIN' then
        dbms_output.put_line('>>> Monitor finalizado [' || v_fase || ']  ejecucion_id=' || v_ejec ||
                              '  estado final=' || v_estado);
    else
        dbms_output.put_line('>>> Monitor pausado [' || v_fase || '] tras 15 refrescos consecutivos');
        dbms_output.put_line('    (limite de seguridad de anidamiento de SQL*Plus - ver encabezado de dm_monitor_avance.sql).');
        dbms_output.put_line('    Progreso actual: ' || v_pct || '%.');
        dbms_output.put_line('    Para seguir monitoreando: @dm_monitor_avance ' || v_ejec ||
                              case when v_interv is not null and v_interv <> '' then ' ' || v_interv else '' end);
    end if;
    dbms_output.put_line('=========================================');
end;
/

undefine 1
undefine 2
undefine 3
undefine 4
undefine 5
undefine 6
