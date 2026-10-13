set echo off
set feedback on
set verify off
set serveroutput on size unlimited
set linesize 220
set pagesize 200
set long 50000
set trimspool on
set tab off
Rem Se fuerza DEFINE ON (no se asume el default de SQL*Plus): un glogin.sql/login.sql con SET DEFINE OFF
Rem dejaria vacias las sustituciones. Nada que toque la base depende de &var (esquema y tablespace van
Rem por variable de enlace); el unico uso es el nombre del SPOOL, que no acepta variables de enlace.
set define on

Rem ================================================================================
Rem INSTALACION ORDENADA DATAMASKING - DESCUBRIMIENTO + ENMASCARAMIENTO
Rem VERSION FF1 (NIST SP 800-38G): nucleo numerico con Cifrado que Preserva Formato
Rem                                estandar (AES-128). Solo cambia 12_dm_pkg_mask_ff1
Rem                                y la generacion del pepper (CSPRNG). El resto igual.
Rem ================================================================================
Rem
Rem Este archivo es una guia para SQL*Plus.
Rem - Los scripts @@ deben estar en la misma ruta de este archivo o ajustar la ruta.
Rem ================================================================================

column v_fecha noprint new_value v_fecha
select to_char(sysdate,'YYYYMMDD_HH24MISS') v_fecha from dual;
Rem Nombre de spool con fecha y hora; si la sustitucion fallara solo se pierde el nombre, no la instalacion.
spool install_datamasking_&v_fecha..log
Rem
Rem ----------------------------------------------------------------
Rem 1.0 DETECCION AUTOMATICA DEL ESQUEMA DEL MOTOR (ASTSYSADMIN o
Rem     ACC_ADMIN, segun cual exista)
Rem ----------------------------------------------------------------
Rem Algunos clientes SQL*Plus resuelven &&var a vacio en contextos sin comillas (GRANT, ALTER SESSION,
Rem TABLESPACE, SPOOL). Este bloque usa una variable de enlace (:g_esquemaast), que no depende de
Rem SET DEFINE/SCAN, y arma cada GRANT/ALTER SESSION con EXECUTE IMMEDIATE.
Rem No se detecta ni se usa tablespace: los CREATE TABLE/INDEX de 01 y 02 no la indican y Oracle toma
Rem la del esquema actual.
variable g_esquemaast varchar2(30)
variable g_install_mal number
exec :g_install_mal := 0
declare
  l_esquemaast dba_users.username%type;
begin
  select username into l_esquemaast
    from (select username from dba_users
           where username in ('ASTSYSADMIN','ACC_ADMIN')
           order by decode(username,'ASTSYSADMIN',1,'ACC_ADMIN',2,9))
   where rownum = 1;
  :g_esquemaast := l_esquemaast;
exception
  when no_data_found then
    raise_application_error(-20001,'No se encontro ni ASTSYSADMIN ni ACC_ADMIN en DBA_USERS -- no se puede determinar el esquema del motor DATAMASKING en esta base.');
end;
/

Rem Diagnostico fiable (PRINT muestra el bind tal cual, no depende de
Rem SET DEFINE/SCAN como el PROMPT con &&var que antes mentia aqui mismo).
prompt
prompt *** ESQUEMA DEL MOTOR DETECTADO (variable de enlace g_esquemaast) ***
print g_esquemaast
prompt *** Si el valor anterior no es el esquema esperado, Ctrl+C ahora. ***
prompt

Rem
Rem ----------------------------------------------------------------
Rem 1.1 PRIVILEGIOS DE SISTEMA PARA EL ESQUEMA DEL MOTOR
Rem ----------------------------------------------------------------

begin
  begin
    execute immediate 'grant select any dictionary to '||:g_esquemaast;
  exception when others then
    null;  -- ver validacion final
  end;
  begin
    execute immediate 'grant execute on SYS.DBMS_CRYPTO to '||:g_esquemaast;
  exception when others then
    null;  -- el usuario que instala puede no ver SYS.DBMS_CRYPTO; la validacion final (4.1c) informa si falta
  end;
end;
/

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
Rem 1.3 PRIVILEGIO ADMINISTRATIVO PARA GESTIONAR TAREAS PARALELAS
Rem     HUERFANAS DE OTRO ESQUEMA (dm_enmascara_cancel, dm_enmascara_reanudar)
Rem ----------------------------------------------------------------
Rem dm_enmascara_cancel.sql y dm_enmascara_reanudar.sql los corre cada DBA con su propio usuario y necesitan
Rem detener, reanudar o eliminar una tarea DBMS_PARALLEL_EXECUTE huerfana que pertenece a &&esquemaast. DROP_TASK/STOP_TASK solo
Rem actuan sobre tareas del CURRENT_USER; para tareas de otro esquema Oracle (11gR2+) ofrece
Rem ADM_DROP_TASK/ADM_STOP_TASK, protegidas por el rol ADM_PARALLEL_EXECUTE_TASK, que no viene en DBA.
Rem Se otorga una sola vez a ROL_DATAMASKING para que lo tenga cualquier DBA con ese rol.
grant ADM_PARALLEL_EXECUTE_TASK to ROL_DATAMASKING;

Rem
Rem ----------------------------------------------------------------
Rem 1.4 SINONIMOS PRIVADOS
Rem ----------------------------------------------------------------
Rem Los sinonimos privados ya NO se crean desde este instalador.
Rem
Rem Cada DBA debe crearlos conectado con su propio usuario:
Rem
Rem   conn <usuario>/<password>@<servicio>
Rem   @dm_creasyn <USUARIO>
Rem ----------------------------------------------------------------
Rem
Rem ================================================================================
Rem AHORA CONECTAR COMO EL ESQUEMA DEL MOTOR (detectado en el paso 1.0)
Rem ================================================================================

begin
  execute immediate 'ALTER SESSION SET CURRENT_SCHEMA = '||:g_esquemaast;
end;
/
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
Rem ================================================================
@@01_dm_descubrimiento_objetos.sql

Rem
Rem ----------------------------------------------------------------
Rem 2.3 CREACION DE OBJETOS DE ENMASCARAMIENTO
Rem ================================================================
@@02_dm_enmascaramiento_objetos.sql

Rem
Rem ----------------------------------------------------------------
Rem 2.3.1 CARGA DE SEMILLA DE SEGURIDAD (PEPPER)
Rem ----------------------------------------------------------------
Rem NOTA: El pepper es EFIMERO POR CAMPANA (ejecucion_id). No se genera en la
Rem   instalacion. Cada campana usa su PROPIA fila clave='PEPPER_MASK:'||ejec,
Rem   de modo que dos esquemas enmascarados a la vez tienen peppers independientes
Rem   (sin carrera de creacion ni purga cruzada).
Rem   pkg_dm_enmascarar.proc_dm_enmascaramiento lo crea al inicio de cada enmascarado
Rem   (RAWTOHEX(DBMS_CRYPTO.RANDOMBYTES(32)), idempotente, COMMIT antes del paralelo).
Rem   Se autopurga al llegar a FINALIZADO. Para abandonar una ejecucion interrumpida:
Rem      EXEC pkg_dm_enmascarar.proc_dm_pepper_purgar(<ejecucion_id>,'Y');
Rem   Invariante: dos esquemas con FK ENTRE SI deben ir en la MISMA ejecucion.
Rem   Se comparte entre los workers paralelos via tdm_secreto durante la corrida.
Rem   Requisito: GRANT EXECUTE ON SYS.DBMS_CRYPTO (concedido en la fase de SYS).

Rem
Rem ----------------------------------------------------------------
Rem 2.4 CARGA DE REGLAS DE DESCUBRIMIENTO
Rem ================================================================
@@03_dm_descubrimiento_carga_reglas.sql

Rem
Rem ----------------------------------------------------------------
Rem 2.5 CONFIGURACION DE EXCEPCIONES (OPCIONAL)
Rem ----------------------------------------------------------------
Rem Si existe el archivo y deseas cargar excepciones:
Rem   @@97_configurar_excepciones.sql
Rem ----------------------------------------------------------------
Rem ----------------------------------------------------------------
Rem 2.6 CREACION DE LOS PAQUETES DEL MOTOR
Rem ----------------------------------------------------------------
Rem El numero del archivo ES el orden de compilacion; la decena indica la familia:
Rem   1x  base compartida por descubrimiento y enmascaramiento (trazabilidad, SQL seguro,
Rem       nucleo FF1, dominios FK)
Rem   2x  descubrimiento (22 es la fachada: lo que invocan los scripts dm_descubre*)
Rem   3x  enmascaramiento (37 es la fachada: lo que invocan los scripts dm_enmascara*)
Rem   4x  satelite opcional fuera del nucleo (export Data Pump)
Rem Cada paquete solo usa paquetes de numero menor, o de su misma decena y numero menor.
Rem Solo las fachadas (22, 37), 10, 12 y 40 reciben grant al rol; los demas son internos.
@@10_dm_pkg_trazabilidad.sql
@@11_dm_pkg_sql_seguro.sql
@@12_dm_pkg_mask_ff1.sql
@@13_dm_pkg_dominios.sql
@@20_dm_pkg_desc_puntuacion.sql
@@21_dm_pkg_desc_catalogo.sql
@@22_dm_pkg_descubrimiento.sql
@@30_dm_pkg_pepper.sql
@@31_dm_pkg_mask_estado.sql
@@32_dm_pkg_mask_validacion.sql
@@33_dm_pkg_mask_dependencias.sql
@@34_dm_pkg_mask_worker.sql
@@35_dm_pkg_mask_columna.sql
@@36_dm_pkg_mask_sync.sql
@@37_dm_pkg_enmascarar.sql
@@40_dm_pkg_export.sql

Rem
Rem 2.8 La revision de errores de compilacion se hace una sola vez, al final (4.5).

Rem
Rem ----------------------------------------------------------------
Rem 2.9 GRANTS SOBRE OBJETOS AL ROL ROL_DATAMASKING
Rem ================================================================
grant execute on pkg_dm_descubrimiento to ROL_DATAMASKING;
grant execute on pkg_dm_mask_ff1       to ROL_DATAMASKING;
grant execute on pkg_dm_enmascarar      to ROL_DATAMASKING;
grant execute on pkg_dm_export          to ROL_DATAMASKING;
grant execute on pkg_dm_trazabilidad    to ROL_DATAMASKING;

grant select on tdm_ejecucion          to ROL_DATAMASKING;
grant select on tdm_ejecucion_scope    to ROL_DATAMASKING;
grant select on tdm_ejecucion_error    to ROL_DATAMASKING;
grant select on tdm_objeto_ctrl        to ROL_DATAMASKING;
grant select on tdm_regla              to ROL_DATAMASKING;
grant select on tdm_excepcion_col      to ROL_DATAMASKING;
grant select on tdm_mask_trace_evento to ROL_DATAMASKING;
grant select on tdm_columna_hist       to ROL_DATAMASKING;
grant select on tdm_dependencia_hist   to ROL_DATAMASKING;
grant select on tdm_columna_final      to ROL_DATAMASKING;
grant select on tdm_dependencia_final  to ROL_DATAMASKING;

Rem Estas tablas solo se escriben desde los paquetes del motor (derechos de definidor). El rol queda en
Rem SELECT: con INSERT/UPDATE directo un operador podria fabricar un APPLY_COL en tdm_mask_trace (la
Rem reanudacion confia en esa traza) o alterar el estado de dependencias que el POST restaura.
grant select on tdm_mask_solicitud      to ROL_DATAMASKING;
grant select on tdm_mask_trace          to ROL_DATAMASKING;
grant select on tdm_mask_dep_estado     to ROL_DATAMASKING;
grant select                  on tdm_mask_regla_esp      to ROL_DATAMASKING;
grant select                  on tdm_mask_relacion_sync  to ROL_DATAMASKING;
Rem tdm_secreto (peppers) NO se concede al rol a proposito: solo el dueño del motor la lee.

grant select on seq_dm_ejecucion          to ROL_DATAMASKING;
grant select on seq_dm_ejecucion_scope    to ROL_DATAMASKING;
grant select on seq_dm_regla              to ROL_DATAMASKING;
grant select on seq_dm_columna_hist       to ROL_DATAMASKING;
grant select on seq_dm_dependencia_hist   to ROL_DATAMASKING;
grant select on seq_dm_mask_solicitud     to ROL_DATAMASKING;
grant select on seq_dm_mask_trace         to ROL_DATAMASKING;
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
Rem La lista de DBA autorizados vive en un solo sitio, la variable de enlace g_dba_csv de abajo
Rem   (separada por comas). El grant y la verificacion 4.3 la leen de ahi.
Rem   Para otra organizacion, editar solo esa linea.
variable g_dba_csv varchar2(1000)
begin
  :g_dba_csv := 'ALOPEZDIAZ,ACASTANGI,DMIRANDA,EYPURISACA,ASANCLEMENTE,CSOETERS,ACAMING,CROSS';
end;
/

begin
  for r in (select trim(regexp_substr(:g_dba_csv, '[^,]+', 1, level)) usuario
              from dual
           connect by level <= regexp_count(:g_dba_csv, ',') + 1) loop
    begin
      execute immediate 'grant ROL_DATAMASKING to ' || r.usuario;
    exception when others then
      dbms_output.put_line('AVISO: no se pudo conceder ROL_DATAMASKING a ' || r.usuario || ': ' || sqlerrm);
    end;
  end loop;
end;
/


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
Rem 4.1b VALIDACION (solo informa, no concede nada) DE LOS PRIVILEGIOS
Rem      QUE EL MOTOR NECESITA SOBRE LOS ESQUEMAS A ENMASCARAR
Rem ----------------------------------------------------------------
Rem El paquete corre con derechos del definidor (el dueno del motor): sus roles no cuentan, ni siquiera
Rem DBA. Sin UPDATE sobre el esquema destino el enmascarado falla con ORA-01031 en todas las columnas.
Rem Cada privilegio puede estar concedido como sistema (ANY) o, para un alcance mas estricto, como
Rem UPDATE/ALTER directo sobre las tablas del esquema destino; esta comprobacion solo mira los de
Rem sistema y lo informa. La decision de conceder es de seguridad.
declare
  l_n number;
begin
  dbms_output.put_line('Privilegios de sistema CONCEDIDOS DIRECTAMENTE a '||:g_esquemaast||':');
  for r in (select column_value as priv
              from table(sys.odcivarchar2list('SELECT ANY TABLE','UPDATE ANY TABLE',
                                              'ALTER ANY TABLE','ALTER ANY TRIGGER','CREATE JOB'))) loop
    select count(*) into l_n from dba_sys_privs where grantee = :g_esquemaast and privilege = r.priv;
    dbms_output.put_line('  '||rpad(r.priv,20)||case when l_n > 0 then 'concedido'
      else 'NO concedido (valido solo si hay UPDATE/ALTER directo sobre cada tabla destino)' end);
  end loop;
end;
/

Rem
Rem ----------------------------------------------------------------
Rem 4.1c VALIDACION (solo informa) DE EXECUTE SOBRE PAQUETES DE SYS
Rem ----------------------------------------------------------------
Rem Por la misma razon que 4.1b (el motor compila con derechos del definidor), el
Rem EXECUTE tiene que estar concedido al esquema del motor o a PUBLIC, no por un rol.
Rem DBMS_CRYPTO se concedio arriba; los demas suelen venir en PUBLIC, pero una base
Rem endurecida puede haberlo revocado y entonces 10..40 compilan con PLS-00201.
declare
  l_n number;
begin
  dbms_output.put_line('EXECUTE sobre paquetes de SYS para '||:g_esquemaast||' o PUBLIC:');
  for r in (select column_value as pkg
              from table(sys.odcivarchar2list('DBMS_CRYPTO','DBMS_PARALLEL_EXECUTE',
                                              'DBMS_SCHEDULER','DBMS_LOCK','DBMS_DATAPUMP'))) loop
    select count(*) into l_n from dba_tab_privs
     where owner = 'SYS' and table_name = r.pkg and privilege = 'EXECUTE'
       and grantee in (:g_esquemaast, 'PUBLIC');
    dbms_output.put_line('  '||rpad(r.pkg,22)||case when l_n > 0 then 'concedido'
      else 'NO concedido: conceder GRANT EXECUTE ON SYS.'||r.pkg||' TO '||:g_esquemaast end);
  end loop;
end;
/

Rem
Rem ----------------------------------------------------------------
Rem 4.1 VALIDACION DE OBJETOS DEL MOTOR (esperado contra real)
Rem ----------------------------------------------------------------
Rem La lista esperada es la que crean 01, 02 y los paquetes 10..40 (17 tablas,
Rem 9 secuencias, 16 paquetes con su cuerpo) y es la misma que borra 98_uninstall.sql.
Rem Si se agrega o se retira un objeto del motor, actualizar las TRES listas a la vez:
Rem   98_uninstall.sql, esta validacion y los GRANT de 2.9.
Rem Solo se imprimen las FALLAS (objeto ausente o INVALID); sin fallas, una linea OK.
declare
  l_esq  varchar2(128) := :g_esquemaast;
  l_tot  number := 0;
  l_mal  number := 0;
  l_est  varchar2(20);

  procedure proc_chequea(p_tipo varchar2, p_lista sys.odcivarchar2list) is
  begin
    for i in 1 .. p_lista.count loop
      l_tot := l_tot + 1;
      begin
        select status into l_est
          from dba_objects
         where owner = l_esq and object_type = p_tipo and object_name = p_lista(i);
      exception
        when no_data_found then l_est := 'FALTA';
      end;
      if l_est <> 'VALID' then
        l_mal := l_mal + 1;
        dbms_output.put_line('  '||rpad(p_tipo,13)||rpad(p_lista(i),28)||l_est);
      end if;
    end loop;
  end;
begin
  dbms_output.put_line('Validacion de objetos del motor en '||l_esq||':');
  proc_chequea('TABLE', sys.odcivarchar2list(
    'TDM_EJECUCION','TDM_EJECUCION_ERROR','TDM_EJECUCION_SCOPE','TDM_OBJETO_CTRL','TDM_REGLA',
    'TDM_EXCEPCION_COL','TDM_COLUMNA_HIST','TDM_DEPENDENCIA_HIST','TDM_COLUMNA_FINAL',
    'TDM_DEPENDENCIA_FINAL','TDM_SECRETO','TDM_MASK_TRACE_EVENTO','TDM_MASK_SOLICITUD','TDM_MASK_TRACE',
    'TDM_MASK_DEP_ESTADO','TDM_MASK_REGLA_ESP','TDM_MASK_RELACION_SYNC'));
  proc_chequea('SEQUENCE', sys.odcivarchar2list(
    'SEQ_DM_EJECUCION','SEQ_DM_EJECUCION_SCOPE','SEQ_DM_REGLA','SEQ_DM_COLUMNA_HIST',
    'SEQ_DM_DEPENDENCIA_HIST','SEQ_DM_MASK_SOLICITUD','SEQ_DM_MASK_TRACE','SEQ_DM_MASK_REGLA_ESP',
    'SEQ_DM_MASK_RELACION_SYNC'));
  proc_chequea('PACKAGE', sys.odcivarchar2list(
    'PKG_DM_TRAZABILIDAD','PKG_DM_DESC_PUNTUACION','PKG_DM_DOMINIOS','PKG_DM_DESC_CATALOGO','PKG_DM_DESCUBRIMIENTO','PKG_DM_MASK_FF1',
    'PKG_DM_SQL_SEGURO','PKG_DM_MASK_WORKER','PKG_DM_MASK_DEPENDENCIAS','PKG_DM_PEPPER','PKG_DM_MASK_ESTADO','PKG_DM_MASK_VALIDACION','PKG_DM_MASK_COLUMNA','PKG_DM_MASK_SYNC',
    'PKG_DM_ENMASCARAR','PKG_DM_EXPORT'));
  proc_chequea('PACKAGE BODY', sys.odcivarchar2list(
    'PKG_DM_TRAZABILIDAD','PKG_DM_DESC_PUNTUACION','PKG_DM_DOMINIOS','PKG_DM_DESC_CATALOGO','PKG_DM_DESCUBRIMIENTO','PKG_DM_MASK_FF1',
    'PKG_DM_SQL_SEGURO','PKG_DM_MASK_WORKER','PKG_DM_MASK_DEPENDENCIAS','PKG_DM_PEPPER','PKG_DM_MASK_ESTADO','PKG_DM_MASK_VALIDACION','PKG_DM_MASK_COLUMNA','PKG_DM_MASK_SYNC',
    'PKG_DM_ENMASCARAR','PKG_DM_EXPORT'));
  :g_install_mal := :g_install_mal + l_mal;
  if l_mal = 0 then
    dbms_output.put_line('  OK: '||l_tot||' objetos esperados, todos presentes y VALID.');
  else
    dbms_output.put_line('  ATENCION: '||l_mal||' de '||l_tot||' objetos con falla (ver arriba y 4.5).');
  end if;
end;
/

Rem
Rem ----------------------------------------------------------------
Rem 4.2 VALIDACION DE GRANTS AL ROL
Rem ----------------------------------------------------------------

select grantee,
       owner,
       table_name,
       privilege
from dba_tab_privs
where owner = :g_esquemaast
  and grantee = 'ROL_DATAMASKING'
order by table_name, privilege;

Rem
Rem ----------------------------------------------------------------
Rem 4.3 VALIDACION DE ASIGNACION DEL ROL A LOS DBA
Rem ----------------------------------------------------------------

select grantee,
       granted_role
from dba_role_privs
where granted_role = 'ROL_DATAMASKING'
  and grantee in (
    select trim(regexp_substr(:g_dba_csv, '[^,]+', 1, level))
      from dual
   connect by level <= regexp_count(:g_dba_csv, ',') + 1)
order by grantee;

/*
Rem
Rem ----------------------------------------------------------------
Rem 4.4 VALIDACION DE SINONIMOS EN LOS DBA
Rem ----------------------------------------------------------------

	select owner,
		   synonym_name,
		   table_owner,
		   table_name
	from dba_synonyms
	where owner in (
		select trim(regexp_substr(:g_dba_csv, '[^,]+', 1, level))
		  from dual
		connect by level <= regexp_count(:g_dba_csv, ',') + 1)  and table_owner = :g_esquemaast
	order by owner, synonym_name;
*/
Rem
Rem ----------------------------------------------------------------
Rem 4.5 VALIDACION DE ERRORES DE COMPILACION
Rem ----------------------------------------------------------------

declare
  l_n number := 0;
begin
  for r in (select name, type, line, position, text
              from dba_errors
             where owner = :g_esquemaast
               and name like 'PKG\_DM\_%' escape '\'
             order by name, type, sequence) loop
    l_n := l_n + 1;
    dbms_output.put_line('  '||r.type||' '||r.name||' ('||r.line||','||r.position||'): '||r.text);
  end loop;
  :g_install_mal := :g_install_mal + l_n;
  if l_n = 0 then
    dbms_output.put_line('  OK: sin errores de compilacion en los paquetes del motor.');
  else
    dbms_output.put_line('  ATENCION: '||l_n||' errores de compilacion (ver arriba).');
  end if;
end;
/

spool off

Rem La instalacion falla cerrada: con objetos ausentes/INVALID o errores de compilacion termina con
Rem codigo de salida distinto de cero (la salida de 4.1 y 4.5 ya esta impresa arriba).
whenever sqlerror exit failure
begin
  if :g_install_mal > 0 then
    raise_application_error(-20099, 'INSTALACION INCOMPLETA: '||:g_install_mal||' objeto(s) ausente(s), INVALID o con errores de compilacion (ver 4.1 y 4.5).');
  end if;
end;
/
whenever sqlerror continue
Rem
Rem ================================================================================
Rem FIN DE INSTALACION / VALIDACION
Rem ================================================================================

Rem
Rem ================================================================================
Rem ANEXO (OPCIONAL, NO BLOQUEANTE): SERVICIO RAC + JOB_CLASS JC_DATAMASKING
Rem ================================================================================
Rem proc_dm_ejecuta_update_seguro (pkg_dm_mask_worker) usa de forma opcional una job_class llamada
Rem JC_DATAMASKING con DBMS_PARALLEL_EXECUTE.RUN_TASK (afinidad de instancia RAC, menos "gc current
Rem block/grant"); si no existe, el motor funciona igual sin ella. Este anexo documenta como crearla.
Rem No forma parte de la instalacion normal y nada de esto se ejecuta desde este script.
Rem
Rem PRERREQUISITO: un servicio RAC dedicado (via Clusterware/srvctl, NUNCA via
Rem DBMS_SERVICE.CREATE_SERVICE - eso rompe el conocimiento de Clusterware sobre el
Rem servicio y su failover/HA). Estos comandos son de SISTEMA OPERATIVO (se ejecutan como
Rem el usuario Oracle/grid, en una shell, NO en SQL*Plus) - se documentan aqui solo como
Rem referencia, no se pueden lanzar desde este script:
Rem
Rem   PASO 1) Crear el servicio (ajustar db_unique_name, nombre de servicio e instancia(s)
Rem           preferida(s)/disponible(s) al entorno real; -P BASIC evita reintentos
Rem           agresivos de reconexion para una carga batch como esta):
Rem     srvctl add service -d <db_unique_name> -s SRV_DATAMASKING -r <instancia_preferida> ^
Rem                        -a <instancias_disponibles_failover> -P BASIC -e NONE
Rem
Rem   PASO 2) Arrancar el servicio:
Rem     srvctl start service -d <db_unique_name> -s SRV_DATAMASKING
Rem
Rem   PASO 3) Verificar estado:
Rem     srvctl status service -d <db_unique_name> -s SRV_DATAMASKING
Rem
Rem Con el servicio SRV_DATAMASKING ya arriba, esto SI es SQL y puede ejecutarse tal cual
Rem (conectado como SYS o un usuario con EXECUTE en DBMS_SCHEDULER a nivel de CREATE_JOB_CLASS,
Rem tipicamente SYS):
Rem
Rem   PASO 4) Crear la job_class ligada al servicio:
Rem     BEGIN
Rem       DBMS_SCHEDULER.CREATE_JOB_CLASS(
Rem         job_class_name => 'JC_DATAMASKING',
Rem         service        => 'SRV_DATAMASKING',
Rem         comments       => 'Afinidad de instancia RAC para el motor de enmascaramiento FF1'
Rem       );
Rem     END;
Rem     /
Rem
Rem   PASO 5) Autorizar al esquema del motor (ASTSYSADMIN o ACC_ADMIN, el que exista; ver &&esquemaast)
Rem           a lanzar jobs en esa clase. Sin el grant, RUN_TASK con job_class falla con
Rem           ORA-27478/ORA-27479; como el motor solo comprueba que la clase exista, conviene
Rem           concederlo en el mismo momento en que se crea:
Rem     GRANT EXECUTE ON SYS.JC_DATAMASKING TO <esquema_del_motor>;
Rem
Rem   PASO 6) Verificacion:
Rem     SELECT job_class_name, service FROM dba_scheduler_job_classes
Rem      WHERE job_class_name = 'JC_DATAMASKING';
Rem
Rem     SELECT grantee, privilege FROM dba_tab_privs
Rem      WHERE table_name = 'JC_DATAMASKING' AND grantee = '<esquema_del_motor>';
Rem
Rem A partir de aqui, la siguiente ejecucion de proc_dm_ejecuta_update_seguro detecta
Rem JC_DATAMASKING sola (SELECT COUNT(*) FROM dba_scheduler_job_classes) y empieza a usarla
Rem sin ningun cambio de codigo ni de configuracion adicional.
Rem
Rem PARA REVERTIR (quitar la afinidad sin tocar el motor, vuelve al comportamiento actual):
Rem     BEGIN DBMS_SCHEDULER.DROP_JOB_CLASS(job_class_name => 'JC_DATAMASKING', force => TRUE); END;
Rem     /
Rem     srvctl stop service  -d <db_unique_name> -s SRV_DATAMASKING
Rem     srvctl remove service -d <db_unique_name> -s SRV_DATAMASKING
Rem ================================================================================

