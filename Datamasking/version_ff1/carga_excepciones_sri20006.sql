--------------------------------------------------------------------------------
-- carga_excepciones_sri2006.sql
--------------------------------------------------------------------------------
-- Owner confirmado: SRI2006 (verificado en la corrida real del DBA).
--
-- PASO 1: MATRIZ -- valida en una sola pasada, de solo lectura, contra el
-- diccionario de datos:
--   a) EXISTENCIA de owner+tabla+columna (dba_tab_columns) -- columna ESTADO.
--   b) POBLACION de esa columna (dba_tables.num_rows + dba_tab_columns.num_nulls,
--      es decir la ULTIMA ESTADISTICA recogida por DBMS_STATS, no un COUNT(*)
--      en vivo) -- columnas TOTAL_FILAS_APROX, FILAS_NULL_APROX, PCT_POBLADO_APROX
--      y DIAGNOSTICO.
--
-- Por que se fusiono aqui (hallazgo real, 2026-09-17): un intento anterior de
-- comprobar poblacion iba en un script aparte que hacia "SELECT COUNT(columna)
-- FROM owner.tabla" columna por columna -- eso revienta con ORA-00904 en
-- cuanto UNA sola columna del listado no existe de verdad (paso justo con
-- SRI_IMPORT_INFGESTION_IDENTLIQ.TEXTO), porque una columna inexistente en
-- una sentencia SQL estatica no compila, sin importar que las demas ramas del
-- UNION ALL sean validas. La solucion es no volver a referenciar el NOMBRE de
-- columna en una consulta de datos en vivo: en vez de eso, la poblacion sale
-- del MISMO LEFT JOIN contra dba_tab_columns que ya usa la comprobacion de
-- existencia (columna t.num_nulls) mas dba_tables.num_rows -- son solo
-- metadatos del diccionario, nunca se ejecuta una consulta contra la tabla
-- real, asi que una columna que no existe simplemente sale como NO EXISTE,
-- nunca rompe la sentencia completa.
--
-- LIMITACION A TENER EN CUENTA: num_rows/num_nulls reflejan la ULTIMA vez que
-- se corrio DBMS_STATS sobre esas tablas (columna LAST_ANALYZED, incluida
-- abajo) -- no es un conteo en vivo. Para tablas TMP_* que se truncan y
-- recargan seguido, esta cifra puede estar desactualizada; si necesita el
-- numero exacto de una tabla puntual, un simple
--   SELECT COUNT(*), COUNT(columna) FROM owner.tabla;
-- manual sobre ESA tabla ya validada como existente es seguro (el riesgo de
-- ORA-00904 solo existe cuando se generaliza a las 80 columnas sin filtrar
-- antes por existencia).
--
-- PASO 2: MERGE final hacia tdm_excepcion_col -- igual que antes, con JOIN
-- (no LEFT JOIN) contra dba_tab_columns, asi que solo se graban las columnas
-- que SI existen; el PASO 2 nunca revienta por una columna inexistente ni
-- necesita el PASO 1 para funcionar (son independientes), pero se recomienda
-- revisar el PASO 1 primero y decidir con criterio (por ejemplo, dejar fuera
-- del PASO 2 -- borrando su bloque UNION ALL -- una columna que salga
-- TABLA VACIA o BAJA POBLACION si prefiere no forzarla todavia).
--
-- Identificador asignado por el nombre de columna (mismo criterio ya acordado):
--   *NIF* / *CIF*                        -> IDENTIFICADOR_IDENTIDAD
--   *NOMBRE* / *APENOM* / *RAZON_SOCIAL* -> IDENTIFICADOR_PERSONAL
--   *TEXTO*                              -> IDENTIFICADOR_OBS (se redacta
--       entera; ese campo trae el NIF embebido segun la nota del Excel)
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- PASO 1: MATRIZ de existencia + poblacion (solo lectura, no escribe nada)
--------------------------------------------------------------------------------
SET LINESIZE 220
SET PAGESIZE 100
COLUMN table_name         FORMAT A32
COLUMN column_name        FORMAT A20
COLUMN identificador_forz FORMAT A24
COLUMN estado             FORMAT A12
COLUMN diagnostico        FORMAT A20

SELECT c.owner_name,
       c.table_name,
       c.column_name,
       c.identificador_forz,
       CASE WHEN t.column_name IS NULL THEN 'NO EXISTE' ELSE 'OK' END AS estado,
       dt.num_rows                                                    AS total_filas_aprox,
       t.num_nulls                                                    AS filas_null_aprox,
       CASE WHEN t.column_name IS NULL THEN NULL
            WHEN dt.num_rows IS NULL OR dt.num_rows = 0 THEN NULL
            ELSE ROUND((dt.num_rows - NVL(t.num_nulls,0)) / dt.num_rows * 100, 2)
       END AS pct_poblado_aprox,
       dt.last_analyzed,
       CASE WHEN t.column_name IS NULL                                    THEN 'NO EXISTE'
            WHEN dt.num_rows IS NULL                                      THEN 'SIN ESTADISTICAS'
            WHEN dt.num_rows = 0                                          THEN 'TABLA VACIA'
            WHEN NVL(t.num_nulls,0) >= dt.num_rows                        THEN 'SIN DATOS EN COLUMNA'
            WHEN (dt.num_rows - NVL(t.num_nulls,0)) / dt.num_rows < 0.05   THEN 'BAJA POBLACION'
            ELSE 'OK'
       END AS diagnostico
  FROM (
  SELECT 'SRI2006' owner_name, 'SRI_ACUERDO_COMPENSACION' table_name, 'AC_NIF_CIF' column_name, 'IDENTIFICADOR_IDENTIDAD' identificador_forz FROM dual UNION ALL
  SELECT 'SRI2006' owner_name, 'SRI_APC_ENVIO' table_name, 'DEUDOR_NIF' column_name, 'IDENTIFICADOR_IDENTIDAD' identificador_forz FROM dual UNION ALL
  SELECT 'SRI2006' owner_name, 'SRI_APC_ENVIO' table_name, 'DEUDOR_NOMBRE' column_name, 'IDENTIFICADOR_PERSONAL' identificador_forz FROM dual UNION ALL
  SELECT 'SRI2006' owner_name, 'SRI_CAMBIOS_NIFS_DEUDAS' table_name, 'CN_NIF_VIEJO' column_name, 'IDENTIFICADOR_IDENTIDAD' identificador_forz FROM dual UNION ALL
  SELECT 'SRI2006' owner_name, 'SRI_CAMBIOS_NIFS_DEUDAS' table_name, 'CN_NIF_NUEVO' column_name, 'IDENTIFICADOR_IDENTIDAD' identificador_forz FROM dual UNION ALL
  SELECT 'SRI2006' owner_name, 'SRI_CARTAS_PAGO_DEUDA' table_name, 'CP_NIF' column_name, 'IDENTIFICADOR_IDENTIDAD' identificador_forz FROM dual UNION ALL
  SELECT 'SRI2006' owner_name, 'SRI_CARTAS_PAGO_DEUDA_TRAZA' table_name, 'CP_NIF' column_name, 'IDENTIFICADOR_IDENTIDAD' identificador_forz FROM dual UNION ALL
  SELECT 'SRI2006' owner_name, 'SRI_CARTAS_PAGO_DEUDA2' table_name, 'CP_NIF' column_name, 'IDENTIFICADOR_IDENTIDAD' identificador_forz FROM dual UNION ALL
  SELECT 'SRI2006' owner_name, 'SRI_CERTIFICADOS' table_name, 'CE_NIF' column_name, 'IDENTIFICADOR_IDENTIDAD' identificador_forz FROM dual UNION ALL
  SELECT 'SRI2006' owner_name, 'SRI_CERTIFICADOS' table_name, 'CE_NOMBRE' column_name, 'IDENTIFICADOR_PERSONAL' identificador_forz FROM dual UNION ALL
  SELECT 'SRI2006' owner_name, 'SRI_CERTIFICADOS_CONCURSAL' table_name, 'CC_NIF' column_name, 'IDENTIFICADOR_IDENTIDAD' identificador_forz FROM dual UNION ALL
  SELECT 'SRI2006' owner_name, 'SRI_CERTIFICADOS_CONCURSAL' table_name, 'CC_NOMBRE' column_name, 'IDENTIFICADOR_PERSONAL' identificador_forz FROM dual UNION ALL
  SELECT 'SRI2006' owner_name, 'SRI_CERTIFICADOS_DEUDAS' table_name, 'CD_NIF' column_name, 'IDENTIFICADOR_IDENTIDAD' identificador_forz FROM dual UNION ALL
  SELECT 'SRI2006' owner_name, 'SRI_CERTIFICADOS_REC' table_name, 'CE_NIF' column_name, 'IDENTIFICADOR_IDENTIDAD' identificador_forz FROM dual UNION ALL
  SELECT 'SRI2006' owner_name, 'SRI_CERTIFICADOS_REC' table_name, 'CE_NOMBRE' column_name, 'IDENTIFICADOR_PERSONAL' identificador_forz FROM dual UNION ALL
  SELECT 'SRI2006' owner_name, 'SRI_CERTIFICADOS_TRAZA' table_name, 'CE_NIF' column_name, 'IDENTIFICADOR_IDENTIDAD' identificador_forz FROM dual UNION ALL
  SELECT 'SRI2006' owner_name, 'SRI_CERTIFICADOS_TRAZA' table_name, 'CE_NOMBRE' column_name, 'IDENTIFICADOR_PERSONAL' identificador_forz FROM dual UNION ALL
  SELECT 'SRI2006' owner_name, 'SRI_DEUDAS_DETALLE' table_name, 'DT_NIF' column_name, 'IDENTIFICADOR_IDENTIDAD' identificador_forz FROM dual UNION ALL
  SELECT 'SRI2006' owner_name, 'SRI_DEUDAS_DETALLE_TRAZA' table_name, 'DT_NIF' column_name, 'IDENTIFICADOR_IDENTIDAD' identificador_forz FROM dual UNION ALL
  SELECT 'SRI2006' owner_name, 'SRI_DEVOLUCIONES_IGESTION' table_name, 'DI_NIF_CIF' column_name, 'IDENTIFICADOR_IDENTIDAD' identificador_forz FROM dual UNION ALL
  SELECT 'SRI2006' owner_name, 'SRI_EXTERNA_BACK_GSOLIDARIO' table_name, 'GS_NIF_GARANTE' column_name, 'IDENTIFICADOR_IDENTIDAD' identificador_forz FROM dual UNION ALL
  SELECT 'SRI2006' owner_name, 'SRI_EXTERNA_BACK_LIQUI' table_name, 'LI_NIF_CIF' column_name, 'IDENTIFICADOR_IDENTIDAD' identificador_forz FROM dual UNION ALL
  SELECT 'SRI2006' owner_name, 'SRI_EXTERNA_LINEA' table_name, 'ELGS_NIF_GARANTE01' column_name, 'IDENTIFICADOR_IDENTIDAD' identificador_forz FROM dual UNION ALL
  SELECT 'SRI2006' owner_name, 'SRI_EXTERNA_LINEA' table_name, 'ELGS_NIF_GARANTE02' column_name, 'IDENTIFICADOR_IDENTIDAD' identificador_forz FROM dual UNION ALL
  SELECT 'SRI2006' owner_name, 'SRI_EXTERNA_LINEA' table_name, 'ELGS_NIF_GARANTE03' column_name, 'IDENTIFICADOR_IDENTIDAD' identificador_forz FROM dual UNION ALL
  SELECT 'SRI2006' owner_name, 'SRI_EXTERNA_LINEA' table_name, 'ELGS_NIF_GARANTE04' column_name, 'IDENTIFICADOR_IDENTIDAD' identificador_forz FROM dual UNION ALL
  SELECT 'SRI2006' owner_name, 'SRI_EXTERNA_LINEA' table_name, 'ELGS_NIF_GARANTE05' column_name, 'IDENTIFICADOR_IDENTIDAD' identificador_forz FROM dual UNION ALL
  SELECT 'SRI2006' owner_name, 'SRI_EXTERNA_LINEA' table_name, 'EL_NIF_CIF' column_name, 'IDENTIFICADOR_IDENTIDAD' identificador_forz FROM dual UNION ALL
  SELECT 'SRI2006' owner_name, 'SRI_FACTURA' table_name, 'FA_NIF_CIF' column_name, 'IDENTIFICADOR_IDENTIDAD' identificador_forz FROM dual UNION ALL
  SELECT 'SRI2006' owner_name, 'SRI_FICHERO_INGRESOS' table_name, 'FI_NIF_CIF' column_name, 'IDENTIFICADOR_IDENTIDAD' identificador_forz FROM dual UNION ALL
  SELECT 'SRI2006' owner_name, 'SRI_GARANTIA' table_name, 'GA_NIF_CIF_GARANTE' column_name, 'IDENTIFICADOR_IDENTIDAD' identificador_forz FROM dual UNION ALL
  SELECT 'SRI2006' owner_name, 'SRI_GIROS_N65' table_name, 'GN_NIF' column_name, 'IDENTIFICADOR_IDENTIDAD' identificador_forz FROM dual UNION ALL
  SELECT 'SRI2006' owner_name, 'SRI_IMPORT_INFGESTION_IDENTLIQ' table_name, 'TEXTO' column_name, 'IDENTIFICADOR_OBS' identificador_forz FROM dual UNION ALL
  SELECT 'SRI2006' owner_name, 'SRI_IMPORT_INFGESTION_IDENTLIQ' table_name, 'NIF_DEUDOR' column_name, 'IDENTIFICADOR_IDENTIDAD' identificador_forz FROM dual UNION ALL
  SELECT 'SRI2006' owner_name, 'SRI_IMPORT_INFGESTION_IDENTLIQ' table_name, 'APENOM_DEUDOR' column_name, 'IDENTIFICADOR_PERSONAL' identificador_forz FROM dual UNION ALL
  SELECT 'SRI2006' owner_name, 'SRI_IMPORT_INFGESTION_PENDIENT' table_name, 'TEXTO' column_name, 'IDENTIFICADOR_OBS' identificador_forz FROM dual UNION ALL
  SELECT 'SRI2006' owner_name, 'SRI_IMPORT_INFGESTION_PENDIENT' table_name, 'NIF' column_name, 'IDENTIFICADOR_IDENTIDAD' identificador_forz FROM dual UNION ALL
  SELECT 'SRI2006' owner_name, 'SRI_IMPORT_INFGESTION_PENDIENT' table_name, 'APENOM' column_name, 'IDENTIFICADOR_PERSONAL' identificador_forz FROM dual UNION ALL
  SELECT 'SRI2006' owner_name, 'SRI_IMPORT_LIQUIDACION' table_name, 'TEXTO' column_name, 'IDENTIFICADOR_OBS' identificador_forz FROM dual UNION ALL
  SELECT 'SRI2006' owner_name, 'SRI_IMPORT_LIQUIDACION' table_name, 'NIF_CIF' column_name, 'IDENTIFICADOR_IDENTIDAD' identificador_forz FROM dual UNION ALL
  SELECT 'SRI2006' owner_name, 'SRI_IMPORT_NORMA65' table_name, 'TEXTO' column_name, 'IDENTIFICADOR_OBS' identificador_forz FROM dual UNION ALL
  SELECT 'SRI2006' owner_name, 'SRI_IMPORT_NORMA65' table_name, 'NIF' column_name, 'IDENTIFICADOR_IDENTIDAD' identificador_forz FROM dual UNION ALL
  SELECT 'SRI2006' owner_name, 'SRI_IMPORT_PENDIENTE_GESTION' table_name, 'TEXTO' column_name, 'IDENTIFICADOR_OBS' identificador_forz FROM dual UNION ALL
  SELECT 'SRI2006' owner_name, 'SRI_IMPORT_PENDIENTE_GESTION' table_name, 'NIF' column_name, 'IDENTIFICADOR_IDENTIDAD' identificador_forz FROM dual UNION ALL
  SELECT 'SRI2006' owner_name, 'SRI_IMPORT_PENDIENTE_GESTION' table_name, 'APENOM' column_name, 'IDENTIFICADOR_PERSONAL' identificador_forz FROM dual UNION ALL
  SELECT 'SRI2006' owner_name, 'SRI_INFORME_GESTION' table_name, 'IG_NIF_CIF' column_name, 'IDENTIFICADOR_IDENTIDAD' identificador_forz FROM dual UNION ALL
  SELECT 'SRI2006' owner_name, 'SRI_INGRESOS' table_name, 'IN_NIF_CIF_TERCERO' column_name, 'IDENTIFICADOR_IDENTIDAD' identificador_forz FROM dual UNION ALL
  SELECT 'SRI2006' owner_name, 'SRI_INGRESOS_DEVOLVER' table_name, 'ID_NIF_CIF_TERCERO' column_name, 'IDENTIFICADOR_IDENTIDAD' identificador_forz FROM dual UNION ALL
  SELECT 'SRI2006' owner_name, 'SRI_INGRESOS_PRIMARIOS' table_name, 'IP_NIF_CIF' column_name, 'IDENTIFICADOR_IDENTIDAD' identificador_forz FROM dual UNION ALL
  SELECT 'SRI2006' owner_name, 'SRI_INGRESOS_PRIMARIOS_TRAZA' table_name, 'IP_NIF_CIF' column_name, 'IDENTIFICADOR_IDENTIDAD' identificador_forz FROM dual UNION ALL
  SELECT 'SRI2006' owner_name, 'SRI_INGRESOS_TEMPORALES' table_name, 'IT_NIF' column_name, 'IDENTIFICADOR_IDENTIDAD' identificador_forz FROM dual UNION ALL
  SELECT 'SRI2006' owner_name, 'SRI_INSERTAR_LIQUIDACIONES' table_name, 'IL_NIF_CIF' column_name, 'IDENTIFICADOR_IDENTIDAD' identificador_forz FROM dual UNION ALL
  SELECT 'SRI2006' owner_name, 'SRI_INTERCAMBIO_NIF' table_name, 'IT_NIF_VIEJO' column_name, 'IDENTIFICADOR_IDENTIDAD' identificador_forz FROM dual UNION ALL
  SELECT 'SRI2006' owner_name, 'SRI_INTERCAMBIO_NIF' table_name, 'IT_NIF_NUEVO' column_name, 'IDENTIFICADOR_IDENTIDAD' identificador_forz FROM dual UNION ALL
  SELECT 'SRI2006' owner_name, 'SRI_LIQUIDACION' table_name, 'LI_NIF_CIF' column_name, 'IDENTIFICADOR_IDENTIDAD' identificador_forz FROM dual UNION ALL
  SELECT 'SRI2006' owner_name, 'SRI_LIQUIDACION_BORRAR' table_name, 'LI_NIF_CIF' column_name, 'IDENTIFICADOR_IDENTIDAD' identificador_forz FROM dual UNION ALL
  SELECT 'SRI2006' owner_name, 'SRI_LIQUIDACION_BORRAR2' table_name, 'LI_NIF_CIF' column_name, 'IDENTIFICADOR_IDENTIDAD' identificador_forz FROM dual UNION ALL
  SELECT 'SRI2006' owner_name, 'SRI_LIQUIDACION_TRAZA' table_name, 'LI_NIF_CIF' column_name, 'IDENTIFICADOR_IDENTIDAD' identificador_forz FROM dual UNION ALL
  SELECT 'SRI2006' owner_name, 'SRI_RESOLUCION_COMPENSACION' table_name, 'RS_NIF_CIF' column_name, 'IDENTIFICADOR_IDENTIDAD' identificador_forz FROM dual UNION ALL
  SELECT 'SRI2006' owner_name, 'SRI_TIPO_DEUDOR' table_name, 'TD_NIF_CIF' column_name, 'IDENTIFICADOR_IDENTIDAD' identificador_forz FROM dual UNION ALL
  SELECT 'SRI2006' owner_name, 'TMP_CONSULTA_FRACC' table_name, 'DT_NIF' column_name, 'IDENTIFICADOR_IDENTIDAD' identificador_forz FROM dual UNION ALL
  SELECT 'SRI2006' owner_name, 'TMP_COPIA_INFORME_GESTION' table_name, 'IG_NIF_CIF' column_name, 'IDENTIFICADOR_IDENTIDAD' identificador_forz FROM dual UNION ALL
  SELECT 'SRI2006' owner_name, 'TMP_CRUCE_FRACC' table_name, 'DT_NIF' column_name, 'IDENTIFICADOR_IDENTIDAD' identificador_forz FROM dual UNION ALL
  SELECT 'SRI2006' owner_name, 'TMP_CRUCE_FRACC2' table_name, 'DT_NIF' column_name, 'IDENTIFICADOR_IDENTIDAD' identificador_forz FROM dual UNION ALL
  SELECT 'SRI2006' owner_name, 'TMP_CUADRE_EJERCICIO' table_name, 'LI_NIF_CIF' column_name, 'IDENTIFICADOR_IDENTIDAD' identificador_forz FROM dual UNION ALL
  SELECT 'SRI2006' owner_name, 'TMP_CUADRE_EJERCICIO2' table_name, 'LI_NIF_CIF' column_name, 'IDENTIFICADOR_IDENTIDAD' identificador_forz FROM dual UNION ALL
  SELECT 'SRI2006' owner_name, 'TMP_CUADRE_EJERCICIO3' table_name, 'LI_NIF_CIF' column_name, 'IDENTIFICADOR_IDENTIDAD' identificador_forz FROM dual UNION ALL
  SELECT 'SRI2006' owner_name, 'TMP_GENERACION_INGRESOS_IG' table_name, 'IG_NIF_CIF' column_name, 'IDENTIFICADOR_IDENTIDAD' identificador_forz FROM dual UNION ALL
  SELECT 'SRI2006' owner_name, 'TMP_INGRESOS_PRIMARIOS' table_name, 'IP_NIF_CIF' column_name, 'IDENTIFICADOR_IDENTIDAD' identificador_forz FROM dual UNION ALL
  SELECT 'SRI2006' owner_name, 'TMP_LIQUIDACION_MENSUAL' table_name, 'NIF' column_name, 'IDENTIFICADOR_IDENTIDAD' identificador_forz FROM dual UNION ALL
  SELECT 'SRI2006' owner_name, 'TMP_LIQUIDACION_MENSUAL' table_name, 'RAZON_SOCIAL' column_name, 'IDENTIFICADOR_PERSONAL' identificador_forz FROM dual UNION ALL
  SELECT 'SRI2006' owner_name, 'TMP_LIQUIDACION_MENSUAL_INFGES' table_name, 'NIF' column_name, 'IDENTIFICADOR_IDENTIDAD' identificador_forz FROM dual UNION ALL
  SELECT 'SRI2006' owner_name, 'TMP_LIQUIDACION_MENSUAL_INFGES' table_name, 'RAZON_SOCIAL' column_name, 'IDENTIFICADOR_PERSONAL' identificador_forz FROM dual UNION ALL
  SELECT 'SRI2006' owner_name, 'TMP_NIFS' table_name, 'NIF' column_name, 'IDENTIFICADOR_IDENTIDAD' identificador_forz FROM dual UNION ALL
  SELECT 'SRI2006' owner_name, 'TMP_NIFS_CERTIF' table_name, 'NIF' column_name, 'IDENTIFICADOR_IDENTIDAD' identificador_forz FROM dual UNION ALL
  SELECT 'SRI2006' owner_name, 'tmp_SRI_IMPORT_INFGESTION_IDEN' table_name, 'NIF_DEUDOR' column_name, 'IDENTIFICADOR_IDENTIDAD' identificador_forz FROM dual UNION ALL
  SELECT 'SRI2006' owner_name, 'tmp_SRI_IMPORT_INFGESTION_IDEN' table_name, 'APENOM_DEUDOR' column_name, 'IDENTIFICADOR_PERSONAL' identificador_forz FROM dual UNION ALL
  SELECT 'SRI2006' owner_name, 'TMP_SRI_INFORME_GESTION' table_name, 'IG_NIF_CIF' column_name, 'IDENTIFICADOR_IDENTIDAD' identificador_forz FROM dual UNION ALL
  SELECT 'SRI2006' owner_name, 'tmp_TMP_LIQUIDACION_MENSUAL' table_name, 'NIF' column_name, 'IDENTIFICADOR_IDENTIDAD' identificador_forz FROM dual UNION ALL
  SELECT 'SRI2006' owner_name, 'tmp_TMP_LIQUIDACION_MENSUAL' table_name, 'RAZON_SOCIAL' column_name, 'IDENTIFICADOR_PERSONAL' identificador_forz FROM dual       ) c
  LEFT JOIN dba_tab_columns t
    ON t.owner = c.owner_name AND t.table_name = c.table_name AND t.column_name = c.column_name
  LEFT JOIN dba_tables dt
    ON dt.owner = c.owner_name AND dt.table_name = c.table_name
 ORDER BY CASE WHEN t.column_name IS NULL THEN 0
               WHEN dt.num_rows IS NULL THEN 1
               WHEN dt.num_rows = 0 THEN 2
               WHEN NVL(t.num_nulls,0) >= dt.num_rows THEN 3
               WHEN (dt.num_rows - NVL(t.num_nulls,0)) / dt.num_rows < 0.05 THEN 4
               ELSE 5
          END,
          c.table_name, c.column_name;

--------------------------------------------------------------------------------
-- Revisa ESTADO y DIAGNOSTICO antes de seguir. Filas NO EXISTE quedaran
-- excluidas solas en el PASO 2 (no hace falta tocarlas). Filas TABLA VACIA /
-- SIN DATOS EN COLUMNA / BAJA POBLACION SI se cargaran igual en el PASO 2 tal
-- como estan abajo -- si prefiere no forzar alguna de esas todavia, borre su
-- bloque "SELECT ... FROM dual UNION ALL" correspondiente en el PASO 2 antes
-- de ejecutarlo.
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- PASO 2: MERGE hacia tdm_excepcion_col (mismo estilo que 97_configurar_excepciones.sql)
-- El JOIN (no LEFT JOIN) contra dba_tab_columns filtra automaticamente: solo
-- se graban las filas que SI existen; las NO EXISTE de la matriz de arriba
-- se descartan solas, sin tocar nada a mano.
--------------------------------------------------------------------------------
MERGE INTO tdm_excepcion_col t
USING (
  SELECT c.owner_name, c.table_name, c.column_name,
         'FORCE' accion, c.identificador_forz, c.razon, 'Y' activa
    FROM (
      SELECT 'SRI2006' owner_name, 'SRI_ACUERDO_COMPENSACION' table_name, 'AC_NIF_CIF' column_name, 'IDENTIFICADOR_IDENTIDAD' identificador_forz, 'Documento de identidad segun anexo de campos sensibles' razon FROM dual UNION ALL
      SELECT 'SRI2006' owner_name, 'SRI_APC_ENVIO' table_name, 'DEUDOR_NIF' column_name, 'IDENTIFICADOR_IDENTIDAD' identificador_forz, 'Documento de identidad segun anexo de campos sensibles' razon FROM dual UNION ALL
      SELECT 'SRI2006' owner_name, 'SRI_APC_ENVIO' table_name, 'DEUDOR_NOMBRE' column_name, 'IDENTIFICADOR_PERSONAL' identificador_forz, 'Nombre/razon social de persona segun anexo de campos sensibles' razon FROM dual UNION ALL
      SELECT 'SRI2006' owner_name, 'SRI_CAMBIOS_NIFS_DEUDAS' table_name, 'CN_NIF_VIEJO' column_name, 'IDENTIFICADOR_IDENTIDAD' identificador_forz, 'Documento de identidad segun anexo de campos sensibles' razon FROM dual UNION ALL
      SELECT 'SRI2006' owner_name, 'SRI_CAMBIOS_NIFS_DEUDAS' table_name, 'CN_NIF_NUEVO' column_name, 'IDENTIFICADOR_IDENTIDAD' identificador_forz, 'Documento de identidad segun anexo de campos sensibles' razon FROM dual UNION ALL
      SELECT 'SRI2006' owner_name, 'SRI_CARTAS_PAGO_DEUDA' table_name, 'CP_NIF' column_name, 'IDENTIFICADOR_IDENTIDAD' identificador_forz, 'Documento de identidad segun anexo de campos sensibles' razon FROM dual UNION ALL
      SELECT 'SRI2006' owner_name, 'SRI_CARTAS_PAGO_DEUDA_TRAZA' table_name, 'CP_NIF' column_name, 'IDENTIFICADOR_IDENTIDAD' identificador_forz, 'Documento de identidad segun anexo de campos sensibles' razon FROM dual UNION ALL
      SELECT 'SRI2006' owner_name, 'SRI_CARTAS_PAGO_DEUDA2' table_name, 'CP_NIF' column_name, 'IDENTIFICADOR_IDENTIDAD' identificador_forz, 'Documento de identidad segun anexo de campos sensibles' razon FROM dual UNION ALL
      SELECT 'SRI2006' owner_name, 'SRI_CERTIFICADOS' table_name, 'CE_NIF' column_name, 'IDENTIFICADOR_IDENTIDAD' identificador_forz, 'Documento de identidad segun anexo de campos sensibles' razon FROM dual UNION ALL
      SELECT 'SRI2006' owner_name, 'SRI_CERTIFICADOS' table_name, 'CE_NOMBRE' column_name, 'IDENTIFICADOR_PERSONAL' identificador_forz, 'Nombre/razon social de persona segun anexo de campos sensibles' razon FROM dual UNION ALL
      SELECT 'SRI2006' owner_name, 'SRI_CERTIFICADOS_CONCURSAL' table_name, 'CC_NIF' column_name, 'IDENTIFICADOR_IDENTIDAD' identificador_forz, 'Documento de identidad segun anexo de campos sensibles' razon FROM dual UNION ALL
      SELECT 'SRI2006' owner_name, 'SRI_CERTIFICADOS_CONCURSAL' table_name, 'CC_NOMBRE' column_name, 'IDENTIFICADOR_PERSONAL' identificador_forz, 'Nombre/razon social de persona segun anexo de campos sensibles' razon FROM dual UNION ALL
      SELECT 'SRI2006' owner_name, 'SRI_CERTIFICADOS_DEUDAS' table_name, 'CD_NIF' column_name, 'IDENTIFICADOR_IDENTIDAD' identificador_forz, 'Documento de identidad segun anexo de campos sensibles' razon FROM dual UNION ALL
      SELECT 'SRI2006' owner_name, 'SRI_CERTIFICADOS_REC' table_name, 'CE_NIF' column_name, 'IDENTIFICADOR_IDENTIDAD' identificador_forz, 'Documento de identidad segun anexo de campos sensibles' razon FROM dual UNION ALL
      SELECT 'SRI2006' owner_name, 'SRI_CERTIFICADOS_REC' table_name, 'CE_NOMBRE' column_name, 'IDENTIFICADOR_PERSONAL' identificador_forz, 'Nombre/razon social de persona segun anexo de campos sensibles' razon FROM dual UNION ALL
      SELECT 'SRI2006' owner_name, 'SRI_CERTIFICADOS_TRAZA' table_name, 'CE_NIF' column_name, 'IDENTIFICADOR_IDENTIDAD' identificador_forz, 'Documento de identidad segun anexo de campos sensibles' razon FROM dual UNION ALL
      SELECT 'SRI2006' owner_name, 'SRI_CERTIFICADOS_TRAZA' table_name, 'CE_NOMBRE' column_name, 'IDENTIFICADOR_PERSONAL' identificador_forz, 'Nombre/razon social de persona segun anexo de campos sensibles' razon FROM dual UNION ALL
      SELECT 'SRI2006' owner_name, 'SRI_DEUDAS_DETALLE' table_name, 'DT_NIF' column_name, 'IDENTIFICADOR_IDENTIDAD' identificador_forz, 'Documento de identidad segun anexo de campos sensibles' razon FROM dual UNION ALL
      SELECT 'SRI2006' owner_name, 'SRI_DEUDAS_DETALLE_TRAZA' table_name, 'DT_NIF' column_name, 'IDENTIFICADOR_IDENTIDAD' identificador_forz, 'Documento de identidad segun anexo de campos sensibles' razon FROM dual UNION ALL
      SELECT 'SRI2006' owner_name, 'SRI_DEVOLUCIONES_IGESTION' table_name, 'DI_NIF_CIF' column_name, 'IDENTIFICADOR_IDENTIDAD' identificador_forz, 'Documento de identidad segun anexo de campos sensibles' razon FROM dual UNION ALL
      SELECT 'SRI2006' owner_name, 'SRI_EXTERNA_BACK_GSOLIDARIO' table_name, 'GS_NIF_GARANTE' column_name, 'IDENTIFICADOR_IDENTIDAD' identificador_forz, 'Documento de identidad segun anexo de campos sensibles' razon FROM dual UNION ALL
      SELECT 'SRI2006' owner_name, 'SRI_EXTERNA_BACK_LIQUI' table_name, 'LI_NIF_CIF' column_name, 'IDENTIFICADOR_IDENTIDAD' identificador_forz, 'Documento de identidad segun anexo de campos sensibles' razon FROM dual UNION ALL
      SELECT 'SRI2006' owner_name, 'SRI_EXTERNA_LINEA' table_name, 'ELGS_NIF_GARANTE01' column_name, 'IDENTIFICADOR_IDENTIDAD' identificador_forz, 'Documento de identidad segun anexo de campos sensibles' razon FROM dual UNION ALL
      SELECT 'SRI2006' owner_name, 'SRI_EXTERNA_LINEA' table_name, 'ELGS_NIF_GARANTE02' column_name, 'IDENTIFICADOR_IDENTIDAD' identificador_forz, 'Documento de identidad segun anexo de campos sensibles' razon FROM dual UNION ALL
      SELECT 'SRI2006' owner_name, 'SRI_EXTERNA_LINEA' table_name, 'ELGS_NIF_GARANTE03' column_name, 'IDENTIFICADOR_IDENTIDAD' identificador_forz, 'Documento de identidad segun anexo de campos sensibles' razon FROM dual UNION ALL
      SELECT 'SRI2006' owner_name, 'SRI_EXTERNA_LINEA' table_name, 'ELGS_NIF_GARANTE04' column_name, 'IDENTIFICADOR_IDENTIDAD' identificador_forz, 'Documento de identidad segun anexo de campos sensibles' razon FROM dual UNION ALL
      SELECT 'SRI2006' owner_name, 'SRI_EXTERNA_LINEA' table_name, 'ELGS_NIF_GARANTE05' column_name, 'IDENTIFICADOR_IDENTIDAD' identificador_forz, 'Documento de identidad segun anexo de campos sensibles' razon FROM dual UNION ALL
      SELECT 'SRI2006' owner_name, 'SRI_EXTERNA_LINEA' table_name, 'EL_NIF_CIF' column_name, 'IDENTIFICADOR_IDENTIDAD' identificador_forz, 'Documento de identidad segun anexo de campos sensibles' razon FROM dual UNION ALL
      SELECT 'SRI2006' owner_name, 'SRI_FACTURA' table_name, 'FA_NIF_CIF' column_name, 'IDENTIFICADOR_IDENTIDAD' identificador_forz, 'Documento de identidad segun anexo de campos sensibles' razon FROM dual UNION ALL
      SELECT 'SRI2006' owner_name, 'SRI_FICHERO_INGRESOS' table_name, 'FI_NIF_CIF' column_name, 'IDENTIFICADOR_IDENTIDAD' identificador_forz, 'Documento de identidad segun anexo de campos sensibles' razon FROM dual UNION ALL
      SELECT 'SRI2006' owner_name, 'SRI_GARANTIA' table_name, 'GA_NIF_CIF_GARANTE' column_name, 'IDENTIFICADOR_IDENTIDAD' identificador_forz, 'Documento de identidad segun anexo de campos sensibles' razon FROM dual UNION ALL
      SELECT 'SRI2006' owner_name, 'SRI_GIROS_N65' table_name, 'GN_NIF' column_name, 'IDENTIFICADOR_IDENTIDAD' identificador_forz, 'Documento de identidad segun anexo de campos sensibles' razon FROM dual UNION ALL
      SELECT 'SRI2006' owner_name, 'SRI_IMPORT_INFGESTION_IDENTLIQ' table_name, 'TEXTO' column_name, 'IDENTIFICADOR_OBS' identificador_forz, 'Texto libre que embebe NIF/APENOM segun anexo del DBA; se redacta completa' razon FROM dual UNION ALL
      SELECT 'SRI2006' owner_name, 'SRI_IMPORT_INFGESTION_IDENTLIQ' table_name, 'NIF_DEUDOR' column_name, 'IDENTIFICADOR_IDENTIDAD' identificador_forz, 'Documento de identidad segun anexo de campos sensibles' razon FROM dual UNION ALL
      SELECT 'SRI2006' owner_name, 'SRI_IMPORT_INFGESTION_IDENTLIQ' table_name, 'APENOM_DEUDOR' column_name, 'IDENTIFICADOR_PERSONAL' identificador_forz, 'Nombre/razon social de persona segun anexo de campos sensibles' razon FROM dual UNION ALL
      SELECT 'SRI2006' owner_name, 'SRI_IMPORT_INFGESTION_PENDIENT' table_name, 'TEXTO' column_name, 'IDENTIFICADOR_OBS' identificador_forz, 'Texto libre que embebe NIF/APENOM segun anexo del DBA; se redacta completa' razon FROM dual UNION ALL
      SELECT 'SRI2006' owner_name, 'SRI_IMPORT_INFGESTION_PENDIENT' table_name, 'NIF' column_name, 'IDENTIFICADOR_IDENTIDAD' identificador_forz, 'Documento de identidad segun anexo de campos sensibles' razon FROM dual UNION ALL
      SELECT 'SRI2006' owner_name, 'SRI_IMPORT_INFGESTION_PENDIENT' table_name, 'APENOM' column_name, 'IDENTIFICADOR_PERSONAL' identificador_forz, 'Nombre/razon social de persona segun anexo de campos sensibles' razon FROM dual UNION ALL
      SELECT 'SRI2006' owner_name, 'SRI_IMPORT_LIQUIDACION' table_name, 'TEXTO' column_name, 'IDENTIFICADOR_OBS' identificador_forz, 'Texto libre que embebe NIF/APENOM segun anexo del DBA; se redacta completa' razon FROM dual UNION ALL
      SELECT 'SRI2006' owner_name, 'SRI_IMPORT_LIQUIDACION' table_name, 'NIF_CIF' column_name, 'IDENTIFICADOR_IDENTIDAD' identificador_forz, 'Documento de identidad segun anexo de campos sensibles' razon FROM dual UNION ALL
      SELECT 'SRI2006' owner_name, 'SRI_IMPORT_NORMA65' table_name, 'TEXTO' column_name, 'IDENTIFICADOR_OBS' identificador_forz, 'Texto libre que embebe NIF/APENOM segun anexo del DBA; se redacta completa' razon FROM dual UNION ALL
      SELECT 'SRI2006' owner_name, 'SRI_IMPORT_NORMA65' table_name, 'NIF' column_name, 'IDENTIFICADOR_IDENTIDAD' identificador_forz, 'Documento de identidad segun anexo de campos sensibles' razon FROM dual UNION ALL
      SELECT 'SRI2006' owner_name, 'SRI_IMPORT_PENDIENTE_GESTION' table_name, 'TEXTO' column_name, 'IDENTIFICADOR_OBS' identificador_forz, 'Texto libre que embebe NIF/APENOM segun anexo del DBA; se redacta completa' razon FROM dual UNION ALL
      SELECT 'SRI2006' owner_name, 'SRI_IMPORT_PENDIENTE_GESTION' table_name, 'NIF' column_name, 'IDENTIFICADOR_IDENTIDAD' identificador_forz, 'Documento de identidad segun anexo de campos sensibles' razon FROM dual UNION ALL
      SELECT 'SRI2006' owner_name, 'SRI_IMPORT_PENDIENTE_GESTION' table_name, 'APENOM' column_name, 'IDENTIFICADOR_PERSONAL' identificador_forz, 'Nombre/razon social de persona segun anexo de campos sensibles' razon FROM dual UNION ALL
      SELECT 'SRI2006' owner_name, 'SRI_INFORME_GESTION' table_name, 'IG_NIF_CIF' column_name, 'IDENTIFICADOR_IDENTIDAD' identificador_forz, 'Documento de identidad segun anexo de campos sensibles' razon FROM dual UNION ALL
      SELECT 'SRI2006' owner_name, 'SRI_INGRESOS' table_name, 'IN_NIF_CIF_TERCERO' column_name, 'IDENTIFICADOR_IDENTIDAD' identificador_forz, 'Documento de identidad segun anexo de campos sensibles' razon FROM dual UNION ALL
      SELECT 'SRI2006' owner_name, 'SRI_INGRESOS_DEVOLVER' table_name, 'ID_NIF_CIF_TERCERO' column_name, 'IDENTIFICADOR_IDENTIDAD' identificador_forz, 'Documento de identidad segun anexo de campos sensibles' razon FROM dual UNION ALL
      SELECT 'SRI2006' owner_name, 'SRI_INGRESOS_PRIMARIOS' table_name, 'IP_NIF_CIF' column_name, 'IDENTIFICADOR_IDENTIDAD' identificador_forz, 'Documento de identidad segun anexo de campos sensibles' razon FROM dual UNION ALL
      SELECT 'SRI2006' owner_name, 'SRI_INGRESOS_PRIMARIOS_TRAZA' table_name, 'IP_NIF_CIF' column_name, 'IDENTIFICADOR_IDENTIDAD' identificador_forz, 'Documento de identidad segun anexo de campos sensibles' razon FROM dual UNION ALL
      SELECT 'SRI2006' owner_name, 'SRI_INGRESOS_TEMPORALES' table_name, 'IT_NIF' column_name, 'IDENTIFICADOR_IDENTIDAD' identificador_forz, 'Documento de identidad segun anexo de campos sensibles' razon FROM dual UNION ALL
      SELECT 'SRI2006' owner_name, 'SRI_INSERTAR_LIQUIDACIONES' table_name, 'IL_NIF_CIF' column_name, 'IDENTIFICADOR_IDENTIDAD' identificador_forz, 'Documento de identidad segun anexo de campos sensibles' razon FROM dual UNION ALL
      SELECT 'SRI2006' owner_name, 'SRI_INTERCAMBIO_NIF' table_name, 'IT_NIF_VIEJO' column_name, 'IDENTIFICADOR_IDENTIDAD' identificador_forz, 'Documento de identidad segun anexo de campos sensibles' razon FROM dual UNION ALL
      SELECT 'SRI2006' owner_name, 'SRI_INTERCAMBIO_NIF' table_name, 'IT_NIF_NUEVO' column_name, 'IDENTIFICADOR_IDENTIDAD' identificador_forz, 'Documento de identidad segun anexo de campos sensibles' razon FROM dual UNION ALL
      SELECT 'SRI2006' owner_name, 'SRI_LIQUIDACION' table_name, 'LI_NIF_CIF' column_name, 'IDENTIFICADOR_IDENTIDAD' identificador_forz, 'Documento de identidad segun anexo de campos sensibles' razon FROM dual UNION ALL
      SELECT 'SRI2006' owner_name, 'SRI_LIQUIDACION_BORRAR' table_name, 'LI_NIF_CIF' column_name, 'IDENTIFICADOR_IDENTIDAD' identificador_forz, 'Documento de identidad segun anexo de campos sensibles' razon FROM dual UNION ALL
      SELECT 'SRI2006' owner_name, 'SRI_LIQUIDACION_BORRAR2' table_name, 'LI_NIF_CIF' column_name, 'IDENTIFICADOR_IDENTIDAD' identificador_forz, 'Documento de identidad segun anexo de campos sensibles' razon FROM dual UNION ALL
      SELECT 'SRI2006' owner_name, 'SRI_LIQUIDACION_TRAZA' table_name, 'LI_NIF_CIF' column_name, 'IDENTIFICADOR_IDENTIDAD' identificador_forz, 'Documento de identidad segun anexo de campos sensibles' razon FROM dual UNION ALL
      SELECT 'SRI2006' owner_name, 'SRI_RESOLUCION_COMPENSACION' table_name, 'RS_NIF_CIF' column_name, 'IDENTIFICADOR_IDENTIDAD' identificador_forz, 'Documento de identidad segun anexo de campos sensibles' razon FROM dual UNION ALL
      SELECT 'SRI2006' owner_name, 'SRI_TIPO_DEUDOR' table_name, 'TD_NIF_CIF' column_name, 'IDENTIFICADOR_IDENTIDAD' identificador_forz, 'Documento de identidad segun anexo de campos sensibles' razon FROM dual UNION ALL
      SELECT 'SRI2006' owner_name, 'TMP_CONSULTA_FRACC' table_name, 'DT_NIF' column_name, 'IDENTIFICADOR_IDENTIDAD' identificador_forz, 'Documento de identidad segun anexo de campos sensibles' razon FROM dual UNION ALL
      SELECT 'SRI2006' owner_name, 'TMP_COPIA_INFORME_GESTION' table_name, 'IG_NIF_CIF' column_name, 'IDENTIFICADOR_IDENTIDAD' identificador_forz, 'Documento de identidad segun anexo de campos sensibles' razon FROM dual UNION ALL
      SELECT 'SRI2006' owner_name, 'TMP_CRUCE_FRACC' table_name, 'DT_NIF' column_name, 'IDENTIFICADOR_IDENTIDAD' identificador_forz, 'Documento de identidad segun anexo de campos sensibles' razon FROM dual UNION ALL
      SELECT 'SRI2006' owner_name, 'TMP_CRUCE_FRACC2' table_name, 'DT_NIF' column_name, 'IDENTIFICADOR_IDENTIDAD' identificador_forz, 'Documento de identidad segun anexo de campos sensibles' razon FROM dual UNION ALL
      SELECT 'SRI2006' owner_name, 'TMP_CUADRE_EJERCICIO' table_name, 'LI_NIF_CIF' column_name, 'IDENTIFICADOR_IDENTIDAD' identificador_forz, 'Documento de identidad segun anexo de campos sensibles' razon FROM dual UNION ALL
      SELECT 'SRI2006' owner_name, 'TMP_CUADRE_EJERCICIO2' table_name, 'LI_NIF_CIF' column_name, 'IDENTIFICADOR_IDENTIDAD' identificador_forz, 'Documento de identidad segun anexo de campos sensibles' razon FROM dual UNION ALL
      SELECT 'SRI2006' owner_name, 'TMP_CUADRE_EJERCICIO3' table_name, 'LI_NIF_CIF' column_name, 'IDENTIFICADOR_IDENTIDAD' identificador_forz, 'Documento de identidad segun anexo de campos sensibles' razon FROM dual UNION ALL
      SELECT 'SRI2006' owner_name, 'TMP_GENERACION_INGRESOS_IG' table_name, 'IG_NIF_CIF' column_name, 'IDENTIFICADOR_IDENTIDAD' identificador_forz, 'Documento de identidad segun anexo de campos sensibles' razon FROM dual UNION ALL
      SELECT 'SRI2006' owner_name, 'TMP_INGRESOS_PRIMARIOS' table_name, 'IP_NIF_CIF' column_name, 'IDENTIFICADOR_IDENTIDAD' identificador_forz, 'Documento de identidad segun anexo de campos sensibles' razon FROM dual UNION ALL
      SELECT 'SRI2006' owner_name, 'TMP_LIQUIDACION_MENSUAL' table_name, 'NIF' column_name, 'IDENTIFICADOR_IDENTIDAD' identificador_forz, 'Documento de identidad segun anexo de campos sensibles' razon FROM dual UNION ALL
      SELECT 'SRI2006' owner_name, 'TMP_LIQUIDACION_MENSUAL' table_name, 'RAZON_SOCIAL' column_name, 'IDENTIFICADOR_PERSONAL' identificador_forz, 'Nombre/razon social de persona segun anexo de campos sensibles' razon FROM dual UNION ALL
      SELECT 'SRI2006' owner_name, 'TMP_LIQUIDACION_MENSUAL_INFGES' table_name, 'NIF' column_name, 'IDENTIFICADOR_IDENTIDAD' identificador_forz, 'Documento de identidad segun anexo de campos sensibles' razon FROM dual UNION ALL
      SELECT 'SRI2006' owner_name, 'TMP_LIQUIDACION_MENSUAL_INFGES' table_name, 'RAZON_SOCIAL' column_name, 'IDENTIFICADOR_PERSONAL' identificador_forz, 'Nombre/razon social de persona segun anexo de campos sensibles' razon FROM dual UNION ALL
      SELECT 'SRI2006' owner_name, 'TMP_NIFS' table_name, 'NIF' column_name, 'IDENTIFICADOR_IDENTIDAD' identificador_forz, 'Documento de identidad segun anexo de campos sensibles' razon FROM dual UNION ALL
      SELECT 'SRI2006' owner_name, 'TMP_NIFS_CERTIF' table_name, 'NIF' column_name, 'IDENTIFICADOR_IDENTIDAD' identificador_forz, 'Documento de identidad segun anexo de campos sensibles' razon FROM dual UNION ALL
      SELECT 'SRI2006' owner_name, 'tmp_SRI_IMPORT_INFGESTION_IDEN' table_name, 'NIF_DEUDOR' column_name, 'IDENTIFICADOR_IDENTIDAD' identificador_forz, 'Documento de identidad segun anexo de campos sensibles' razon FROM dual UNION ALL
      SELECT 'SRI2006' owner_name, 'tmp_SRI_IMPORT_INFGESTION_IDEN' table_name, 'APENOM_DEUDOR' column_name, 'IDENTIFICADOR_PERSONAL' identificador_forz, 'Nombre/razon social de persona segun anexo de campos sensibles' razon FROM dual UNION ALL
      SELECT 'SRI2006' owner_name, 'TMP_SRI_INFORME_GESTION' table_name, 'IG_NIF_CIF' column_name, 'IDENTIFICADOR_IDENTIDAD' identificador_forz, 'Documento de identidad segun anexo de campos sensibles' razon FROM dual UNION ALL
      SELECT 'SRI2006' owner_name, 'tmp_TMP_LIQUIDACION_MENSUAL' table_name, 'NIF' column_name, 'IDENTIFICADOR_IDENTIDAD' identificador_forz, 'Documento de identidad segun anexo de campos sensibles' razon FROM dual UNION ALL
      SELECT 'SRI2006' owner_name, 'tmp_TMP_LIQUIDACION_MENSUAL' table_name, 'RAZON_SOCIAL' column_name, 'IDENTIFICADOR_PERSONAL' identificador_forz, 'Nombre/razon social de persona segun anexo de campos sensibles' razon FROM dual         ) c
    JOIN dba_tab_columns d
      ON d.owner = c.owner_name AND d.table_name = c.table_name AND d.column_name = c.column_name
) s
ON (
       t.owner_name  = s.owner_name
   AND t.table_name  = s.table_name
   AND t.column_name = s.column_name
)
WHEN MATCHED THEN
  UPDATE SET
      t.accion             = s.accion,
      t.identificador_forz = s.identificador_forz,
      t.razon              = s.razon,
      t.activa             = s.activa
WHEN NOT MATCHED THEN
  INSERT (
      owner_name, table_name, column_name,
      accion, identificador_forz, razon, activa
  )
  VALUES (
      s.owner_name, s.table_name, s.column_name,
      s.accion, s.identificador_forz, s.razon, s.activa
  );

COMMIT;
