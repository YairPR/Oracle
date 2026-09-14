Rem ================================================================================
Rem GUION DE USO - DATAMASKING VERSION FF1 (NIST SP 800-38G)
Rem ================================================================================
Rem Runbook operativo. NO ejecuta nada: son los comandos, en orden, para una
Rem campana de enmascaramiento. Usa los scripts @dm_*.sql de esta carpeta.
Rem Reemplaza <ESQUEMA>, <EJEC>, <USUARIO>, <RUTA>, <DIR_ORACLE>, <ARCHIVO>.
Rem
Rem Cripto: dominios numericos (DNI/NIE/CIF/cuenta/IBAN) con FF1 (AES-128),
Rem biyectivo y determinista. Texto libre por semilla (no biyectivo).
Rem
Rem Pepper EFIMERO POR CAMPANA: cada ejecucion usa su propia semilla
Rem   tdm_secreto.clave = 'PEPPER_MASK:'||ejecucion_id
Rem La crea p_dm_enmascara al inicio y se PURGA como paso final (dm_pepper_purgar).
Rem Dos esquemas a la vez = dos ejecuciones = dos peppers independientes.
Rem ================================================================================

set serveroutput on size unlimited
set linesize 220
set pagesize 200

Rem ================================================================================
Rem 0) INSTALACION (una sola vez por entorno)
Rem ================================================================================
Rem   @@99_install_datamasking.sql
Rem SYS concede dentro de 99: grant execute on SYS.DBMS_CRYPTO to ASTSYSADMIN;
Rem El pepper NO se crea aqui: nace y muere con cada campana (pasos 4 y 8).
Rem
Rem Sinonimos privados por cada DBA (conectado con su propio usuario):
Rem   @crear_sinonimos <USUARIO>

Rem ================================================================================
Rem 1) DESCUBRIMIENTO  (crea la ejecucion y clasifica columnas PII)
Rem ================================================================================
Rem   @dm_descubre <ESQUEMA>        -> modo default (sample 500)
Rem   @dm_descubre <ESQUEMA> Y      -> forzar full
Rem   @dm_descubre <ESQUEMA> 200    -> sample_rows = 200 (10..500)
Rem El script imprime el EJECUCION_ID generado. Anotalo como <EJEC>.

Rem --- Si necesitas recuperar el ejecucion_id mas reciente del esquema ---
column esquema_objetivo format a25
select ejecucion_id, esquema_objetivo, fase_proceso, estado, fecha_inicio
from   astsysadmin.tdm_ejecucion
where  esquema_objetivo = '<ESQUEMA>'
order  by ejecucion_id desc;

Rem ================================================================================
Rem 2) REVISION DE LA CLASIFICACION
Rem ================================================================================
Rem Consolidado por esquema (lo que se enmascarara):
column owner_name format a18
column table_name format a28
column column_name format a28
column identificador format a26
select owner_name, table_name, column_name, identificador, enmascarar
from   astsysadmin.tdm_columna_final
where  owner_name = '<ESQUEMA>'
order  by table_name, column_name;
Rem (El detalle por ejecucion esta en tdm_columna_hist WHERE ejecucion_id = <EJEC>.)
Rem
Rem Exportar la clasificacion a CSV (opcional):
Rem   @dm_exportcsv <RUTA> <ESQUEMA>

Rem ================================================================================
Rem 3) EXCEPCIONES (opcional): forzar/excluir columnas antes de enmascarar
Rem ================================================================================
Rem   @@97_configurar_excepciones.sql
Rem IMPORTANTE (integridad referencial): toda columna que participe en una FK debe
Rem llevar identificador BIYECTIVO (IDENTIDAD/DOCUMENTO/BANCARIO), nunca de texto.
Rem Tras cambiar excepciones, re-propagar dominios FK:
EXEC pkg_dm_descubrimiento.proc_dm_propaga_dominios(p_esquema => '<ESQUEMA>');

Rem ================================================================================
Rem 4) ENMASCARAMIENTO  (genera el pepper 'PEPPER_MASK:<EJEC>' y aplica FF1)
Rem ================================================================================
Rem   @dm_enmascara <EJEC>      -> default
Rem   @dm_enmascara <EJEC> Y    -> reproceso forzado
Rem Solo un identificador (opcional):
Rem   @dm_enmascara_id <EJEC> IDENTIFICADOR_BANCARIO %
Rem   @dm_enmascara_id <EJEC> IDENTIFICADOR_BANCARIO Y
Rem
Rem Internamente: crea el pepper de la campana, deshabilita FK/triggers (PRE),
Rem enmascara (paralelo por ROWID si la tabla supera 100k filas), rehabilita (POST).

Rem ================================================================================
Rem 5) VALIDACION  (KPIs; no necesita el pepper: valida el dato ya enmascarado)
Rem ================================================================================
Rem   @dm_validar_flujo <ESQUEMA> <EJEC>
Rem KPIs: sin INVALID, dependencias restauradas, sin errores, DNI/NIE e IBAN
Rem validos (mod 23 / mod 97), unicidad sin colisiones (KPI-06) e integridad
Rem referencial sin huerfanos (KPI-08). Con FF1 los numericos son biyectivos:
Rem KPI-04/05/06 deben quedar en OK.
Rem
Rem Prueba puntual de biyeccion de un dominio (total = distintos => sin colisiones):
select count(*) total, count(distinct pkg_dm_func_mask.func_nif(dni)) distintos
from ( select lpad(level,8,'0')||'Z' dni from dual connect by level <= 100000 );

Rem ================================================================================
Rem 6) EXPORT del dump enmascarado (dato ya enmascarado; no usa el pepper)
Rem ================================================================================
EXEC pkg_dm_enmascarar.p_export_mask(p_esquema => '<ESQUEMA>', p_directorio => '<DIR_ORACLE>', p_dumpfile => '<ARCHIVO>.dmp', p_alcance => 'S', p_logfile => '<ARCHIVO>.log', p_ejecucion_id => <EJEC>);

Rem ================================================================================
Rem 7) RECOMPILAR (si quedaron objetos INVALID en el esquema)
Rem ================================================================================
Rem   @dm_recompilar <ESQUEMA>

Rem ================================================================================
Rem 8) PURGA DEL PEPPER  (PASO FINAL, tras validar y exportar)
Rem ================================================================================
Rem   @dm_pepper_purgar <EJEC>
Rem Borra 'PEPPER_MASK:<EJEC>'. A partir de aqui el dato enmascarado no es
Rem reversible (la unica vuelta atras es reimportar el dump de PRO).

Rem ================================================================================
Rem 9) CONCURRENCIA: DOS ESQUEMAS A LA VEZ
Rem ================================================================================
Rem   Sesion A:  @dm_descubre ESQ_A  -> EJEC_A  -> @dm_enmascara EJEC_A  -> @dm_pepper_purgar EJEC_A
Rem   Sesion B:  @dm_descubre ESQ_B  -> EJEC_B  -> @dm_enmascara EJEC_B  -> @dm_pepper_purgar EJEC_B
Rem Cada ejecucion tiene su pepper: sin carrera ni purga cruzada.
Rem INVARIANTE: dos esquemas con FK ENTRE SI deben ir en la MISMA ejecucion.

Rem ================================================================================
Rem 10) CANCELAR / REANUDAR / DESINSTALAR
Rem ================================================================================
Rem Cancelar descubrimiento:  EXEC pkg_dm_descubrimiento.p_dm_cancelar(<EJEC>);
Rem Cancelar enmascaramiento: EXEC pkg_dm_enmascarar.p_mask_cancelar(<EJEC>);
Rem Reanudar enmascaramiento: EXEC pkg_dm_enmascarar.p_mask_reanudar(<EJEC>, 1000);
Rem   (el resume conserva el mismo 'PEPPER_MASK:<EJEC>' por ser idempotente)
Rem Desinstalar todo:         @@98_uninstall.sql
