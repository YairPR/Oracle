programa2.sh

SCRIPT=RES_PROD_202002
FECHA=`date +%y%m%d%H%M%S`
ARCHIVO=log_${SCRIPT}_${FECHA}
CIERRELOG=./logs/${ARCHIVO}.log


echo " " > $CIERRELOG
echo " " >> $CIERRELOG
echo "****************************************************************************" >> $CIERRELOG
echo "Inicio: `date +%Y-%m-%d@%H:%M:%S`" >> $CIERRELOG
echo "****************************************************************************" >> $CIERRELOG

sqlplus -S  mantenimiento/mn2013mn << FIN >> $CIERRELOG

DECLARE

  PROCEDURE terminar_pcd
  (
    p_cfproc  res_prod.fproc%TYPE,
    p_nidelog res_prod_log.idelog%TYPE
  ) IS
    nlimitebulk NUMBER;
    ncontarray  NUMBER := 0;
    --
    CURSOR c_data IS
      SELECT ROWID,
             idefact
      FROM   acselx.res_prod rp
      WHERE  rp.fproc = p_cfproc
      AND    rp.rep = rp.rep || '' --<RTC-213337> Claudia Yugar / 11-09-2019 / Mejoras al proceso de cálculo de la PCD
      AND    rp.tipoproc = 'PRC';
    --
    TYPE t_data IS TABLE OF c_data%ROWTYPE INDEX BY PLS_INTEGER;
    r_data t_data;
    --
  BEGIN
    nlimitebulk := to_number(pr.busca_lval('VALCNFBC', 'LIMITEBULK'));
    --
    dbms_application_info.set_module('TERMINAR_PCD: ' || to_char(SYSDATE, 'dd/mm/yy hh24:mi:ss'), '');
    r_data.DELETE;
    OPEN c_data;
    LOOP
      FETCH c_data BULK COLLECT
        INTO r_data LIMIT nlimitebulk;
      EXIT WHEN r_data.COUNT = 0;
      --
      FOR i IN 1 .. r_data.COUNT
      LOOP
        BEGIN
          UPDATE res_prod p SET p.tipoproc = 'PEN' WHERE p.ROWID = r_data(i).ROWID;
          --
          ncontarray := ncontarray + 1;
          dbms_application_info.set_module('TERMINAR_PCD: ' || ncontarray, '');
        EXCEPTION
          WHEN OTHERS THEN
            pr_res_prod.registrar_log_hijo(p_cfproc, 'TERMINAR_PCD', p_nidelog, 'ERR', 'IDEFACT', r_data(i).idefact, NULL, substr(SQLERRM, 1, 4000));
        END;
      END LOOP;
      COMMIT;
      --
      r_data.DELETE;
    END LOOP;
    COMMIT;
    CLOSE c_data;
    dbms_session.free_unused_user_memory;
  END terminar_pcd;
    
  PROCEDURE iniciar_pcd
  (
    p_cfproc  res_prod.fproc%TYPE,
    p_nidelog res_prod_log.idelog%TYPE
  ) IS
    nlimitebulk NUMBER;
    ncontarray  NUMBER := 0;
    --
    CURSOR c_data IS
      SELECT ROWID
      FROM   acselx.res_prod rp
      WHERE  rp.fproc = p_cfproc
      AND    rp.rep = rp.rep || '' --<RTC-213337> Claudia Yugar / 11-09-2019 / Mejoras al proceso de cálculo de la PCD
      AND    EXISTS (SELECT 1
              FROM   lval
              WHERE  tipolval = 'CONFPCD'
              AND    codlval LIKE 'TIPOPROC%'
              AND    rp.tipoproc = descrip);
    --
    TYPE t_rowid IS TABLE OF ROWID INDEX BY PLS_INTEGER;
    varrayrowid t_rowid;
    --
  BEGIN
    nlimitebulk := to_number(pr.busca_lval('VALCNFBC', 'LIMITEBULK'));
    --
    DECLARE
      ndia NUMBER;
    BEGIN
      IF pr.busca_lval('CONFPCD', 'SWINICIOMANUAL') = 'S' THEN
        -- Toma lo que está configurado
        NULL;
      ELSE
        --<I RTC-235282> Claudia Yugar / 28-01-2020 / Nuevos Cálculos de PCD Seguros
        --SELECT to_number(to_char(SYSDATE, 'D')) INTO ndia FROM dual;
        SELECT DECODE(to_number(to_char(SYSDATE, 'DD')),1,1,to_number(to_char(SYSDATE, 'D'))) INTO ndia FROM dual;
        --<F RTC-235282>
        --
        DELETE FROM lval
        WHERE  tipolval = 'CONFPCD'
        AND    codlval LIKE 'TIPOPROC%';
        --
        IF ndia IN (1, 7) THEN
          INSERT INTO lval (tipolval, codlval, descrip) VALUES ('CONFPCD', 'TIPOPROC01', 'PEN');
          INSERT INTO lval (tipolval, codlval, descrip) VALUES ('CONFPCD', 'TIPOPROC02', 'PRC');
        ELSE
          INSERT INTO lval (tipolval, codlval, descrip) VALUES ('CONFPCD', 'TIPOPROC02', 'PRC');
        END IF;
        --
        COMMIT;
      END IF;
    EXCEPTION
      WHEN OTHERS THEN
        raise_application_error(-20101, 'Error al configurar el inicio del Proceso de PCD');
    END;
    --
    dbms_application_info.set_module('INICIAR_PCD: ' || to_char(SYSDATE, 'dd/mm/yy hh24:mi:ss'), '');
    ncontarray := 0;
    varrayrowid.DELETE;
    OPEN c_data;
    LOOP
      FETCH c_data BULK COLLECT
        INTO varrayrowid LIMIT nlimitebulk;
      EXIT WHEN varrayrowid.COUNT = 0;
      BEGIN
        FORALL i IN 1 .. varrayrowid.COUNT
          UPDATE res_prod p
          SET    p.fecconv          = (SELECT fc.fecconvpago FROM factura_conv fc WHERE fc.idefact = p.idefact),
                 p.porc_prov        = 0,
                 p.ind_vigvencida   = 'N',
                 p.ind_transporte   = 'N',
                 p.inddif           = 'N',
                 p.mtodif           = 0, --<RTC-151701> Julio Ames - 25/09/2018 - RQ CORRECTIVO
                 p.mtolib           = 0, --<RTC-151701> Julio Ames - 25/09/2018 - RQ CORRECTIVO
                 p.indcnt           = 'N',
                 p.indestado        = 'N',
                 p.indajuste        = 'N',
                 p.indws            = 'N',
                 p.ind_burning_cost = 'N',
                 p.ind_msvo         = 'N',--<RTC-235282> Claudia Yugar / 28-01-2020 / Nuevos Cálculos de PCD Seguros
                 p.ind_provision    = NULL,
                 p.fecinivig_pol    = NULL,
                 p.tipoproc         = 'PRC'
          WHERE  p.ROWID = varrayrowid(i);
        --
        ncontarray := ncontarray + varrayrowid.COUNT;
        dbms_application_info.set_module('INICIAR_PCD: ' || ncontarray, '');
      EXCEPTION
        WHEN OTHERS THEN
          pr_res_prod.registrar_log_hijo(p_cfproc, 'INICIAR_PCD', p_nidelog, 'ERR', 'CURSOR', NULL, NULL, substr(SQLERRM, 1, 4000));
      END;
      COMMIT;
      varrayrowid.DELETE;
    END LOOP;
    CLOSE c_data;
    dbms_session.free_unused_user_memory;
    --
  END iniciar_pcd;
    
  PROCEDURE principal(p_cfproc res_prod.fproc%TYPE) IS
    --
    cind            NUMBER;
    log_proceso     NUMBER;
    log_proceso_pcd NUMBER;
    fecini_pcd      DATE;
    csqlerrm        VARCHAR2(4000);
    --cindnuevoperiodo VARCHAR2(1); --<RTC-121141> Julio Ames - 19/03/2017 - Reporte de emisiones diarias de documentos en provisión
    --
    --
  BEGIN
    --
    fecini_pcd := SYSDATE;
    --
    UPDATE lval
    SET    descrip = 'N'
    WHERE  tipolval = 'CONFPCD'
    AND    codlval = 'SWCANCEL';
    COMMIT;
    --
    --<I RTC-121141> Julio Ames - 19/03/2017 - Reporte de emisiones diarias de documentos en provisión
    /*log_proceso := pr_res_prod.log_proceso_ini(p_cfproc, 'PR_RES_PROD.ACT_PENDIENTE_PCD');
    log_proceso_pcd := log_proceso; --<RTC-141115> Julio Ames - 28/06/2018 - CORRECTIVO - Cierre Mensual PCD
    act_pendiente_pcd(p_cfproc);
    pr_res_prod.log_proceso_fin(log_proceso, NULL);
    IF pr.busca_lval('CONFPCD', 'SWCANCEL') = 'S' THEN
      raise_application_error(-20101, 'Usuario ha cancelado el proceso');
    END IF;*/
    --
    /*log_proceso := pr_res_prod.log_proceso_ini(p_cfproc, 'PR_RES_PROD.LIQUIDACIONES_EMITIDAS');
    pr_res_prod.cargar_liquidaciones_emitidas(p_cfproc, 0);
    pr_res_prod.lq_emitidas_rrgg(p_cfproc, 0);
    pr_res_prod.lq_emitidas_vida(p_cfproc, 0);
    pr_res_prod.log_proceso_fin(log_proceso, NULL);
    IF pr.busca_lval('CONFPCD', 'SWCANCEL') = 'S' THEN
      raise_application_error(-20101, 'Usuario ha cancelado el proceso');
    END IF;
    --
    log_proceso := pr_res_prod.log_proceso_ini(p_cfproc, 'PR_RES_PROD.FACTURAS_PENDIENTES');
    pr_res_prod.cargar_facturas_emitidas(p_cfproc, log_proceso);
    pr_res_prod.facturas_emitidas(p_cfproc, log_proceso);
    pr_res_prod.log_proceso_fin(log_proceso, NULL);
    IF pr.busca_lval('CONFPCD', 'SWCANCEL') = 'S' THEN
      raise_application_error(-20101, 'Usuario ha cancelado el proceso');
    END IF;
    --
    log_proceso := pr_res_prod.log_proceso_ini(p_cfproc, 'PR_RES_PROD.LETRA_PENDIENTE');
    pr_res_prod.letra_pendiente(p_cfproc, cind);
    pr_res_prod.log_proceso_fin(log_proceso, NULL);
    IF pr.busca_lval('CONFPCD', 'SWCANCEL') = 'S' THEN
      raise_application_error(-20101, 'Usuario ha cancelado el proceso');
    END IF;
    --
    log_proceso := pr_res_prod.log_proceso_ini(p_cfproc, 'PR_RES_PROD.LETRA_MOROSA');
    pr_res_prod.letra_morosa(p_cfproc, cind);
    pr_res_prod.log_proceso_fin(log_proceso, NULL);
    IF pr.busca_lval('CONFPCD', 'SWCANCEL') = 'S' THEN
      raise_application_error(-20101, 'Usuario ha cancelado el proceso');
    END IF;
    --
    log_proceso := pr_res_prod.log_proceso_ini(p_cfproc, 'PR_RES_PROD.ACTUALIZA_CODPROD');
    pr_res_prod.actualiza_codprod(p_cfproc);
    pr_res_prod.log_proceso_fin(log_proceso, NULL);
    IF pr.busca_lval('CONFPCD', 'SWCANCEL') = 'S' THEN
      raise_application_error(-20101, 'Usuario ha cancelado el proceso');
    END IF;*/
    --
    --
    log_proceso := pr_res_prod.log_proceso_ini(p_cfproc, 'PR_RES_PROD.INICIAR_PCD');
    iniciar_pcd(p_cfproc, log_proceso);
    pr_res_prod.log_proceso_fin(log_proceso, NULL);
    IF pr.busca_lval('CONFPCD', 'SWCANCEL') = 'S' THEN
      raise_application_error(-20101, 'Usuario ha cancelado el proceso');
    END IF;
    --
    log_proceso := pr_res_prod.log_proceso_ini(p_cfproc, 'PR_RES_PROD.PR_ACTUALIZA_POLIZA_DWH');
    pr_res_prod.pr_actualiza_poliza_dwh;
    pr_res_prod.log_proceso_fin(log_proceso, NULL);
    IF pr.busca_lval('CONFPCD', 'SWCANCEL') = 'S' THEN
      raise_application_error(-20101, 'Usuario ha cancelado el proceso');
    END IF;
    --
    log_proceso := pr_res_prod.log_proceso_ini(p_cfproc, 'PR_RES_PROD.PR_CALC_FECCONV_DOC');
    pr_res_prod.pr_calc_fecconv_doc(NULL, last_day(to_date(p_cfproc || '01', 'RRRRMMDD')), log_proceso); --pr_calc_fecconv_doc(NULL, SYSDATE, log_proceso); --<RTC-141115> Julio Ames - 05/06/2018 - CORRECTIVO - Cierre Mensual PCD
    pr_res_prod.log_proceso_fin(log_proceso, NULL);
    IF pr.busca_lval('CONFPCD', 'SWCANCEL') = 'S' THEN
      raise_application_error(-20101, 'Usuario ha cancelado el proceso');
    END IF;
    --
    log_proceso := pr_res_prod.log_proceso_ini(p_cfproc, 'PR_RES_PROD.ACTUALIZAR_FECCONV');
    pr_res_prod.actualizar_fecconv(p_cfproc, p_cfproc, log_proceso);
    pr_res_prod.log_proceso_fin(log_proceso, NULL);
    IF pr.busca_lval('CONFPCD', 'SWCANCEL') = 'S' THEN
      raise_application_error(-20101, 'Usuario ha cancelado el proceso');
    END IF;
    --
    log_proceso := pr_res_prod.log_proceso_ini(p_cfproc, 'PR_RES_PROD.ACTUALIZAR_VIGENCIA');
    pr_res_prod.actualizar_vigencia(p_cfproc, log_proceso);
    pr_res_prod.log_proceso_fin(log_proceso, NULL);
    IF pr.busca_lval('CONFPCD', 'SWCANCEL') = 'S' THEN
      raise_application_error(-20101, 'Usuario ha cancelado el proceso');
    END IF;
    --
    log_proceso := pr_res_prod.log_proceso_ini(p_cfproc, 'PR_RES_PROD.ACTUALIZAR_TRANSPORTE');
    pr_res_prod.actualizar_transporte(p_cfproc, log_proceso);
    pr_res_prod.log_proceso_fin(log_proceso, NULL);
    IF pr.busca_lval('CONFPCD', 'SWCANCEL') = 'S' THEN
      raise_application_error(-20101, 'Usuario ha cancelado el proceso');
    END IF;
    --
    log_proceso := pr_res_prod.log_proceso_ini(p_cfproc, 'PR_RES_PROD.ACTUALIZAR_DIFERIDO');
    pr_res_prod.actualizar_diferido(p_cfproc, log_proceso);
    pr_res_prod.log_proceso_fin(log_proceso, NULL);
    IF pr.busca_lval('CONFPCD', 'SWCANCEL') = 'S' THEN
      raise_application_error(-20101, 'Usuario ha cancelado el proceso');
    END IF;
    --
    log_proceso := pr_res_prod.log_proceso_ini(p_cfproc, 'PR_RES_PROD.ACTUALIZAR_CNT');
    pr_res_prod.actualizar_cnt(p_cfproc, log_proceso);
    pr_res_prod.log_proceso_fin(log_proceso, NULL);
    IF pr.busca_lval('CONFPCD', 'SWCANCEL') = 'S' THEN
      raise_application_error(-20101, 'Usuario ha cancelado el proceso');
    END IF;
    --
    log_proceso := pr_res_prod.log_proceso_ini(p_cfproc, 'PR_RES_PROD.ACTUALIZAR_ESTADO');
    pr_res_prod.actualizar_estado(p_cfproc, log_proceso);
    pr_res_prod.log_proceso_fin(log_proceso, NULL);
    IF pr.busca_lval('CONFPCD', 'SWCANCEL') = 'S' THEN
      raise_application_error(-20101, 'Usuario ha cancelado el proceso');
    END IF;
    --
    log_proceso := pr_res_prod.log_proceso_ini(p_cfproc, 'PR_RES_PROD.ACTUALIZAR_INDAJUSTE');
    pr_res_prod.actualizar_indajuste(p_cfproc, log_proceso);
    pr_res_prod.log_proceso_fin(log_proceso, NULL);
    IF pr.busca_lval('CONFPCD', 'SWCANCEL') = 'S' THEN
      raise_application_error(-20101, 'Usuario ha cancelado el proceso');
    END IF;
    --
    log_proceso := pr_res_prod.log_proceso_ini(p_cfproc, 'PR_RES_PROD.ACTUALIZAR_WS');
    pr_res_prod.actualizar_ws(p_cfproc, log_proceso);
    pr_res_prod.log_proceso_fin(log_proceso, NULL);
    IF pr.busca_lval('CONFPCD', 'SWCANCEL') = 'S' THEN
      raise_application_error(-20101, 'Usuario ha cancelado el proceso');
    END IF;
    --
    log_proceso := pr_res_prod.log_proceso_ini(p_cfproc, 'PR_RES_PROD.ACTUALIZAR_BC');
    pr_res_prod.actualizar_bc(p_cfproc, log_proceso);
    pr_res_prod.log_proceso_fin(log_proceso, NULL);
    IF pr.busca_lval('CONFPCD', 'SWCANCEL') = 'S' THEN
      raise_application_error(-20101, 'Usuario ha cancelado el proceso');
    END IF;
    --
    -- Retirar documentos de provision
    log_proceso := pr_res_prod.log_proceso_ini(p_cfproc, 'PR_RES_PROD.PCD_RETIRAR_DOC');
    pr_res_prod.pcd_retirar_doc(p_cfproc);
    pr_res_prod.log_proceso_fin(log_proceso, NULL);
    IF pr.busca_lval('CONFPCD', 'SWCANCEL') = 'S' THEN
      raise_application_error(-20101, 'Usuario ha cancelado el proceso');
    END IF;
    --
    -- Calculo de la PCD
    log_proceso := pr_res_prod.log_proceso_ini(p_cfproc, 'PR_RES_PROD.CALCULA_PCD');
    pr_res_prod.calcula_pcd(p_cfproc, p_cfproc, log_proceso);
    pr_res_prod.log_proceso_fin(log_proceso, NULL);
    IF pr.busca_lval('CONFPCD', 'SWCANCEL') = 'S' THEN
      raise_application_error(-20101, 'Usuario ha cancelado el proceso');
    END IF;
    --
    log_proceso := pr_res_prod.log_proceso_ini(p_cfproc, 'PR_RES_PROD.CARGAR_DATA_PROV_COBR_DUD');
    pr_res_prod.cargar_data_prov_cobr_dud(p_cfproc, p_cfproc);
    pr_res_prod.log_proceso_fin(log_proceso, NULL);
    --
    log_proceso := pr_res_prod.log_proceso_ini(p_cfproc, 'PR_RES_PROD.TERMINAR_PCD');
    terminar_pcd(p_cfproc, log_proceso);
    pr_res_prod.log_proceso_fin(log_proceso, NULL);
    --
    COMMIT;
    --
    IF pr.busca_lval('CONFPCD', 'SWENVCOR') = 'S' THEN
      -- Envía Montos de Provision
      pr_res_prod.envio_inf_pcd(p_cfproc);
      -- Solicita ejecutar el Datastage
      pr_res_prod.envio_correo_pcd(log_proceso_pcd, fecini_pcd, SYSDATE, 'MAILPCD');
      --
    END IF;
    --
  EXCEPTION
    WHEN OTHERS THEN
      csqlerrm := SQLERRM;
      ROLLBACK;
      pr_res_prod.log_proceso_fin(log_proceso, csqlerrm);
      pr_res_prod.envio_correo_error_pcd(log_proceso_pcd, fecini_pcd, SYSDATE, csqlerrm);
      raise_application_error(-20000, 'PRINCIPAL: ' || ' - ' || csqlerrm);
  END principal;

BEGIN

  principal('202002');
  
END;
/

FIN


echo " " >> $CIERRELOG
echo " " >> $CIERRELOG
echo "****************************************************************************" >> $CIERRELOG
echo "Fin: `date +%Y-%m-%d@%H:%M:%S`" >> $CIERRELOG
echo "****************************************************************************" >> $CIERRELOG
