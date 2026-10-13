set define off

Rem ================================================================================
Rem pkg_dm_sql_seguro  --  11_dm_pkg_sql_seguro.sql
Rem ================================================================================
Rem Entrecomillar, normalizar y acotar texto antes de concatenarlo en SQL dinamico.
Rem
Rem    MODIFICADO   (MM/DD/YY)
Rem    epurisaca    10/10/26 - Rutinas movidas desde pkg_dm_enmascarar sin cambiar su logica
Rem    epurisaca    10/12/26 - Se elimina func_dm_csv_item (solo la usaba proc_dm_enmascara_tabla)
Rem ================================================================================

create or replace PACKAGE pkg_dm_sql_seguro AS

  FUNCTION func_dm_norm(p_txt IN VARCHAR2) RETURN VARCHAR2 DETERMINISTIC;

  FUNCTION func_dm_safe_err(p_err IN VARCHAR2) RETURN VARCHAR2 DETERMINISTIC;

  FUNCTION func_dm_safe_name(p_txt IN VARCHAR2) RETURN VARCHAR2 DETERMINISTIC;

  FUNCTION func_dm_qname(p_name IN VARCHAR2) RETURN VARCHAR2;


END pkg_dm_sql_seguro;
/

create or replace PACKAGE BODY pkg_dm_sql_seguro AS



  ------------------------------------------------------------------------------
  -- Helpers seguros
  ------------------------------------------------------------------------------
  ------------------------------------------------------------------------------
  -- [DOC] function func_dm_norm
  -- PROPOSITO    : Normaliza un texto a mayusculas y sin espacios laterales para comparar
  --                identificadores de forma uniforme.
  -- ENTRADAS     : p_txt; retorna UPPER(TRIM(p_txt), DETERMINISTIC).
  -- LEE          : ninguno
  -- ESCRIBE      : ninguno
  -- ERRORES      : ninguno
  -- LLAMADO DESDE: Interno: helper usado por casi todas las unidades del paquete (qname,
  --                expr_gen_sql, apl_col, mask_cat, enmascaramiento, gestiona_tareas, pre_dep,
  --                pepper_purgar, etc.); sin llamadas externas (40_dm_pkg_export tiene su propia
  --                copia).
  ------------------------------------------------------------------------------
  FUNCTION func_dm_norm(p_txt IN VARCHAR2) RETURN VARCHAR2 DETERMINISTIC IS
  BEGIN
    RETURN UPPER(TRIM(p_txt));
  END;


  ------------------------------------------------------------------------------
  -- [DOC] function func_dm_safe_err
  -- PROPOSITO    : Aplana un mensaje de error (quita saltos de linea, lo acota a 1800 caracteres)
  --                para guardarlo en trazas y columnas de error.
  -- ENTRADAS     : p_err; retorna texto de una linea, o SIN_ERROR si es nulo.
  -- LEE          : ninguno
  -- ESCRIBE      : ninguno
  -- ERRORES      : ninguno
  -- LLAMADO DESDE: Interno: proc_dm_enmascaramiento, proc_dm_mask_cat,
  --                proc_dm_apl_col, proc_dm_post_sync, proc_dm_upd_ejec, proc_dm_close_sol_open.
  ------------------------------------------------------------------------------
  FUNCTION func_dm_safe_err(p_err IN VARCHAR2) RETURN VARCHAR2 DETERMINISTIC IS
  BEGIN
    RETURN SUBSTR(REPLACE(REPLACE(NVL(p_err,'SIN_ERROR'), CHR(10), ' '), CHR(13), ' '), 1, 1800);
  END;


  ------------------------------------------------------------------------------
  -- [DOC] function func_dm_safe_name
  -- PROPOSITO    : Devuelve un nombre de objeto acotado a 256 caracteres (o ? si es nulo) para
  --                componer mensajes de traza sin romper longitudes.
  -- ENTRADAS     : p_txt; retorna texto acotado.
  -- LEE          : ninguno
  -- ESCRIBE      : ninguno
  -- ERRORES      : ninguno
  -- LLAMADO DESDE: Interno: proc_dm_pre_dep y proc_dm_post_dep (mensajes de traza).
  ------------------------------------------------------------------------------
  FUNCTION func_dm_safe_name(p_txt IN VARCHAR2) RETURN VARCHAR2 DETERMINISTIC IS
  BEGIN
    RETURN SUBSTR(NVL(TRIM(p_txt), '?'), 1, 256);
  END;


  ------------------------------------------------------------------------------
  -- [DOC] function func_dm_qname
  -- PROPOSITO    : Valida y entrecomilla un identificador SQL con DBMS_ASSERT para poder concatenarlo
  --                con seguridad en SQL dinamico.
  -- ENTRADAS     : p_name; retorna el nombre en mayusculas entre comillas dobles.
  -- LEE          : ninguno
  -- ESCRIBE      : ninguno
  -- ERRORES      : ORA-20060 si el nombre no es un identificador SQL simple valido (cualquier error
  --                de DBMS_ASSERT se convierte a este codigo).
  -- LLAMADO DESDE: Interno: proc_dm_apl_col, proc_dm_ejecuta_update_seguro, proc_dm_post_sync,
  --                proc_dm_pre_dep, proc_dm_post_dep, func_dm_expr_compatible. Otros archivos
  --                (dm_validar_flujo.sql, tests) solo lo citan en comentarios como convencion.
  ------------------------------------------------------------------------------
  FUNCTION func_dm_qname(p_name IN VARCHAR2) RETURN VARCHAR2 IS
  BEGIN
    RETURN DBMS_ASSERT.ENQUOTE_NAME(
             DBMS_ASSERT.SIMPLE_SQL_NAME(func_dm_norm(p_name)),
             FALSE
           );
  EXCEPTION
    WHEN OTHERS THEN
      RAISE_APPLICATION_ERROR(-20060, 'Nombre SQL invalido: '||SUBSTR(NVL(p_name,'NULL'),1,120));
  END;

END pkg_dm_sql_seguro;
/
