declare
  l_filas_tabla number; l_conteo_ok varchar2(1) := 'Y'; l_err varchar2(400);
begin
  dbms_output.put_line('-> SRI2006.SRI_ACUERDO_COMPENSACION (1 columna(s): AC_NIF_CIF)');
  begin
    execute immediate 'SELECT COUNT(*) FROM ' || dbms_assert.enquote_name(:v_esquema,false) || '.' || dbms_assert.enquote_name('SRI_ACUERDO_COMPENSACION',false) into l_filas_tabla;
  exception when others then
    l_conteo_ok := 'N';
    dbms_output.put_line('   AVISO: no se pudo contar filas (' || replace(replace(substr(sqlerrm,1,200),chr(10),' '),chr(13),' ') || '); se intenta enmascarar igual.');
  end;
  if l_conteo_ok = 'Y' and l_filas_tabla = 0 then
    dbms_output.put_line('   OMITIDA: tabla vacia (0 filas) -- no se llamo a p_mask_tab, no se creo ejecucion ad-hoc.');
    :v_vacias_tablas := :v_vacias_tablas + 1; :v_reporte := :v_reporte || rpad('SRI_ACUERDO_COMPENSACION',35) || 'VACIA (0 filas)' || chr(10);
  else
    if l_conteo_ok = 'Y' then dbms_output.put_line('   Filas en tabla: ' || l_filas_tabla); end if;
    begin
      pkg_dm_enmascarar.p_mask_tab(p_esquema => :v_esquema, p_tabla => 'SRI_ACUERDO_COMPENSACION', p_identificador => 'IDENTIFICADOR_IDENTIDAD', p_columna => 'AC_NIF_CIF');
      declare l_ejec_id number; l_filas number; begin
        begin select max(ejecucion_id) into l_ejec_id from tdm_ejecucion where esquema_objetivo = :v_esquema; exception when others then l_ejec_id := null; end;
        l_filas := null;
        if l_ejec_id is not null then
          begin select sum(filas_procesadas) into l_filas from tdm_mask_solicitud where ejecucion_id = l_ejec_id; exception when others then l_filas := null; end;
          if :v_ejec_min is null or l_ejec_id < :v_ejec_min then :v_ejec_min := l_ejec_id; end if;
          if :v_ejec_max is null or l_ejec_id > :v_ejec_max then :v_ejec_max := l_ejec_id; end if;
        end if;
        dbms_output.put_line('   OK  ejecucion_id=' || nvl(to_char(l_ejec_id),'?') || '  filas_procesadas=' || nvl(to_char(l_filas),'?'));
        :v_reporte := :v_reporte || rpad('SRI_ACUERDO_COMPENSACION',35) || 'OK  ejec=' || nvl(to_char(l_ejec_id),'?') || ' filas=' || nvl(to_char(l_filas),'?') || chr(10);
      end;
      :v_ok_tablas := :v_ok_tablas + 1; :v_total_columnas := :v_total_columnas + 1;
    exception when others then
      l_err := replace(replace(substr(sqlerrm,1,300),chr(10),' '),chr(13),' ');
      dbms_output.put_line('   ERROR: ' || l_err);
      :v_reporte := :v_reporte || rpad('SRI_ACUERDO_COMPENSACION',35) || 'ERROR ' || l_err || chr(10);
      :v_err_tablas := :v_err_tablas + 1;
    end;
  end if;
end;
/
declare
  l_filas_tabla number; l_conteo_ok varchar2(1) := 'Y'; l_err varchar2(400);
begin
  dbms_output.put_line('-> SRI2006.SRI_APC_ENVIO (2 columna(s): DEUDOR_NIF,DEUDOR_NOMBRE)');
  begin
    execute immediate 'SELECT COUNT(*) FROM ' || dbms_assert.enquote_name(:v_esquema,false) || '.' || dbms_assert.enquote_name('SRI_APC_ENVIO',false) into l_filas_tabla;
  exception when others then
    l_conteo_ok := 'N';
    dbms_output.put_line('   AVISO: no se pudo contar filas (' || replace(replace(substr(sqlerrm,1,200),chr(10),' '),chr(13),' ') || '); se intenta enmascarar igual.');
  end;
  if l_conteo_ok = 'Y' and l_filas_tabla = 0 then
    dbms_output.put_line('   OMITIDA: tabla vacia (0 filas) -- no se llamo a p_mask_tab, no se creo ejecucion ad-hoc.');
    :v_vacias_tablas := :v_vacias_tablas + 1; :v_reporte := :v_reporte || rpad('SRI_APC_ENVIO',35) || 'VACIA (0 filas)' || chr(10);
  else
    if l_conteo_ok = 'Y' then dbms_output.put_line('   Filas en tabla: ' || l_filas_tabla); end if;
    begin
      pkg_dm_enmascarar.p_mask_tab(p_esquema => :v_esquema, p_tabla => 'SRI_APC_ENVIO', p_identificador => 'IDENTIFICADOR_IDENTIDAD', p_columna => 'DEUDOR_NIF,DEUDOR_NOMBRE');
      declare l_ejec_id number; l_filas number; begin
        begin select max(ejecucion_id) into l_ejec_id from tdm_ejecucion where esquema_objetivo = :v_esquema; exception when others then l_ejec_id := null; end;
        l_filas := null;
        if l_ejec_id is not null then
          begin select sum(filas_procesadas) into l_filas from tdm_mask_solicitud where ejecucion_id = l_ejec_id; exception when others then l_filas := null; end;
          if :v_ejec_min is null or l_ejec_id < :v_ejec_min then :v_ejec_min := l_ejec_id; end if;
          if :v_ejec_max is null or l_ejec_id > :v_ejec_max then :v_ejec_max := l_ejec_id; end if;
        end if;
        dbms_output.put_line('   OK  ejecucion_id=' || nvl(to_char(l_ejec_id),'?') || '  filas_procesadas=' || nvl(to_char(l_filas),'?'));
        :v_reporte := :v_reporte || rpad('SRI_APC_ENVIO',35) || 'OK  ejec=' || nvl(to_char(l_ejec_id),'?') || ' filas=' || nvl(to_char(l_filas),'?') || chr(10);
      end;
      :v_ok_tablas := :v_ok_tablas + 1; :v_total_columnas := :v_total_columnas + 2;
    exception when others then
      l_err := replace(replace(substr(sqlerrm,1,300),chr(10),' '),chr(13),' ');
      dbms_output.put_line('   ERROR: ' || l_err);
      :v_reporte := :v_reporte || rpad('SRI_APC_ENVIO',35) || 'ERROR ' || l_err || chr(10);
      :v_err_tablas := :v_err_tablas + 1;
    end;
  end if;
end;
/
declare
  l_filas_tabla number; l_conteo_ok varchar2(1) := 'Y'; l_err varchar2(400);
begin
  dbms_output.put_line('-> SRI2006.SRI_CAMBIOS_NIFS_DEUDAS (2 columna(s): CN_NIF_NUEVO,CN_NIF_VIEJO)');
  begin
    execute immediate 'SELECT COUNT(*) FROM ' || dbms_assert.enquote_name(:v_esquema,false) || '.' || dbms_assert.enquote_name('SRI_CAMBIOS_NIFS_DEUDAS',false) into l_filas_tabla;
  exception when others then
    l_conteo_ok := 'N';
    dbms_output.put_line('   AVISO: no se pudo contar filas (' || replace(replace(substr(sqlerrm,1,200),chr(10),' '),chr(13),' ') || '); se intenta enmascarar igual.');
  end;
  if l_conteo_ok = 'Y' and l_filas_tabla = 0 then
    dbms_output.put_line('   OMITIDA: tabla vacia (0 filas) -- no se llamo a p_mask_tab, no se creo ejecucion ad-hoc.');
    :v_vacias_tablas := :v_vacias_tablas + 1; :v_reporte := :v_reporte || rpad('SRI_CAMBIOS_NIFS_DEUDAS',35) || 'VACIA (0 filas)' || chr(10);
  else
    if l_conteo_ok = 'Y' then dbms_output.put_line('   Filas en tabla: ' || l_filas_tabla); end if;
    begin
      pkg_dm_enmascarar.p_mask_tab(p_esquema => :v_esquema, p_tabla => 'SRI_CAMBIOS_NIFS_DEUDAS', p_identificador => 'IDENTIFICADOR_IDENTIDAD', p_columna => 'CN_NIF_NUEVO,CN_NIF_VIEJO');
      declare l_ejec_id number; l_filas number; begin
        begin select max(ejecucion_id) into l_ejec_id from tdm_ejecucion where esquema_objetivo = :v_esquema; exception when others then l_ejec_id := null; end;
        l_filas := null;
        if l_ejec_id is not null then
          begin select sum(filas_procesadas) into l_filas from tdm_mask_solicitud where ejecucion_id = l_ejec_id; exception when others then l_filas := null; end;
          if :v_ejec_min is null or l_ejec_id < :v_ejec_min then :v_ejec_min := l_ejec_id; end if;
          if :v_ejec_max is null or l_ejec_id > :v_ejec_max then :v_ejec_max := l_ejec_id; end if;
        end if;
        dbms_output.put_line('   OK  ejecucion_id=' || nvl(to_char(l_ejec_id),'?') || '  filas_procesadas=' || nvl(to_char(l_filas),'?'));
        :v_reporte := :v_reporte || rpad('SRI_CAMBIOS_NIFS_DEUDAS',35) || 'OK  ejec=' || nvl(to_char(l_ejec_id),'?') || ' filas=' || nvl(to_char(l_filas),'?') || chr(10);
      end;
      :v_ok_tablas := :v_ok_tablas + 1; :v_total_columnas := :v_total_columnas + 2;
    exception when others then
      l_err := replace(replace(substr(sqlerrm,1,300),chr(10),' '),chr(13),' ');
      dbms_output.put_line('   ERROR: ' || l_err);
      :v_reporte := :v_reporte || rpad('SRI_CAMBIOS_NIFS_DEUDAS',35) || 'ERROR ' || l_err || chr(10);
      :v_err_tablas := :v_err_tablas + 1;
    end;
  end if;
end;
/
declare
  l_filas_tabla number; l_conteo_ok varchar2(1) := 'Y'; l_err varchar2(400);
begin
  dbms_output.put_line('-> SRI2006.SRI_CARTAS_PAGO_DEUDA (1 columna(s): CP_NIF)');
  begin
    execute immediate 'SELECT COUNT(*) FROM ' || dbms_assert.enquote_name(:v_esquema,false) || '.' || dbms_assert.enquote_name('SRI_CARTAS_PAGO_DEUDA',false) into l_filas_tabla;
  exception when others then
    l_conteo_ok := 'N';
    dbms_output.put_line('   AVISO: no se pudo contar filas (' || replace(replace(substr(sqlerrm,1,200),chr(10),' '),chr(13),' ') || '); se intenta enmascarar igual.');
  end;
  if l_conteo_ok = 'Y' and l_filas_tabla = 0 then
    dbms_output.put_line('   OMITIDA: tabla vacia (0 filas) -- no se llamo a p_mask_tab, no se creo ejecucion ad-hoc.');
    :v_vacias_tablas := :v_vacias_tablas + 1; :v_reporte := :v_reporte || rpad('SRI_CARTAS_PAGO_DEUDA',35) || 'VACIA (0 filas)' || chr(10);
  else
    if l_conteo_ok = 'Y' then dbms_output.put_line('   Filas en tabla: ' || l_filas_tabla); end if;
    begin
      pkg_dm_enmascarar.p_mask_tab(p_esquema => :v_esquema, p_tabla => 'SRI_CARTAS_PAGO_DEUDA', p_identificador => 'IDENTIFICADOR_IDENTIDAD', p_columna => 'CP_NIF');
      declare l_ejec_id number; l_filas number; begin
        begin select max(ejecucion_id) into l_ejec_id from tdm_ejecucion where esquema_objetivo = :v_esquema; exception when others then l_ejec_id := null; end;
        l_filas := null;
        if l_ejec_id is not null then
          begin select sum(filas_procesadas) into l_filas from tdm_mask_solicitud where ejecucion_id = l_ejec_id; exception when others then l_filas := null; end;
          if :v_ejec_min is null or l_ejec_id < :v_ejec_min then :v_ejec_min := l_ejec_id; end if;
          if :v_ejec_max is null or l_ejec_id > :v_ejec_max then :v_ejec_max := l_ejec_id; end if;
        end if;
        dbms_output.put_line('   OK  ejecucion_id=' || nvl(to_char(l_ejec_id),'?') || '  filas_procesadas=' || nvl(to_char(l_filas),'?'));
        :v_reporte := :v_reporte || rpad('SRI_CARTAS_PAGO_DEUDA',35) || 'OK  ejec=' || nvl(to_char(l_ejec_id),'?') || ' filas=' || nvl(to_char(l_filas),'?') || chr(10);
      end;
      :v_ok_tablas := :v_ok_tablas + 1; :v_total_columnas := :v_total_columnas + 1;
    exception when others then
      l_err := replace(replace(substr(sqlerrm,1,300),chr(10),' '),chr(13),' ');
      dbms_output.put_line('   ERROR: ' || l_err);
      :v_reporte := :v_reporte || rpad('SRI_CARTAS_PAGO_DEUDA',35) || 'ERROR ' || l_err || chr(10);
      :v_err_tablas := :v_err_tablas + 1;
    end;
  end if;
end;
/
declare
  l_filas_tabla number; l_conteo_ok varchar2(1) := 'Y'; l_err varchar2(400);
begin
  dbms_output.put_line('-> SRI2006.SRI_CARTAS_PAGO_DEUDA_TRAZA (1 columna(s): CP_NIF)');
  begin
    execute immediate 'SELECT COUNT(*) FROM ' || dbms_assert.enquote_name(:v_esquema,false) || '.' || dbms_assert.enquote_name('SRI_CARTAS_PAGO_DEUDA_TRAZA',false) into l_filas_tabla;
  exception when others then
    l_conteo_ok := 'N';
    dbms_output.put_line('   AVISO: no se pudo contar filas (' || replace(replace(substr(sqlerrm,1,200),chr(10),' '),chr(13),' ') || '); se intenta enmascarar igual.');
  end;
  if l_conteo_ok = 'Y' and l_filas_tabla = 0 then
    dbms_output.put_line('   OMITIDA: tabla vacia (0 filas) -- no se llamo a p_mask_tab, no se creo ejecucion ad-hoc.');
    :v_vacias_tablas := :v_vacias_tablas + 1; :v_reporte := :v_reporte || rpad('SRI_CARTAS_PAGO_DEUDA_TRAZA',35) || 'VACIA (0 filas)' || chr(10);
  else
    if l_conteo_ok = 'Y' then dbms_output.put_line('   Filas en tabla: ' || l_filas_tabla); end if;
    begin
      pkg_dm_enmascarar.p_mask_tab(p_esquema => :v_esquema, p_tabla => 'SRI_CARTAS_PAGO_DEUDA_TRAZA', p_identificador => 'IDENTIFICADOR_IDENTIDAD', p_columna => 'CP_NIF');
      declare l_ejec_id number; l_filas number; begin
        begin select max(ejecucion_id) into l_ejec_id from tdm_ejecucion where esquema_objetivo = :v_esquema; exception when others then l_ejec_id := null; end;
        l_filas := null;
        if l_ejec_id is not null then
          begin select sum(filas_procesadas) into l_filas from tdm_mask_solicitud where ejecucion_id = l_ejec_id; exception when others then l_filas := null; end;
          if :v_ejec_min is null or l_ejec_id < :v_ejec_min then :v_ejec_min := l_ejec_id; end if;
          if :v_ejec_max is null or l_ejec_id > :v_ejec_max then :v_ejec_max := l_ejec_id; end if;
        end if;
        dbms_output.put_line('   OK  ejecucion_id=' || nvl(to_char(l_ejec_id),'?') || '  filas_procesadas=' || nvl(to_char(l_filas),'?'));
        :v_reporte := :v_reporte || rpad('SRI_CARTAS_PAGO_DEUDA_TRAZA',35) || 'OK  ejec=' || nvl(to_char(l_ejec_id),'?') || ' filas=' || nvl(to_char(l_filas),'?') || chr(10);
      end;
      :v_ok_tablas := :v_ok_tablas + 1; :v_total_columnas := :v_total_columnas + 1;
    exception when others then
      l_err := replace(replace(substr(sqlerrm,1,300),chr(10),' '),chr(13),' ');
      dbms_output.put_line('   ERROR: ' || l_err);
      :v_reporte := :v_reporte || rpad('SRI_CARTAS_PAGO_DEUDA_TRAZA',35) || 'ERROR ' || l_err || chr(10);
      :v_err_tablas := :v_err_tablas + 1;
    end;
  end if;
end;
/
declare
  l_filas_tabla number; l_conteo_ok varchar2(1) := 'Y'; l_err varchar2(400);
begin
  dbms_output.put_line('-> SRI2006.SRI_CARTAS_PAGO_DEUDA2 (1 columna(s): CP_NIF)');
  begin
    execute immediate 'SELECT COUNT(*) FROM ' || dbms_assert.enquote_name(:v_esquema,false) || '.' || dbms_assert.enquote_name('SRI_CARTAS_PAGO_DEUDA2',false) into l_filas_tabla;
  exception when others then
    l_conteo_ok := 'N';
    dbms_output.put_line('   AVISO: no se pudo contar filas (' || replace(replace(substr(sqlerrm,1,200),chr(10),' '),chr(13),' ') || '); se intenta enmascarar igual.');
  end;
  if l_conteo_ok = 'Y' and l_filas_tabla = 0 then
    dbms_output.put_line('   OMITIDA: tabla vacia (0 filas) -- no se llamo a p_mask_tab, no se creo ejecucion ad-hoc.');
    :v_vacias_tablas := :v_vacias_tablas + 1; :v_reporte := :v_reporte || rpad('SRI_CARTAS_PAGO_DEUDA2',35) || 'VACIA (0 filas)' || chr(10);
  else
    if l_conteo_ok = 'Y' then dbms_output.put_line('   Filas en tabla: ' || l_filas_tabla); end if;
    begin
      pkg_dm_enmascarar.p_mask_tab(p_esquema => :v_esquema, p_tabla => 'SRI_CARTAS_PAGO_DEUDA2', p_identificador => 'IDENTIFICADOR_IDENTIDAD', p_columna => 'CP_NIF');
      declare l_ejec_id number; l_filas number; begin
        begin select max(ejecucion_id) into l_ejec_id from tdm_ejecucion where esquema_objetivo = :v_esquema; exception when others then l_ejec_id := null; end;
        l_filas := null;
        if l_ejec_id is not null then
          begin select sum(filas_procesadas) into l_filas from tdm_mask_solicitud where ejecucion_id = l_ejec_id; exception when others then l_filas := null; end;
          if :v_ejec_min is null or l_ejec_id < :v_ejec_min then :v_ejec_min := l_ejec_id; end if;
          if :v_ejec_max is null or l_ejec_id > :v_ejec_max then :v_ejec_max := l_ejec_id; end if;
        end if;
        dbms_output.put_line('   OK  ejecucion_id=' || nvl(to_char(l_ejec_id),'?') || '  filas_procesadas=' || nvl(to_char(l_filas),'?'));
        :v_reporte := :v_reporte || rpad('SRI_CARTAS_PAGO_DEUDA2',35) || 'OK  ejec=' || nvl(to_char(l_ejec_id),'?') || ' filas=' || nvl(to_char(l_filas),'?') || chr(10);
      end;
      :v_ok_tablas := :v_ok_tablas + 1; :v_total_columnas := :v_total_columnas + 1;
    exception when others then
      l_err := replace(replace(substr(sqlerrm,1,300),chr(10),' '),chr(13),' ');
      dbms_output.put_line('   ERROR: ' || l_err);
      :v_reporte := :v_reporte || rpad('SRI_CARTAS_PAGO_DEUDA2',35) || 'ERROR ' || l_err || chr(10);
      :v_err_tablas := :v_err_tablas + 1;
    end;
  end if;
end;
/
declare
  l_filas_tabla number; l_conteo_ok varchar2(1) := 'Y'; l_err varchar2(400);
begin
  dbms_output.put_line('-> SRI2006.SRI_CERTIFICADOS (2 columna(s): CE_NIF,CE_NOMBRE)');
  begin
    execute immediate 'SELECT COUNT(*) FROM ' || dbms_assert.enquote_name(:v_esquema,false) || '.' || dbms_assert.enquote_name('SRI_CERTIFICADOS',false) into l_filas_tabla;
  exception when others then
    l_conteo_ok := 'N';
    dbms_output.put_line('   AVISO: no se pudo contar filas (' || replace(replace(substr(sqlerrm,1,200),chr(10),' '),chr(13),' ') || '); se intenta enmascarar igual.');
  end;
  if l_conteo_ok = 'Y' and l_filas_tabla = 0 then
    dbms_output.put_line('   OMITIDA: tabla vacia (0 filas) -- no se llamo a p_mask_tab, no se creo ejecucion ad-hoc.');
    :v_vacias_tablas := :v_vacias_tablas + 1; :v_reporte := :v_reporte || rpad('SRI_CERTIFICADOS',35) || 'VACIA (0 filas)' || chr(10);
  else
    if l_conteo_ok = 'Y' then dbms_output.put_line('   Filas en tabla: ' || l_filas_tabla); end if;
    begin
      pkg_dm_enmascarar.p_mask_tab(p_esquema => :v_esquema, p_tabla => 'SRI_CERTIFICADOS', p_identificador => 'IDENTIFICADOR_IDENTIDAD', p_columna => 'CE_NIF,CE_NOMBRE');
      declare l_ejec_id number; l_filas number; begin
        begin select max(ejecucion_id) into l_ejec_id from tdm_ejecucion where esquema_objetivo = :v_esquema; exception when others then l_ejec_id := null; end;
        l_filas := null;
        if l_ejec_id is not null then
          begin select sum(filas_procesadas) into l_filas from tdm_mask_solicitud where ejecucion_id = l_ejec_id; exception when others then l_filas := null; end;
          if :v_ejec_min is null or l_ejec_id < :v_ejec_min then :v_ejec_min := l_ejec_id; end if;
          if :v_ejec_max is null or l_ejec_id > :v_ejec_max then :v_ejec_max := l_ejec_id; end if;
        end if;
        dbms_output.put_line('   OK  ejecucion_id=' || nvl(to_char(l_ejec_id),'?') || '  filas_procesadas=' || nvl(to_char(l_filas),'?'));
        :v_reporte := :v_reporte || rpad('SRI_CERTIFICADOS',35) || 'OK  ejec=' || nvl(to_char(l_ejec_id),'?') || ' filas=' || nvl(to_char(l_filas),'?') || chr(10);
      end;
      :v_ok_tablas := :v_ok_tablas + 1; :v_total_columnas := :v_total_columnas + 2;
    exception when others then
      l_err := replace(replace(substr(sqlerrm,1,300),chr(10),' '),chr(13),' ');
      dbms_output.put_line('   ERROR: ' || l_err);
      :v_reporte := :v_reporte || rpad('SRI_CERTIFICADOS',35) || 'ERROR ' || l_err || chr(10);
      :v_err_tablas := :v_err_tablas + 1;
    end;
  end if;
end;
/
declare
  l_filas_tabla number; l_conteo_ok varchar2(1) := 'Y'; l_err varchar2(400);
begin
  dbms_output.put_line('-> SRI2006.SRI_CERTIFICADOS_CONCURSAL (2 columna(s): CC_NIF,CC_NOMBRE)');
  begin
    execute immediate 'SELECT COUNT(*) FROM ' || dbms_assert.enquote_name(:v_esquema,false) || '.' || dbms_assert.enquote_name('SRI_CERTIFICADOS_CONCURSAL',false) into l_filas_tabla;
  exception when others then
    l_conteo_ok := 'N';
    dbms_output.put_line('   AVISO: no se pudo contar filas (' || replace(replace(substr(sqlerrm,1,200),chr(10),' '),chr(13),' ') || '); se intenta enmascarar igual.');
  end;
  if l_conteo_ok = 'Y' and l_filas_tabla = 0 then
    dbms_output.put_line('   OMITIDA: tabla vacia (0 filas) -- no se llamo a p_mask_tab, no se creo ejecucion ad-hoc.');
    :v_vacias_tablas := :v_vacias_tablas + 1; :v_reporte := :v_reporte || rpad('SRI_CERTIFICADOS_CONCURSAL',35) || 'VACIA (0 filas)' || chr(10);
  else
    if l_conteo_ok = 'Y' then dbms_output.put_line('   Filas en tabla: ' || l_filas_tabla); end if;
    begin
      pkg_dm_enmascarar.p_mask_tab(p_esquema => :v_esquema, p_tabla => 'SRI_CERTIFICADOS_CONCURSAL', p_identificador => 'IDENTIFICADOR_IDENTIDAD', p_columna => 'CC_NIF,CC_NOMBRE');
      declare l_ejec_id number; l_filas number; begin
        begin select max(ejecucion_id) into l_ejec_id from tdm_ejecucion where esquema_objetivo = :v_esquema; exception when others then l_ejec_id := null; end;
        l_filas := null;
        if l_ejec_id is not null then
          begin select sum(filas_procesadas) into l_filas from tdm_mask_solicitud where ejecucion_id = l_ejec_id; exception when others then l_filas := null; end;
          if :v_ejec_min is null or l_ejec_id < :v_ejec_min then :v_ejec_min := l_ejec_id; end if;
          if :v_ejec_max is null or l_ejec_id > :v_ejec_max then :v_ejec_max := l_ejec_id; end if;
        end if;
        dbms_output.put_line('   OK  ejecucion_id=' || nvl(to_char(l_ejec_id),'?') || '  filas_procesadas=' || nvl(to_char(l_filas),'?'));
        :v_reporte := :v_reporte || rpad('SRI_CERTIFICADOS_CONCURSAL',35) || 'OK  ejec=' || nvl(to_char(l_ejec_id),'?') || ' filas=' || nvl(to_char(l_filas),'?') || chr(10);
      end;
      :v_ok_tablas := :v_ok_tablas + 1; :v_total_columnas := :v_total_columnas + 2;
    exception when others then
      l_err := replace(replace(substr(sqlerrm,1,300),chr(10),' '),chr(13),' ');
      dbms_output.put_line('   ERROR: ' || l_err);
      :v_reporte := :v_reporte || rpad('SRI_CERTIFICADOS_CONCURSAL',35) || 'ERROR ' || l_err || chr(10);
      :v_err_tablas := :v_err_tablas + 1;
    end;
  end if;
end;
/
declare
  l_filas_tabla number; l_conteo_ok varchar2(1) := 'Y'; l_err varchar2(400);
begin
  dbms_output.put_line('-> SRI2006.SRI_CERTIFICADOS_DEUDAS (1 columna(s): CD_NIF)');
  begin
    execute immediate 'SELECT COUNT(*) FROM ' || dbms_assert.enquote_name(:v_esquema,false) || '.' || dbms_assert.enquote_name('SRI_CERTIFICADOS_DEUDAS',false) into l_filas_tabla;
  exception when others then
    l_conteo_ok := 'N';
    dbms_output.put_line('   AVISO: no se pudo contar filas (' || replace(replace(substr(sqlerrm,1,200),chr(10),' '),chr(13),' ') || '); se intenta enmascarar igual.');
  end;
  if l_conteo_ok = 'Y' and l_filas_tabla = 0 then
    dbms_output.put_line('   OMITIDA: tabla vacia (0 filas) -- no se llamo a p_mask_tab, no se creo ejecucion ad-hoc.');
    :v_vacias_tablas := :v_vacias_tablas + 1; :v_reporte := :v_reporte || rpad('SRI_CERTIFICADOS_DEUDAS',35) || 'VACIA (0 filas)' || chr(10);
  else
    if l_conteo_ok = 'Y' then dbms_output.put_line('   Filas en tabla: ' || l_filas_tabla); end if;
    begin
      pkg_dm_enmascarar.p_mask_tab(p_esquema => :v_esquema, p_tabla => 'SRI_CERTIFICADOS_DEUDAS', p_identificador => 'IDENTIFICADOR_IDENTIDAD', p_columna => 'CD_NIF');
      declare l_ejec_id number; l_filas number; begin
        begin select max(ejecucion_id) into l_ejec_id from tdm_ejecucion where esquema_objetivo = :v_esquema; exception when others then l_ejec_id := null; end;
        l_filas := null;
        if l_ejec_id is not null then
          begin select sum(filas_procesadas) into l_filas from tdm_mask_solicitud where ejecucion_id = l_ejec_id; exception when others then l_filas := null; end;
          if :v_ejec_min is null or l_ejec_id < :v_ejec_min then :v_ejec_min := l_ejec_id; end if;
          if :v_ejec_max is null or l_ejec_id > :v_ejec_max then :v_ejec_max := l_ejec_id; end if;
        end if;
        dbms_output.put_line('   OK  ejecucion_id=' || nvl(to_char(l_ejec_id),'?') || '  filas_procesadas=' || nvl(to_char(l_filas),'?'));
        :v_reporte := :v_reporte || rpad('SRI_CERTIFICADOS_DEUDAS',35) || 'OK  ejec=' || nvl(to_char(l_ejec_id),'?') || ' filas=' || nvl(to_char(l_filas),'?') || chr(10);
      end;
      :v_ok_tablas := :v_ok_tablas + 1; :v_total_columnas := :v_total_columnas + 1;
    exception when others then
      l_err := replace(replace(substr(sqlerrm,1,300),chr(10),' '),chr(13),' ');
      dbms_output.put_line('   ERROR: ' || l_err);
      :v_reporte := :v_reporte || rpad('SRI_CERTIFICADOS_DEUDAS',35) || 'ERROR ' || l_err || chr(10);
      :v_err_tablas := :v_err_tablas + 1;
    end;
  end if;
end;
/
declare
  l_filas_tabla number; l_conteo_ok varchar2(1) := 'Y'; l_err varchar2(400);
begin
  dbms_output.put_line('-> SRI2006.SRI_CERTIFICADOS_REC (2 columna(s): CE_NIF,CE_NOMBRE)');
  begin
    execute immediate 'SELECT COUNT(*) FROM ' || dbms_assert.enquote_name(:v_esquema,false) || '.' || dbms_assert.enquote_name('SRI_CERTIFICADOS_REC',false) into l_filas_tabla;
  exception when others then
    l_conteo_ok := 'N';
    dbms_output.put_line('   AVISO: no se pudo contar filas (' || replace(replace(substr(sqlerrm,1,200),chr(10),' '),chr(13),' ') || '); se intenta enmascarar igual.');
  end;
  if l_conteo_ok = 'Y' and l_filas_tabla = 0 then
    dbms_output.put_line('   OMITIDA: tabla vacia (0 filas) -- no se llamo a p_mask_tab, no se creo ejecucion ad-hoc.');
    :v_vacias_tablas := :v_vacias_tablas + 1; :v_reporte := :v_reporte || rpad('SRI_CERTIFICADOS_REC',35) || 'VACIA (0 filas)' || chr(10);
  else
    if l_conteo_ok = 'Y' then dbms_output.put_line('   Filas en tabla: ' || l_filas_tabla); end if;
    begin
      pkg_dm_enmascarar.p_mask_tab(p_esquema => :v_esquema, p_tabla => 'SRI_CERTIFICADOS_REC', p_identificador => 'IDENTIFICADOR_IDENTIDAD', p_columna => 'CE_NIF,CE_NOMBRE');
      declare l_ejec_id number; l_filas number; begin
        begin select max(ejecucion_id) into l_ejec_id from tdm_ejecucion where esquema_objetivo = :v_esquema; exception when others then l_ejec_id := null; end;
        l_filas := null;
        if l_ejec_id is not null then
          begin select sum(filas_procesadas) into l_filas from tdm_mask_solicitud where ejecucion_id = l_ejec_id; exception when others then l_filas := null; end;
          if :v_ejec_min is null or l_ejec_id < :v_ejec_min then :v_ejec_min := l_ejec_id; end if;
          if :v_ejec_max is null or l_ejec_id > :v_ejec_max then :v_ejec_max := l_ejec_id; end if;
        end if;
        dbms_output.put_line('   OK  ejecucion_id=' || nvl(to_char(l_ejec_id),'?') || '  filas_procesadas=' || nvl(to_char(l_filas),'?'));
        :v_reporte := :v_reporte || rpad('SRI_CERTIFICADOS_REC',35) || 'OK  ejec=' || nvl(to_char(l_ejec_id),'?') || ' filas=' || nvl(to_char(l_filas),'?') || chr(10);
      end;
      :v_ok_tablas := :v_ok_tablas + 1; :v_total_columnas := :v_total_columnas + 2;
    exception when others then
      l_err := replace(replace(substr(sqlerrm,1,300),chr(10),' '),chr(13),' ');
      dbms_output.put_line('   ERROR: ' || l_err);
      :v_reporte := :v_reporte || rpad('SRI_CERTIFICADOS_REC',35) || 'ERROR ' || l_err || chr(10);
      :v_err_tablas := :v_err_tablas + 1;
    end;
  end if;
end;
/
declare
  l_filas_tabla number; l_conteo_ok varchar2(1) := 'Y'; l_err varchar2(400);
begin
  dbms_output.put_line('-> SRI2006.SRI_CERTIFICADOS_TRAZA (2 columna(s): CE_NIF,CE_NOMBRE)');
  begin
    execute immediate 'SELECT COUNT(*) FROM ' || dbms_assert.enquote_name(:v_esquema,false) || '.' || dbms_assert.enquote_name('SRI_CERTIFICADOS_TRAZA',false) into l_filas_tabla;
  exception when others then
    l_conteo_ok := 'N';
    dbms_output.put_line('   AVISO: no se pudo contar filas (' || replace(replace(substr(sqlerrm,1,200),chr(10),' '),chr(13),' ') || '); se intenta enmascarar igual.');
  end;
  if l_conteo_ok = 'Y' and l_filas_tabla = 0 then
    dbms_output.put_line('   OMITIDA: tabla vacia (0 filas) -- no se llamo a p_mask_tab, no se creo ejecucion ad-hoc.');
    :v_vacias_tablas := :v_vacias_tablas + 1; :v_reporte := :v_reporte || rpad('SRI_CERTIFICADOS_TRAZA',35) || 'VACIA (0 filas)' || chr(10);
  else
    if l_conteo_ok = 'Y' then dbms_output.put_line('   Filas en tabla: ' || l_filas_tabla); end if;
    begin
      pkg_dm_enmascarar.p_mask_tab(p_esquema => :v_esquema, p_tabla => 'SRI_CERTIFICADOS_TRAZA', p_identificador => 'IDENTIFICADOR_IDENTIDAD', p_columna => 'CE_NIF,CE_NOMBRE');
      declare l_ejec_id number; l_filas number; begin
        begin select max(ejecucion_id) into l_ejec_id from tdm_ejecucion where esquema_objetivo = :v_esquema; exception when others then l_ejec_id := null; end;
        l_filas := null;
        if l_ejec_id is not null then
          begin select sum(filas_procesadas) into l_filas from tdm_mask_solicitud where ejecucion_id = l_ejec_id; exception when others then l_filas := null; end;
          if :v_ejec_min is null or l_ejec_id < :v_ejec_min then :v_ejec_min := l_ejec_id; end if;
          if :v_ejec_max is null or l_ejec_id > :v_ejec_max then :v_ejec_max := l_ejec_id; end if;
        end if;
        dbms_output.put_line('   OK  ejecucion_id=' || nvl(to_char(l_ejec_id),'?') || '  filas_procesadas=' || nvl(to_char(l_filas),'?'));
        :v_reporte := :v_reporte || rpad('SRI_CERTIFICADOS_TRAZA',35) || 'OK  ejec=' || nvl(to_char(l_ejec_id),'?') || ' filas=' || nvl(to_char(l_filas),'?') || chr(10);
      end;
      :v_ok_tablas := :v_ok_tablas + 1; :v_total_columnas := :v_total_columnas + 2;
    exception when others then
      l_err := replace(replace(substr(sqlerrm,1,300),chr(10),' '),chr(13),' ');
      dbms_output.put_line('   ERROR: ' || l_err);
      :v_reporte := :v_reporte || rpad('SRI_CERTIFICADOS_TRAZA',35) || 'ERROR ' || l_err || chr(10);
      :v_err_tablas := :v_err_tablas + 1;
    end;
  end if;
end;
/
declare
  l_filas_tabla number; l_conteo_ok varchar2(1) := 'Y'; l_err varchar2(400);
begin
  dbms_output.put_line('-> SRI2006.SRI_DEUDAS_DETALLE (1 columna(s): DT_NIF)');
  begin
    execute immediate 'SELECT COUNT(*) FROM ' || dbms_assert.enquote_name(:v_esquema,false) || '.' || dbms_assert.enquote_name('SRI_DEUDAS_DETALLE',false) into l_filas_tabla;
  exception when others then
    l_conteo_ok := 'N';
    dbms_output.put_line('   AVISO: no se pudo contar filas (' || replace(replace(substr(sqlerrm,1,200),chr(10),' '),chr(13),' ') || '); se intenta enmascarar igual.');
  end;
  if l_conteo_ok = 'Y' and l_filas_tabla = 0 then
    dbms_output.put_line('   OMITIDA: tabla vacia (0 filas) -- no se llamo a p_mask_tab, no se creo ejecucion ad-hoc.');
    :v_vacias_tablas := :v_vacias_tablas + 1; :v_reporte := :v_reporte || rpad('SRI_DEUDAS_DETALLE',35) || 'VACIA (0 filas)' || chr(10);
  else
    if l_conteo_ok = 'Y' then dbms_output.put_line('   Filas en tabla: ' || l_filas_tabla); end if;
    begin
      pkg_dm_enmascarar.p_mask_tab(p_esquema => :v_esquema, p_tabla => 'SRI_DEUDAS_DETALLE', p_identificador => 'IDENTIFICADOR_IDENTIDAD', p_columna => 'DT_NIF');
      declare l_ejec_id number; l_filas number; begin
        begin select max(ejecucion_id) into l_ejec_id from tdm_ejecucion where esquema_objetivo = :v_esquema; exception when others then l_ejec_id := null; end;
        l_filas := null;
        if l_ejec_id is not null then
          begin select sum(filas_procesadas) into l_filas from tdm_mask_solicitud where ejecucion_id = l_ejec_id; exception when others then l_filas := null; end;
          if :v_ejec_min is null or l_ejec_id < :v_ejec_min then :v_ejec_min := l_ejec_id; end if;
          if :v_ejec_max is null or l_ejec_id > :v_ejec_max then :v_ejec_max := l_ejec_id; end if;
        end if;
        dbms_output.put_line('   OK  ejecucion_id=' || nvl(to_char(l_ejec_id),'?') || '  filas_procesadas=' || nvl(to_char(l_filas),'?'));
        :v_reporte := :v_reporte || rpad('SRI_DEUDAS_DETALLE',35) || 'OK  ejec=' || nvl(to_char(l_ejec_id),'?') || ' filas=' || nvl(to_char(l_filas),'?') || chr(10);
      end;
      :v_ok_tablas := :v_ok_tablas + 1; :v_total_columnas := :v_total_columnas + 1;
    exception when others then
      l_err := replace(replace(substr(sqlerrm,1,300),chr(10),' '),chr(13),' ');
      dbms_output.put_line('   ERROR: ' || l_err);
      :v_reporte := :v_reporte || rpad('SRI_DEUDAS_DETALLE',35) || 'ERROR ' || l_err || chr(10);
      :v_err_tablas := :v_err_tablas + 1;
    end;
  end if;
end;
/
declare
  l_filas_tabla number; l_conteo_ok varchar2(1) := 'Y'; l_err varchar2(400);
begin
  dbms_output.put_line('-> SRI2006.SRI_DEUDAS_DETALLE_TRAZA (1 columna(s): DT_NIF)');
  begin
    execute immediate 'SELECT COUNT(*) FROM ' || dbms_assert.enquote_name(:v_esquema,false) || '.' || dbms_assert.enquote_name('SRI_DEUDAS_DETALLE_TRAZA',false) into l_filas_tabla;
  exception when others then
    l_conteo_ok := 'N';
    dbms_output.put_line('   AVISO: no se pudo contar filas (' || replace(replace(substr(sqlerrm,1,200),chr(10),' '),chr(13),' ') || '); se intenta enmascarar igual.');
  end;
  if l_conteo_ok = 'Y' and l_filas_tabla = 0 then
    dbms_output.put_line('   OMITIDA: tabla vacia (0 filas) -- no se llamo a p_mask_tab, no se creo ejecucion ad-hoc.');
    :v_vacias_tablas := :v_vacias_tablas + 1; :v_reporte := :v_reporte || rpad('SRI_DEUDAS_DETALLE_TRAZA',35) || 'VACIA (0 filas)' || chr(10);
  else
    if l_conteo_ok = 'Y' then dbms_output.put_line('   Filas en tabla: ' || l_filas_tabla); end if;
    begin
      pkg_dm_enmascarar.p_mask_tab(p_esquema => :v_esquema, p_tabla => 'SRI_DEUDAS_DETALLE_TRAZA', p_identificador => 'IDENTIFICADOR_IDENTIDAD', p_columna => 'DT_NIF');
      declare l_ejec_id number; l_filas number; begin
        begin select max(ejecucion_id) into l_ejec_id from tdm_ejecucion where esquema_objetivo = :v_esquema; exception when others then l_ejec_id := null; end;
        l_filas := null;
        if l_ejec_id is not null then
          begin select sum(filas_procesadas) into l_filas from tdm_mask_solicitud where ejecucion_id = l_ejec_id; exception when others then l_filas := null; end;
          if :v_ejec_min is null or l_ejec_id < :v_ejec_min then :v_ejec_min := l_ejec_id; end if;
          if :v_ejec_max is null or l_ejec_id > :v_ejec_max then :v_ejec_max := l_ejec_id; end if;
        end if;
        dbms_output.put_line('   OK  ejecucion_id=' || nvl(to_char(l_ejec_id),'?') || '  filas_procesadas=' || nvl(to_char(l_filas),'?'));
        :v_reporte := :v_reporte || rpad('SRI_DEUDAS_DETALLE_TRAZA',35) || 'OK  ejec=' || nvl(to_char(l_ejec_id),'?') || ' filas=' || nvl(to_char(l_filas),'?') || chr(10);
      end;
      :v_ok_tablas := :v_ok_tablas + 1; :v_total_columnas := :v_total_columnas + 1;
    exception when others then
      l_err := replace(replace(substr(sqlerrm,1,300),chr(10),' '),chr(13),' ');
      dbms_output.put_line('   ERROR: ' || l_err);
      :v_reporte := :v_reporte || rpad('SRI_DEUDAS_DETALLE_TRAZA',35) || 'ERROR ' || l_err || chr(10);
      :v_err_tablas := :v_err_tablas + 1;
    end;
  end if;
end;
/
declare
  l_filas_tabla number; l_conteo_ok varchar2(1) := 'Y'; l_err varchar2(400);
begin
  dbms_output.put_line('-> SRI2006.SRI_DEVOLUCIONES_IGESTION (1 columna(s): DI_NIF_CIF)');
  begin
    execute immediate 'SELECT COUNT(*) FROM ' || dbms_assert.enquote_name(:v_esquema,false) || '.' || dbms_assert.enquote_name('SRI_DEVOLUCIONES_IGESTION',false) into l_filas_tabla;
  exception when others then
    l_conteo_ok := 'N';
    dbms_output.put_line('   AVISO: no se pudo contar filas (' || replace(replace(substr(sqlerrm,1,200),chr(10),' '),chr(13),' ') || '); se intenta enmascarar igual.');
  end;
  if l_conteo_ok = 'Y' and l_filas_tabla = 0 then
    dbms_output.put_line('   OMITIDA: tabla vacia (0 filas) -- no se llamo a p_mask_tab, no se creo ejecucion ad-hoc.');
    :v_vacias_tablas := :v_vacias_tablas + 1; :v_reporte := :v_reporte || rpad('SRI_DEVOLUCIONES_IGESTION',35) || 'VACIA (0 filas)' || chr(10);
  else
    if l_conteo_ok = 'Y' then dbms_output.put_line('   Filas en tabla: ' || l_filas_tabla); end if;
    begin
      pkg_dm_enmascarar.p_mask_tab(p_esquema => :v_esquema, p_tabla => 'SRI_DEVOLUCIONES_IGESTION', p_identificador => 'IDENTIFICADOR_IDENTIDAD', p_columna => 'DI_NIF_CIF');
      declare l_ejec_id number; l_filas number; begin
        begin select max(ejecucion_id) into l_ejec_id from tdm_ejecucion where esquema_objetivo = :v_esquema; exception when others then l_ejec_id := null; end;
        l_filas := null;
        if l_ejec_id is not null then
          begin select sum(filas_procesadas) into l_filas from tdm_mask_solicitud where ejecucion_id = l_ejec_id; exception when others then l_filas := null; end;
          if :v_ejec_min is null or l_ejec_id < :v_ejec_min then :v_ejec_min := l_ejec_id; end if;
          if :v_ejec_max is null or l_ejec_id > :v_ejec_max then :v_ejec_max := l_ejec_id; end if;
        end if;
        dbms_output.put_line('   OK  ejecucion_id=' || nvl(to_char(l_ejec_id),'?') || '  filas_procesadas=' || nvl(to_char(l_filas),'?'));
        :v_reporte := :v_reporte || rpad('SRI_DEVOLUCIONES_IGESTION',35) || 'OK  ejec=' || nvl(to_char(l_ejec_id),'?') || ' filas=' || nvl(to_char(l_filas),'?') || chr(10);
      end;
      :v_ok_tablas := :v_ok_tablas + 1; :v_total_columnas := :v_total_columnas + 1;
    exception when others then
      l_err := replace(replace(substr(sqlerrm,1,300),chr(10),' '),chr(13),' ');
      dbms_output.put_line('   ERROR: ' || l_err);
      :v_reporte := :v_reporte || rpad('SRI_DEVOLUCIONES_IGESTION',35) || 'ERROR ' || l_err || chr(10);
      :v_err_tablas := :v_err_tablas + 1;
    end;
  end if;
end;
/
declare
  l_filas_tabla number; l_conteo_ok varchar2(1) := 'Y'; l_err varchar2(400);
begin
  dbms_output.put_line('-> SRI2006.SRI_EXTERNA_BACK_GSOLIDARIO (1 columna(s): GS_NIF_GARANTE)');
  begin
    execute immediate 'SELECT COUNT(*) FROM ' || dbms_assert.enquote_name(:v_esquema,false) || '.' || dbms_assert.enquote_name('SRI_EXTERNA_BACK_GSOLIDARIO',false) into l_filas_tabla;
  exception when others then
    l_conteo_ok := 'N';
    dbms_output.put_line('   AVISO: no se pudo contar filas (' || replace(replace(substr(sqlerrm,1,200),chr(10),' '),chr(13),' ') || '); se intenta enmascarar igual.');
  end;
  if l_conteo_ok = 'Y' and l_filas_tabla = 0 then
    dbms_output.put_line('   OMITIDA: tabla vacia (0 filas) -- no se llamo a p_mask_tab, no se creo ejecucion ad-hoc.');
    :v_vacias_tablas := :v_vacias_tablas + 1; :v_reporte := :v_reporte || rpad('SRI_EXTERNA_BACK_GSOLIDARIO',35) || 'VACIA (0 filas)' || chr(10);
  else
    if l_conteo_ok = 'Y' then dbms_output.put_line('   Filas en tabla: ' || l_filas_tabla); end if;
    begin
      pkg_dm_enmascarar.p_mask_tab(p_esquema => :v_esquema, p_tabla => 'SRI_EXTERNA_BACK_GSOLIDARIO', p_identificador => 'IDENTIFICADOR_IDENTIDAD', p_columna => 'GS_NIF_GARANTE');
      declare l_ejec_id number; l_filas number; begin
        begin select max(ejecucion_id) into l_ejec_id from tdm_ejecucion where esquema_objetivo = :v_esquema; exception when others then l_ejec_id := null; end;
        l_filas := null;
        if l_ejec_id is not null then
          begin select sum(filas_procesadas) into l_filas from tdm_mask_solicitud where ejecucion_id = l_ejec_id; exception when others then l_filas := null; end;
          if :v_ejec_min is null or l_ejec_id < :v_ejec_min then :v_ejec_min := l_ejec_id; end if;
          if :v_ejec_max is null or l_ejec_id > :v_ejec_max then :v_ejec_max := l_ejec_id; end if;
        end if;
        dbms_output.put_line('   OK  ejecucion_id=' || nvl(to_char(l_ejec_id),'?') || '  filas_procesadas=' || nvl(to_char(l_filas),'?'));
        :v_reporte := :v_reporte || rpad('SRI_EXTERNA_BACK_GSOLIDARIO',35) || 'OK  ejec=' || nvl(to_char(l_ejec_id),'?') || ' filas=' || nvl(to_char(l_filas),'?') || chr(10);
      end;
      :v_ok_tablas := :v_ok_tablas + 1; :v_total_columnas := :v_total_columnas + 1;
    exception when others then
      l_err := replace(replace(substr(sqlerrm,1,300),chr(10),' '),chr(13),' ');
      dbms_output.put_line('   ERROR: ' || l_err);
      :v_reporte := :v_reporte || rpad('SRI_EXTERNA_BACK_GSOLIDARIO',35) || 'ERROR ' || l_err || chr(10);
      :v_err_tablas := :v_err_tablas + 1;
    end;
  end if;
end;
/
declare
  l_filas_tabla number; l_conteo_ok varchar2(1) := 'Y'; l_err varchar2(400);
begin
  dbms_output.put_line('-> SRI2006.SRI_EXTERNA_BACK_LIQUI (1 columna(s): LI_NIF_CIF)');
  begin
    execute immediate 'SELECT COUNT(*) FROM ' || dbms_assert.enquote_name(:v_esquema,false) || '.' || dbms_assert.enquote_name('SRI_EXTERNA_BACK_LIQUI',false) into l_filas_tabla;
  exception when others then
    l_conteo_ok := 'N';
    dbms_output.put_line('   AVISO: no se pudo contar filas (' || replace(replace(substr(sqlerrm,1,200),chr(10),' '),chr(13),' ') || '); se intenta enmascarar igual.');
  end;
  if l_conteo_ok = 'Y' and l_filas_tabla = 0 then
    dbms_output.put_line('   OMITIDA: tabla vacia (0 filas) -- no se llamo a p_mask_tab, no se creo ejecucion ad-hoc.');
    :v_vacias_tablas := :v_vacias_tablas + 1; :v_reporte := :v_reporte || rpad('SRI_EXTERNA_BACK_LIQUI',35) || 'VACIA (0 filas)' || chr(10);
  else
    if l_conteo_ok = 'Y' then dbms_output.put_line('   Filas en tabla: ' || l_filas_tabla); end if;
    begin
      pkg_dm_enmascarar.p_mask_tab(p_esquema => :v_esquema, p_tabla => 'SRI_EXTERNA_BACK_LIQUI', p_identificador => 'IDENTIFICADOR_IDENTIDAD', p_columna => 'LI_NIF_CIF');
      declare l_ejec_id number; l_filas number; begin
        begin select max(ejecucion_id) into l_ejec_id from tdm_ejecucion where esquema_objetivo = :v_esquema; exception when others then l_ejec_id := null; end;
        l_filas := null;
        if l_ejec_id is not null then
          begin select sum(filas_procesadas) into l_filas from tdm_mask_solicitud where ejecucion_id = l_ejec_id; exception when others then l_filas := null; end;
          if :v_ejec_min is null or l_ejec_id < :v_ejec_min then :v_ejec_min := l_ejec_id; end if;
          if :v_ejec_max is null or l_ejec_id > :v_ejec_max then :v_ejec_max := l_ejec_id; end if;
        end if;
        dbms_output.put_line('   OK  ejecucion_id=' || nvl(to_char(l_ejec_id),'?') || '  filas_procesadas=' || nvl(to_char(l_filas),'?'));
        :v_reporte := :v_reporte || rpad('SRI_EXTERNA_BACK_LIQUI',35) || 'OK  ejec=' || nvl(to_char(l_ejec_id),'?') || ' filas=' || nvl(to_char(l_filas),'?') || chr(10);
      end;
      :v_ok_tablas := :v_ok_tablas + 1; :v_total_columnas := :v_total_columnas + 1;
    exception when others then
      l_err := replace(replace(substr(sqlerrm,1,300),chr(10),' '),chr(13),' ');
      dbms_output.put_line('   ERROR: ' || l_err);
      :v_reporte := :v_reporte || rpad('SRI_EXTERNA_BACK_LIQUI',35) || 'ERROR ' || l_err || chr(10);
      :v_err_tablas := :v_err_tablas + 1;
    end;
  end if;
end;
/
declare
  l_filas_tabla number; l_conteo_ok varchar2(1) := 'Y'; l_err varchar2(400);
begin
  dbms_output.put_line('-> SRI2006.SRI_EXTERNA_LINEA (6 columna(s): ELGS_NIF_GARANTE01,ELGS_NIF_GARANTE02,ELGS_NIF_GARANTE03,ELGS_NIF_GARANTE04,ELGS_NIF_GARANTE05,EL_NIF_CIF)');
  begin
    execute immediate 'SELECT COUNT(*) FROM ' || dbms_assert.enquote_name(:v_esquema,false) || '.' || dbms_assert.enquote_name('SRI_EXTERNA_LINEA',false) into l_filas_tabla;
  exception when others then
    l_conteo_ok := 'N';
    dbms_output.put_line('   AVISO: no se pudo contar filas (' || replace(replace(substr(sqlerrm,1,200),chr(10),' '),chr(13),' ') || '); se intenta enmascarar igual.');
  end;
  if l_conteo_ok = 'Y' and l_filas_tabla = 0 then
    dbms_output.put_line('   OMITIDA: tabla vacia (0 filas) -- no se llamo a p_mask_tab, no se creo ejecucion ad-hoc.');
    :v_vacias_tablas := :v_vacias_tablas + 1; :v_reporte := :v_reporte || rpad('SRI_EXTERNA_LINEA',35) || 'VACIA (0 filas)' || chr(10);
  else
    if l_conteo_ok = 'Y' then dbms_output.put_line('   Filas en tabla: ' || l_filas_tabla); end if;
    begin
      pkg_dm_enmascarar.p_mask_tab(p_esquema => :v_esquema, p_tabla => 'SRI_EXTERNA_LINEA', p_identificador => 'IDENTIFICADOR_IDENTIDAD', p_columna => 'ELGS_NIF_GARANTE01,ELGS_NIF_GARANTE02,ELGS_NIF_GARANTE03,ELGS_NIF_GARANTE04,ELGS_NIF_GARANTE05,EL_NIF_CIF');
      declare l_ejec_id number; l_filas number; begin
        begin select max(ejecucion_id) into l_ejec_id from tdm_ejecucion where esquema_objetivo = :v_esquema; exception when others then l_ejec_id := null; end;
        l_filas := null;
        if l_ejec_id is not null then
          begin select sum(filas_procesadas) into l_filas from tdm_mask_solicitud where ejecucion_id = l_ejec_id; exception when others then l_filas := null; end;
          if :v_ejec_min is null or l_ejec_id < :v_ejec_min then :v_ejec_min := l_ejec_id; end if;
          if :v_ejec_max is null or l_ejec_id > :v_ejec_max then :v_ejec_max := l_ejec_id; end if;
        end if;
        dbms_output.put_line('   OK  ejecucion_id=' || nvl(to_char(l_ejec_id),'?') || '  filas_procesadas=' || nvl(to_char(l_filas),'?'));
        :v_reporte := :v_reporte || rpad('SRI_EXTERNA_LINEA',35) || 'OK  ejec=' || nvl(to_char(l_ejec_id),'?') || ' filas=' || nvl(to_char(l_filas),'?') || chr(10);
      end;
      :v_ok_tablas := :v_ok_tablas + 1; :v_total_columnas := :v_total_columnas + 6;
    exception when others then
      l_err := replace(replace(substr(sqlerrm,1,300),chr(10),' '),chr(13),' ');
      dbms_output.put_line('   ERROR: ' || l_err);
      :v_reporte := :v_reporte || rpad('SRI_EXTERNA_LINEA',35) || 'ERROR ' || l_err || chr(10);
      :v_err_tablas := :v_err_tablas + 1;
    end;
  end if;
end;
/
declare
  l_filas_tabla number; l_conteo_ok varchar2(1) := 'Y'; l_err varchar2(400);
begin
  dbms_output.put_line('-> SRI2006.SRI_FACTURA (1 columna(s): FA_NIF_CIF)');
  begin
    execute immediate 'SELECT COUNT(*) FROM ' || dbms_assert.enquote_name(:v_esquema,false) || '.' || dbms_assert.enquote_name('SRI_FACTURA',false) into l_filas_tabla;
  exception when others then
    l_conteo_ok := 'N';
    dbms_output.put_line('   AVISO: no se pudo contar filas (' || replace(replace(substr(sqlerrm,1,200),chr(10),' '),chr(13),' ') || '); se intenta enmascarar igual.');
  end;
  if l_conteo_ok = 'Y' and l_filas_tabla = 0 then
    dbms_output.put_line('   OMITIDA: tabla vacia (0 filas) -- no se llamo a p_mask_tab, no se creo ejecucion ad-hoc.');
    :v_vacias_tablas := :v_vacias_tablas + 1; :v_reporte := :v_reporte || rpad('SRI_FACTURA',35) || 'VACIA (0 filas)' || chr(10);
  else
    if l_conteo_ok = 'Y' then dbms_output.put_line('   Filas en tabla: ' || l_filas_tabla); end if;
    begin
      pkg_dm_enmascarar.p_mask_tab(p_esquema => :v_esquema, p_tabla => 'SRI_FACTURA', p_identificador => 'IDENTIFICADOR_IDENTIDAD', p_columna => 'FA_NIF_CIF');
      declare l_ejec_id number; l_filas number; begin
        begin select max(ejecucion_id) into l_ejec_id from tdm_ejecucion where esquema_objetivo = :v_esquema; exception when others then l_ejec_id := null; end;
        l_filas := null;
        if l_ejec_id is not null then
          begin select sum(filas_procesadas) into l_filas from tdm_mask_solicitud where ejecucion_id = l_ejec_id; exception when others then l_filas := null; end;
          if :v_ejec_min is null or l_ejec_id < :v_ejec_min then :v_ejec_min := l_ejec_id; end if;
          if :v_ejec_max is null or l_ejec_id > :v_ejec_max then :v_ejec_max := l_ejec_id; end if;
        end if;
        dbms_output.put_line('   OK  ejecucion_id=' || nvl(to_char(l_ejec_id),'?') || '  filas_procesadas=' || nvl(to_char(l_filas),'?'));
        :v_reporte := :v_reporte || rpad('SRI_FACTURA',35) || 'OK  ejec=' || nvl(to_char(l_ejec_id),'?') || ' filas=' || nvl(to_char(l_filas),'?') || chr(10);
      end;
      :v_ok_tablas := :v_ok_tablas + 1; :v_total_columnas := :v_total_columnas + 1;
    exception when others then
      l_err := replace(replace(substr(sqlerrm,1,300),chr(10),' '),chr(13),' ');
      dbms_output.put_line('   ERROR: ' || l_err);
      :v_reporte := :v_reporte || rpad('SRI_FACTURA',35) || 'ERROR ' || l_err || chr(10);
      :v_err_tablas := :v_err_tablas + 1;
    end;
  end if;
end;
/
declare
  l_filas_tabla number; l_conteo_ok varchar2(1) := 'Y'; l_err varchar2(400);
begin
  dbms_output.put_line('-> SRI2006.SRI_FICHERO_INGRESOS (1 columna(s): FI_NIF_CIF)');
  begin
    execute immediate 'SELECT COUNT(*) FROM ' || dbms_assert.enquote_name(:v_esquema,false) || '.' || dbms_assert.enquote_name('SRI_FICHERO_INGRESOS',false) into l_filas_tabla;
  exception when others then
    l_conteo_ok := 'N';
    dbms_output.put_line('   AVISO: no se pudo contar filas (' || replace(replace(substr(sqlerrm,1,200),chr(10),' '),chr(13),' ') || '); se intenta enmascarar igual.');
  end;
  if l_conteo_ok = 'Y' and l_filas_tabla = 0 then
    dbms_output.put_line('   OMITIDA: tabla vacia (0 filas) -- no se llamo a p_mask_tab, no se creo ejecucion ad-hoc.');
    :v_vacias_tablas := :v_vacias_tablas + 1; :v_reporte := :v_reporte || rpad('SRI_FICHERO_INGRESOS',35) || 'VACIA (0 filas)' || chr(10);
  else
    if l_conteo_ok = 'Y' then dbms_output.put_line('   Filas en tabla: ' || l_filas_tabla); end if;
    begin
      pkg_dm_enmascarar.p_mask_tab(p_esquema => :v_esquema, p_tabla => 'SRI_FICHERO_INGRESOS', p_identificador => 'IDENTIFICADOR_IDENTIDAD', p_columna => 'FI_NIF_CIF');
      declare l_ejec_id number; l_filas number; begin
        begin select max(ejecucion_id) into l_ejec_id from tdm_ejecucion where esquema_objetivo = :v_esquema; exception when others then l_ejec_id := null; end;
        l_filas := null;
        if l_ejec_id is not null then
          begin select sum(filas_procesadas) into l_filas from tdm_mask_solicitud where ejecucion_id = l_ejec_id; exception when others then l_filas := null; end;
          if :v_ejec_min is null or l_ejec_id < :v_ejec_min then :v_ejec_min := l_ejec_id; end if;
          if :v_ejec_max is null or l_ejec_id > :v_ejec_max then :v_ejec_max := l_ejec_id; end if;
        end if;
        dbms_output.put_line('   OK  ejecucion_id=' || nvl(to_char(l_ejec_id),'?') || '  filas_procesadas=' || nvl(to_char(l_filas),'?'));
        :v_reporte := :v_reporte || rpad('SRI_FICHERO_INGRESOS',35) || 'OK  ejec=' || nvl(to_char(l_ejec_id),'?') || ' filas=' || nvl(to_char(l_filas),'?') || chr(10);
      end;
      :v_ok_tablas := :v_ok_tablas + 1; :v_total_columnas := :v_total_columnas + 1;
    exception when others then
      l_err := replace(replace(substr(sqlerrm,1,300),chr(10),' '),chr(13),' ');
      dbms_output.put_line('   ERROR: ' || l_err);
      :v_reporte := :v_reporte || rpad('SRI_FICHERO_INGRESOS',35) || 'ERROR ' || l_err || chr(10);
      :v_err_tablas := :v_err_tablas + 1;
    end;
  end if;
end;
/
declare
  l_filas_tabla number; l_conteo_ok varchar2(1) := 'Y'; l_err varchar2(400);
begin
  dbms_output.put_line('-> SRI2006.SRI_GARANTIA (1 columna(s): GA_NIF_CIF_GARANTE)');
  begin
    execute immediate 'SELECT COUNT(*) FROM ' || dbms_assert.enquote_name(:v_esquema,false) || '.' || dbms_assert.enquote_name('SRI_GARANTIA',false) into l_filas_tabla;
  exception when others then
    l_conteo_ok := 'N';
    dbms_output.put_line('   AVISO: no se pudo contar filas (' || replace(replace(substr(sqlerrm,1,200),chr(10),' '),chr(13),' ') || '); se intenta enmascarar igual.');
  end;
  if l_conteo_ok = 'Y' and l_filas_tabla = 0 then
    dbms_output.put_line('   OMITIDA: tabla vacia (0 filas) -- no se llamo a p_mask_tab, no se creo ejecucion ad-hoc.');
    :v_vacias_tablas := :v_vacias_tablas + 1; :v_reporte := :v_reporte || rpad('SRI_GARANTIA',35) || 'VACIA (0 filas)' || chr(10);
  else
    if l_conteo_ok = 'Y' then dbms_output.put_line('   Filas en tabla: ' || l_filas_tabla); end if;
    begin
      pkg_dm_enmascarar.p_mask_tab(p_esquema => :v_esquema, p_tabla => 'SRI_GARANTIA', p_identificador => 'IDENTIFICADOR_IDENTIDAD', p_columna => 'GA_NIF_CIF_GARANTE');
      declare l_ejec_id number; l_filas number; begin
        begin select max(ejecucion_id) into l_ejec_id from tdm_ejecucion where esquema_objetivo = :v_esquema; exception when others then l_ejec_id := null; end;
        l_filas := null;
        if l_ejec_id is not null then
          begin select sum(filas_procesadas) into l_filas from tdm_mask_solicitud where ejecucion_id = l_ejec_id; exception when others then l_filas := null; end;
          if :v_ejec_min is null or l_ejec_id < :v_ejec_min then :v_ejec_min := l_ejec_id; end if;
          if :v_ejec_max is null or l_ejec_id > :v_ejec_max then :v_ejec_max := l_ejec_id; end if;
        end if;
        dbms_output.put_line('   OK  ejecucion_id=' || nvl(to_char(l_ejec_id),'?') || '  filas_procesadas=' || nvl(to_char(l_filas),'?'));
        :v_reporte := :v_reporte || rpad('SRI_GARANTIA',35) || 'OK  ejec=' || nvl(to_char(l_ejec_id),'?') || ' filas=' || nvl(to_char(l_filas),'?') || chr(10);
      end;
      :v_ok_tablas := :v_ok_tablas + 1; :v_total_columnas := :v_total_columnas + 1;
    exception when others then
      l_err := replace(replace(substr(sqlerrm,1,300),chr(10),' '),chr(13),' ');
      dbms_output.put_line('   ERROR: ' || l_err);
      :v_reporte := :v_reporte || rpad('SRI_GARANTIA',35) || 'ERROR ' || l_err || chr(10);
      :v_err_tablas := :v_err_tablas + 1;
    end;
  end if;
end;
/
declare
  l_filas_tabla number; l_conteo_ok varchar2(1) := 'Y'; l_err varchar2(400);
begin
  dbms_output.put_line('-> SRI2006.SRI_GIROS_N65 (1 columna(s): GN_NIF)');
  begin
    execute immediate 'SELECT COUNT(*) FROM ' || dbms_assert.enquote_name(:v_esquema,false) || '.' || dbms_assert.enquote_name('SRI_GIROS_N65',false) into l_filas_tabla;
  exception when others then
    l_conteo_ok := 'N';
    dbms_output.put_line('   AVISO: no se pudo contar filas (' || replace(replace(substr(sqlerrm,1,200),chr(10),' '),chr(13),' ') || '); se intenta enmascarar igual.');
  end;
  if l_conteo_ok = 'Y' and l_filas_tabla = 0 then
    dbms_output.put_line('   OMITIDA: tabla vacia (0 filas) -- no se llamo a p_mask_tab, no se creo ejecucion ad-hoc.');
    :v_vacias_tablas := :v_vacias_tablas + 1; :v_reporte := :v_reporte || rpad('SRI_GIROS_N65',35) || 'VACIA (0 filas)' || chr(10);
  else
    if l_conteo_ok = 'Y' then dbms_output.put_line('   Filas en tabla: ' || l_filas_tabla); end if;
    begin
      pkg_dm_enmascarar.p_mask_tab(p_esquema => :v_esquema, p_tabla => 'SRI_GIROS_N65', p_identificador => 'IDENTIFICADOR_IDENTIDAD', p_columna => 'GN_NIF');
      declare l_ejec_id number; l_filas number; begin
        begin select max(ejecucion_id) into l_ejec_id from tdm_ejecucion where esquema_objetivo = :v_esquema; exception when others then l_ejec_id := null; end;
        l_filas := null;
        if l_ejec_id is not null then
          begin select sum(filas_procesadas) into l_filas from tdm_mask_solicitud where ejecucion_id = l_ejec_id; exception when others then l_filas := null; end;
          if :v_ejec_min is null or l_ejec_id < :v_ejec_min then :v_ejec_min := l_ejec_id; end if;
          if :v_ejec_max is null or l_ejec_id > :v_ejec_max then :v_ejec_max := l_ejec_id; end if;
        end if;
        dbms_output.put_line('   OK  ejecucion_id=' || nvl(to_char(l_ejec_id),'?') || '  filas_procesadas=' || nvl(to_char(l_filas),'?'));
        :v_reporte := :v_reporte || rpad('SRI_GIROS_N65',35) || 'OK  ejec=' || nvl(to_char(l_ejec_id),'?') || ' filas=' || nvl(to_char(l_filas),'?') || chr(10);
      end;
      :v_ok_tablas := :v_ok_tablas + 1; :v_total_columnas := :v_total_columnas + 1;
    exception when others then
      l_err := replace(replace(substr(sqlerrm,1,300),chr(10),' '),chr(13),' ');
      dbms_output.put_line('   ERROR: ' || l_err);
      :v_reporte := :v_reporte || rpad('SRI_GIROS_N65',35) || 'ERROR ' || l_err || chr(10);
      :v_err_tablas := :v_err_tablas + 1;
    end;
  end if;
end;
/
declare
  l_filas_tabla number; l_conteo_ok varchar2(1) := 'Y'; l_err varchar2(400);
begin
  dbms_output.put_line('-> SRI2006.SRI_IMPORT_INFGESTION_IDENTLIQ (2 columna(s): APENOM_DEUDOR,NIF_DEUDOR)');
  begin
    execute immediate 'SELECT COUNT(*) FROM ' || dbms_assert.enquote_name(:v_esquema,false) || '.' || dbms_assert.enquote_name('SRI_IMPORT_INFGESTION_IDENTLIQ',false) into l_filas_tabla;
  exception when others then
    l_conteo_ok := 'N';
    dbms_output.put_line('   AVISO: no se pudo contar filas (' || replace(replace(substr(sqlerrm,1,200),chr(10),' '),chr(13),' ') || '); se intenta enmascarar igual.');
  end;
  if l_conteo_ok = 'Y' and l_filas_tabla = 0 then
    dbms_output.put_line('   OMITIDA: tabla vacia (0 filas) -- no se llamo a p_mask_tab, no se creo ejecucion ad-hoc.');
    :v_vacias_tablas := :v_vacias_tablas + 1; :v_reporte := :v_reporte || rpad('SRI_IMPORT_INFGESTION_IDENTLIQ',35) || 'VACIA (0 filas)' || chr(10);
  else
    if l_conteo_ok = 'Y' then dbms_output.put_line('   Filas en tabla: ' || l_filas_tabla); end if;
    begin
      pkg_dm_enmascarar.p_mask_tab(p_esquema => :v_esquema, p_tabla => 'SRI_IMPORT_INFGESTION_IDENTLIQ', p_identificador => 'IDENTIFICADOR_IDENTIDAD', p_columna => 'APENOM_DEUDOR,NIF_DEUDOR');
      declare l_ejec_id number; l_filas number; begin
        begin select max(ejecucion_id) into l_ejec_id from tdm_ejecucion where esquema_objetivo = :v_esquema; exception when others then l_ejec_id := null; end;
        l_filas := null;
        if l_ejec_id is not null then
          begin select sum(filas_procesadas) into l_filas from tdm_mask_solicitud where ejecucion_id = l_ejec_id; exception when others then l_filas := null; end;
          if :v_ejec_min is null or l_ejec_id < :v_ejec_min then :v_ejec_min := l_ejec_id; end if;
          if :v_ejec_max is null or l_ejec_id > :v_ejec_max then :v_ejec_max := l_ejec_id; end if;
        end if;
        dbms_output.put_line('   OK  ejecucion_id=' || nvl(to_char(l_ejec_id),'?') || '  filas_procesadas=' || nvl(to_char(l_filas),'?'));
        :v_reporte := :v_reporte || rpad('SRI_IMPORT_INFGESTION_IDENTLIQ',35) || 'OK  ejec=' || nvl(to_char(l_ejec_id),'?') || ' filas=' || nvl(to_char(l_filas),'?') || chr(10);
      end;
      :v_ok_tablas := :v_ok_tablas + 1; :v_total_columnas := :v_total_columnas + 2;
    exception when others then
      l_err := replace(replace(substr(sqlerrm,1,300),chr(10),' '),chr(13),' ');
      dbms_output.put_line('   ERROR: ' || l_err);
      :v_reporte := :v_reporte || rpad('SRI_IMPORT_INFGESTION_IDENTLIQ',35) || 'ERROR ' || l_err || chr(10);
      :v_err_tablas := :v_err_tablas + 1;
    end;
  end if;
end;
/
declare
  l_filas_tabla number; l_conteo_ok varchar2(1) := 'Y'; l_err varchar2(400);
begin
  dbms_output.put_line('-> SRI2006.SRI_IMPORT_INFGESTION_PENDIENT (3 columna(s): APENOM,NIF,TEXTO)');
  begin
    execute immediate 'SELECT COUNT(*) FROM ' || dbms_assert.enquote_name(:v_esquema,false) || '.' || dbms_assert.enquote_name('SRI_IMPORT_INFGESTION_PENDIENT',false) into l_filas_tabla;
  exception when others then
    l_conteo_ok := 'N';
    dbms_output.put_line('   AVISO: no se pudo contar filas (' || replace(replace(substr(sqlerrm,1,200),chr(10),' '),chr(13),' ') || '); se intenta enmascarar igual.');
  end;
  if l_conteo_ok = 'Y' and l_filas_tabla = 0 then
    dbms_output.put_line('   OMITIDA: tabla vacia (0 filas) -- no se llamo a p_mask_tab, no se creo ejecucion ad-hoc.');
    :v_vacias_tablas := :v_vacias_tablas + 1; :v_reporte := :v_reporte || rpad('SRI_IMPORT_INFGESTION_PENDIENT',35) || 'VACIA (0 filas)' || chr(10);
  else
    if l_conteo_ok = 'Y' then dbms_output.put_line('   Filas en tabla: ' || l_filas_tabla); end if;
    begin
      pkg_dm_enmascarar.p_mask_tab(p_esquema => :v_esquema, p_tabla => 'SRI_IMPORT_INFGESTION_PENDIENT', p_identificador => 'IDENTIFICADOR_IDENTIDAD', p_columna => 'APENOM,NIF,TEXTO');
      declare l_ejec_id number; l_filas number; begin
        begin select max(ejecucion_id) into l_ejec_id from tdm_ejecucion where esquema_objetivo = :v_esquema; exception when others then l_ejec_id := null; end;
        l_filas := null;
        if l_ejec_id is not null then
          begin select sum(filas_procesadas) into l_filas from tdm_mask_solicitud where ejecucion_id = l_ejec_id; exception when others then l_filas := null; end;
          if :v_ejec_min is null or l_ejec_id < :v_ejec_min then :v_ejec_min := l_ejec_id; end if;
          if :v_ejec_max is null or l_ejec_id > :v_ejec_max then :v_ejec_max := l_ejec_id; end if;
        end if;
        dbms_output.put_line('   OK  ejecucion_id=' || nvl(to_char(l_ejec_id),'?') || '  filas_procesadas=' || nvl(to_char(l_filas),'?'));
        :v_reporte := :v_reporte || rpad('SRI_IMPORT_INFGESTION_PENDIENT',35) || 'OK  ejec=' || nvl(to_char(l_ejec_id),'?') || ' filas=' || nvl(to_char(l_filas),'?') || chr(10);
      end;
      :v_ok_tablas := :v_ok_tablas + 1; :v_total_columnas := :v_total_columnas + 3;
    exception when others then
      l_err := replace(replace(substr(sqlerrm,1,300),chr(10),' '),chr(13),' ');
      dbms_output.put_line('   ERROR: ' || l_err);
      :v_reporte := :v_reporte || rpad('SRI_IMPORT_INFGESTION_PENDIENT',35) || 'ERROR ' || l_err || chr(10);
      :v_err_tablas := :v_err_tablas + 1;
    end;
  end if;
end;
/
declare
  l_filas_tabla number; l_conteo_ok varchar2(1) := 'Y'; l_err varchar2(400);
begin
  dbms_output.put_line('-> SRI2006.SRI_IMPORT_LIQUIDACION (2 columna(s): NIF_CIF,TEXTO)');
  begin
    execute immediate 'SELECT COUNT(*) FROM ' || dbms_assert.enquote_name(:v_esquema,false) || '.' || dbms_assert.enquote_name('SRI_IMPORT_LIQUIDACION',false) into l_filas_tabla;
  exception when others then
    l_conteo_ok := 'N';
    dbms_output.put_line('   AVISO: no se pudo contar filas (' || replace(replace(substr(sqlerrm,1,200),chr(10),' '),chr(13),' ') || '); se intenta enmascarar igual.');
  end;
  if l_conteo_ok = 'Y' and l_filas_tabla = 0 then
    dbms_output.put_line('   OMITIDA: tabla vacia (0 filas) -- no se llamo a p_mask_tab, no se creo ejecucion ad-hoc.');
    :v_vacias_tablas := :v_vacias_tablas + 1; :v_reporte := :v_reporte || rpad('SRI_IMPORT_LIQUIDACION',35) || 'VACIA (0 filas)' || chr(10);
  else
    if l_conteo_ok = 'Y' then dbms_output.put_line('   Filas en tabla: ' || l_filas_tabla); end if;
    begin
      pkg_dm_enmascarar.p_mask_tab(p_esquema => :v_esquema, p_tabla => 'SRI_IMPORT_LIQUIDACION', p_identificador => 'IDENTIFICADOR_IDENTIDAD', p_columna => 'NIF_CIF,TEXTO');
      declare l_ejec_id number; l_filas number; begin
        begin select max(ejecucion_id) into l_ejec_id from tdm_ejecucion where esquema_objetivo = :v_esquema; exception when others then l_ejec_id := null; end;
        l_filas := null;
        if l_ejec_id is not null then
          begin select sum(filas_procesadas) into l_filas from tdm_mask_solicitud where ejecucion_id = l_ejec_id; exception when others then l_filas := null; end;
          if :v_ejec_min is null or l_ejec_id < :v_ejec_min then :v_ejec_min := l_ejec_id; end if;
          if :v_ejec_max is null or l_ejec_id > :v_ejec_max then :v_ejec_max := l_ejec_id; end if;
        end if;
        dbms_output.put_line('   OK  ejecucion_id=' || nvl(to_char(l_ejec_id),'?') || '  filas_procesadas=' || nvl(to_char(l_filas),'?'));
        :v_reporte := :v_reporte || rpad('SRI_IMPORT_LIQUIDACION',35) || 'OK  ejec=' || nvl(to_char(l_ejec_id),'?') || ' filas=' || nvl(to_char(l_filas),'?') || chr(10);
      end;
      :v_ok_tablas := :v_ok_tablas + 1; :v_total_columnas := :v_total_columnas + 2;
    exception when others then
      l_err := replace(replace(substr(sqlerrm,1,300),chr(10),' '),chr(13),' ');
      dbms_output.put_line('   ERROR: ' || l_err);
      :v_reporte := :v_reporte || rpad('SRI_IMPORT_LIQUIDACION',35) || 'ERROR ' || l_err || chr(10);
      :v_err_tablas := :v_err_tablas + 1;
    end;
  end if;
end;
/
declare
  l_filas_tabla number; l_conteo_ok varchar2(1) := 'Y'; l_err varchar2(400);
begin
  dbms_output.put_line('-> SRI2006.SRI_IMPORT_NORMA65 (2 columna(s): NIF,TEXTO)');
  begin
    execute immediate 'SELECT COUNT(*) FROM ' || dbms_assert.enquote_name(:v_esquema,false) || '.' || dbms_assert.enquote_name('SRI_IMPORT_NORMA65',false) into l_filas_tabla;
  exception when others then
    l_conteo_ok := 'N';
    dbms_output.put_line('   AVISO: no se pudo contar filas (' || replace(replace(substr(sqlerrm,1,200),chr(10),' '),chr(13),' ') || '); se intenta enmascarar igual.');
  end;
  if l_conteo_ok = 'Y' and l_filas_tabla = 0 then
    dbms_output.put_line('   OMITIDA: tabla vacia (0 filas) -- no se llamo a p_mask_tab, no se creo ejecucion ad-hoc.');
    :v_vacias_tablas := :v_vacias_tablas + 1; :v_reporte := :v_reporte || rpad('SRI_IMPORT_NORMA65',35) || 'VACIA (0 filas)' || chr(10);
  else
    if l_conteo_ok = 'Y' then dbms_output.put_line('   Filas en tabla: ' || l_filas_tabla); end if;
    begin
      pkg_dm_enmascarar.p_mask_tab(p_esquema => :v_esquema, p_tabla => 'SRI_IMPORT_NORMA65', p_identificador => 'IDENTIFICADOR_IDENTIDAD', p_columna => 'NIF,TEXTO');
      declare l_ejec_id number; l_filas number; begin
        begin select max(ejecucion_id) into l_ejec_id from tdm_ejecucion where esquema_objetivo = :v_esquema; exception when others then l_ejec_id := null; end;
        l_filas := null;
        if l_ejec_id is not null then
          begin select sum(filas_procesadas) into l_filas from tdm_mask_solicitud where ejecucion_id = l_ejec_id; exception when others then l_filas := null; end;
          if :v_ejec_min is null or l_ejec_id < :v_ejec_min then :v_ejec_min := l_ejec_id; end if;
          if :v_ejec_max is null or l_ejec_id > :v_ejec_max then :v_ejec_max := l_ejec_id; end if;
        end if;
        dbms_output.put_line('   OK  ejecucion_id=' || nvl(to_char(l_ejec_id),'?') || '  filas_procesadas=' || nvl(to_char(l_filas),'?'));
        :v_reporte := :v_reporte || rpad('SRI_IMPORT_NORMA65',35) || 'OK  ejec=' || nvl(to_char(l_ejec_id),'?') || ' filas=' || nvl(to_char(l_filas),'?') || chr(10);
      end;
      :v_ok_tablas := :v_ok_tablas + 1; :v_total_columnas := :v_total_columnas + 2;
    exception when others then
      l_err := replace(replace(substr(sqlerrm,1,300),chr(10),' '),chr(13),' ');
      dbms_output.put_line('   ERROR: ' || l_err);
      :v_reporte := :v_reporte || rpad('SRI_IMPORT_NORMA65',35) || 'ERROR ' || l_err || chr(10);
      :v_err_tablas := :v_err_tablas + 1;
    end;
  end if;
end;
/
declare
  l_filas_tabla number; l_conteo_ok varchar2(1) := 'Y'; l_err varchar2(400);
begin
  dbms_output.put_line('-> SRI2006.SRI_IMPORT_PENDIENTE_GESTION (3 columna(s): APENOM,NIF,TEXTO)');
  begin
    execute immediate 'SELECT COUNT(*) FROM ' || dbms_assert.enquote_name(:v_esquema,false) || '.' || dbms_assert.enquote_name('SRI_IMPORT_PENDIENTE_GESTION',false) into l_filas_tabla;
  exception when others then
    l_conteo_ok := 'N';
    dbms_output.put_line('   AVISO: no se pudo contar filas (' || replace(replace(substr(sqlerrm,1,200),chr(10),' '),chr(13),' ') || '); se intenta enmascarar igual.');
  end;
  if l_conteo_ok = 'Y' and l_filas_tabla = 0 then
    dbms_output.put_line('   OMITIDA: tabla vacia (0 filas) -- no se llamo a p_mask_tab, no se creo ejecucion ad-hoc.');
    :v_vacias_tablas := :v_vacias_tablas + 1; :v_reporte := :v_reporte || rpad('SRI_IMPORT_PENDIENTE_GESTION',35) || 'VACIA (0 filas)' || chr(10);
  else
    if l_conteo_ok = 'Y' then dbms_output.put_line('   Filas en tabla: ' || l_filas_tabla); end if;
    begin
      pkg_dm_enmascarar.p_mask_tab(p_esquema => :v_esquema, p_tabla => 'SRI_IMPORT_PENDIENTE_GESTION', p_identificador => 'IDENTIFICADOR_IDENTIDAD', p_columna => 'APENOM,NIF,TEXTO');
      declare l_ejec_id number; l_filas number; begin
        begin select max(ejecucion_id) into l_ejec_id from tdm_ejecucion where esquema_objetivo = :v_esquema; exception when others then l_ejec_id := null; end;
        l_filas := null;
        if l_ejec_id is not null then
          begin select sum(filas_procesadas) into l_filas from tdm_mask_solicitud where ejecucion_id = l_ejec_id; exception when others then l_filas := null; end;
          if :v_ejec_min is null or l_ejec_id < :v_ejec_min then :v_ejec_min := l_ejec_id; end if;
          if :v_ejec_max is null or l_ejec_id > :v_ejec_max then :v_ejec_max := l_ejec_id; end if;
        end if;
        dbms_output.put_line('   OK  ejecucion_id=' || nvl(to_char(l_ejec_id),'?') || '  filas_procesadas=' || nvl(to_char(l_filas),'?'));
        :v_reporte := :v_reporte || rpad('SRI_IMPORT_PENDIENTE_GESTION',35) || 'OK  ejec=' || nvl(to_char(l_ejec_id),'?') || ' filas=' || nvl(to_char(l_filas),'?') || chr(10);
      end;
      :v_ok_tablas := :v_ok_tablas + 1; :v_total_columnas := :v_total_columnas + 3;
    exception when others then
      l_err := replace(replace(substr(sqlerrm,1,300),chr(10),' '),chr(13),' ');
      dbms_output.put_line('   ERROR: ' || l_err);
      :v_reporte := :v_reporte || rpad('SRI_IMPORT_PENDIENTE_GESTION',35) || 'ERROR ' || l_err || chr(10);
      :v_err_tablas := :v_err_tablas + 1;
    end;
  end if;
end;
/
declare
  l_filas_tabla number; l_conteo_ok varchar2(1) := 'Y'; l_err varchar2(400);
begin
  dbms_output.put_line('-> SRI2006.SRI_INFORME_GESTION (1 columna(s): IG_NIF_CIF)');
  begin
    execute immediate 'SELECT COUNT(*) FROM ' || dbms_assert.enquote_name(:v_esquema,false) || '.' || dbms_assert.enquote_name('SRI_INFORME_GESTION',false) into l_filas_tabla;
  exception when others then
    l_conteo_ok := 'N';
    dbms_output.put_line('   AVISO: no se pudo contar filas (' || replace(replace(substr(sqlerrm,1,200),chr(10),' '),chr(13),' ') || '); se intenta enmascarar igual.');
  end;
  if l_conteo_ok = 'Y' and l_filas_tabla = 0 then
    dbms_output.put_line('   OMITIDA: tabla vacia (0 filas) -- no se llamo a p_mask_tab, no se creo ejecucion ad-hoc.');
    :v_vacias_tablas := :v_vacias_tablas + 1; :v_reporte := :v_reporte || rpad('SRI_INFORME_GESTION',35) || 'VACIA (0 filas)' || chr(10);
  else
    if l_conteo_ok = 'Y' then dbms_output.put_line('   Filas en tabla: ' || l_filas_tabla); end if;
    begin
      pkg_dm_enmascarar.p_mask_tab(p_esquema => :v_esquema, p_tabla => 'SRI_INFORME_GESTION', p_identificador => 'IDENTIFICADOR_IDENTIDAD', p_columna => 'IG_NIF_CIF');
      declare l_ejec_id number; l_filas number; begin
        begin select max(ejecucion_id) into l_ejec_id from tdm_ejecucion where esquema_objetivo = :v_esquema; exception when others then l_ejec_id := null; end;
        l_filas := null;
        if l_ejec_id is not null then
          begin select sum(filas_procesadas) into l_filas from tdm_mask_solicitud where ejecucion_id = l_ejec_id; exception when others then l_filas := null; end;
          if :v_ejec_min is null or l_ejec_id < :v_ejec_min then :v_ejec_min := l_ejec_id; end if;
          if :v_ejec_max is null or l_ejec_id > :v_ejec_max then :v_ejec_max := l_ejec_id; end if;
        end if;
        dbms_output.put_line('   OK  ejecucion_id=' || nvl(to_char(l_ejec_id),'?') || '  filas_procesadas=' || nvl(to_char(l_filas),'?'));
        :v_reporte := :v_reporte || rpad('SRI_INFORME_GESTION',35) || 'OK  ejec=' || nvl(to_char(l_ejec_id),'?') || ' filas=' || nvl(to_char(l_filas),'?') || chr(10);
      end;
      :v_ok_tablas := :v_ok_tablas + 1; :v_total_columnas := :v_total_columnas + 1;
    exception when others then
      l_err := replace(replace(substr(sqlerrm,1,300),chr(10),' '),chr(13),' ');
      dbms_output.put_line('   ERROR: ' || l_err);
      :v_reporte := :v_reporte || rpad('SRI_INFORME_GESTION',35) || 'ERROR ' || l_err || chr(10);
      :v_err_tablas := :v_err_tablas + 1;
    end;
  end if;
end;
/
declare
  l_filas_tabla number; l_conteo_ok varchar2(1) := 'Y'; l_err varchar2(400);
begin
  dbms_output.put_line('-> SRI2006.SRI_INGRESOS (1 columna(s): IN_NIF_CIF_TERCERO)');
  begin
    execute immediate 'SELECT COUNT(*) FROM ' || dbms_assert.enquote_name(:v_esquema,false) || '.' || dbms_assert.enquote_name('SRI_INGRESOS',false) into l_filas_tabla;
  exception when others then
    l_conteo_ok := 'N';
    dbms_output.put_line('   AVISO: no se pudo contar filas (' || replace(replace(substr(sqlerrm,1,200),chr(10),' '),chr(13),' ') || '); se intenta enmascarar igual.');
  end;
  if l_conteo_ok = 'Y' and l_filas_tabla = 0 then
    dbms_output.put_line('   OMITIDA: tabla vacia (0 filas) -- no se llamo a p_mask_tab, no se creo ejecucion ad-hoc.');
    :v_vacias_tablas := :v_vacias_tablas + 1; :v_reporte := :v_reporte || rpad('SRI_INGRESOS',35) || 'VACIA (0 filas)' || chr(10);
  else
    if l_conteo_ok = 'Y' then dbms_output.put_line('   Filas en tabla: ' || l_filas_tabla); end if;
    begin
      pkg_dm_enmascarar.p_mask_tab(p_esquema => :v_esquema, p_tabla => 'SRI_INGRESOS', p_identificador => 'IDENTIFICADOR_IDENTIDAD', p_columna => 'IN_NIF_CIF_TERCERO');
      declare l_ejec_id number; l_filas number; begin
        begin select max(ejecucion_id) into l_ejec_id from tdm_ejecucion where esquema_objetivo = :v_esquema; exception when others then l_ejec_id := null; end;
        l_filas := null;
        if l_ejec_id is not null then
          begin select sum(filas_procesadas) into l_filas from tdm_mask_solicitud where ejecucion_id = l_ejec_id; exception when others then l_filas := null; end;
          if :v_ejec_min is null or l_ejec_id < :v_ejec_min then :v_ejec_min := l_ejec_id; end if;
          if :v_ejec_max is null or l_ejec_id > :v_ejec_max then :v_ejec_max := l_ejec_id; end if;
        end if;
        dbms_output.put_line('   OK  ejecucion_id=' || nvl(to_char(l_ejec_id),'?') || '  filas_procesadas=' || nvl(to_char(l_filas),'?'));
        :v_reporte := :v_reporte || rpad('SRI_INGRESOS',35) || 'OK  ejec=' || nvl(to_char(l_ejec_id),'?') || ' filas=' || nvl(to_char(l_filas),'?') || chr(10);
      end;
      :v_ok_tablas := :v_ok_tablas + 1; :v_total_columnas := :v_total_columnas + 1;
    exception when others then
      l_err := replace(replace(substr(sqlerrm,1,300),chr(10),' '),chr(13),' ');
      dbms_output.put_line('   ERROR: ' || l_err);
      :v_reporte := :v_reporte || rpad('SRI_INGRESOS',35) || 'ERROR ' || l_err || chr(10);
      :v_err_tablas := :v_err_tablas + 1;
    end;
  end if;
end;
/
declare
  l_filas_tabla number; l_conteo_ok varchar2(1) := 'Y'; l_err varchar2(400);
begin
  dbms_output.put_line('-> SRI2006.SRI_INGRESOS_DEVOLVER (1 columna(s): ID_NIF_CIF_TERCERO)');
  begin
    execute immediate 'SELECT COUNT(*) FROM ' || dbms_assert.enquote_name(:v_esquema,false) || '.' || dbms_assert.enquote_name('SRI_INGRESOS_DEVOLVER',false) into l_filas_tabla;
  exception when others then
    l_conteo_ok := 'N';
    dbms_output.put_line('   AVISO: no se pudo contar filas (' || replace(replace(substr(sqlerrm,1,200),chr(10),' '),chr(13),' ') || '); se intenta enmascarar igual.');
  end;
  if l_conteo_ok = 'Y' and l_filas_tabla = 0 then
    dbms_output.put_line('   OMITIDA: tabla vacia (0 filas) -- no se llamo a p_mask_tab, no se creo ejecucion ad-hoc.');
    :v_vacias_tablas := :v_vacias_tablas + 1; :v_reporte := :v_reporte || rpad('SRI_INGRESOS_DEVOLVER',35) || 'VACIA (0 filas)' || chr(10);
  else
    if l_conteo_ok = 'Y' then dbms_output.put_line('   Filas en tabla: ' || l_filas_tabla); end if;
    begin
      pkg_dm_enmascarar.p_mask_tab(p_esquema => :v_esquema, p_tabla => 'SRI_INGRESOS_DEVOLVER', p_identificador => 'IDENTIFICADOR_IDENTIDAD', p_columna => 'ID_NIF_CIF_TERCERO');
      declare l_ejec_id number; l_filas number; begin
        begin select max(ejecucion_id) into l_ejec_id from tdm_ejecucion where esquema_objetivo = :v_esquema; exception when others then l_ejec_id := null; end;
        l_filas := null;
        if l_ejec_id is not null then
          begin select sum(filas_procesadas) into l_filas from tdm_mask_solicitud where ejecucion_id = l_ejec_id; exception when others then l_filas := null; end;
          if :v_ejec_min is null or l_ejec_id < :v_ejec_min then :v_ejec_min := l_ejec_id; end if;
          if :v_ejec_max is null or l_ejec_id > :v_ejec_max then :v_ejec_max := l_ejec_id; end if;
        end if;
        dbms_output.put_line('   OK  ejecucion_id=' || nvl(to_char(l_ejec_id),'?') || '  filas_procesadas=' || nvl(to_char(l_filas),'?'));
        :v_reporte := :v_reporte || rpad('SRI_INGRESOS_DEVOLVER',35) || 'OK  ejec=' || nvl(to_char(l_ejec_id),'?') || ' filas=' || nvl(to_char(l_filas),'?') || chr(10);
      end;
      :v_ok_tablas := :v_ok_tablas + 1; :v_total_columnas := :v_total_columnas + 1;
    exception when others then
      l_err := replace(replace(substr(sqlerrm,1,300),chr(10),' '),chr(13),' ');
      dbms_output.put_line('   ERROR: ' || l_err);
      :v_reporte := :v_reporte || rpad('SRI_INGRESOS_DEVOLVER',35) || 'ERROR ' || l_err || chr(10);
      :v_err_tablas := :v_err_tablas + 1;
    end;
  end if;
end;
/
declare
  l_filas_tabla number; l_conteo_ok varchar2(1) := 'Y'; l_err varchar2(400);
begin
  dbms_output.put_line('-> SRI2006.SRI_INGRESOS_PRIMARIOS (1 columna(s): IP_NIF_CIF)');
  begin
    execute immediate 'SELECT COUNT(*) FROM ' || dbms_assert.enquote_name(:v_esquema,false) || '.' || dbms_assert.enquote_name('SRI_INGRESOS_PRIMARIOS',false) into l_filas_tabla;
  exception when others then
    l_conteo_ok := 'N';
    dbms_output.put_line('   AVISO: no se pudo contar filas (' || replace(replace(substr(sqlerrm,1,200),chr(10),' '),chr(13),' ') || '); se intenta enmascarar igual.');
  end;
  if l_conteo_ok = 'Y' and l_filas_tabla = 0 then
    dbms_output.put_line('   OMITIDA: tabla vacia (0 filas) -- no se llamo a p_mask_tab, no se creo ejecucion ad-hoc.');
    :v_vacias_tablas := :v_vacias_tablas + 1; :v_reporte := :v_reporte || rpad('SRI_INGRESOS_PRIMARIOS',35) || 'VACIA (0 filas)' || chr(10);
  else
    if l_conteo_ok = 'Y' then dbms_output.put_line('   Filas en tabla: ' || l_filas_tabla); end if;
    begin
      pkg_dm_enmascarar.p_mask_tab(p_esquema => :v_esquema, p_tabla => 'SRI_INGRESOS_PRIMARIOS', p_identificador => 'IDENTIFICADOR_IDENTIDAD', p_columna => 'IP_NIF_CIF');
      declare l_ejec_id number; l_filas number; begin
        begin select max(ejecucion_id) into l_ejec_id from tdm_ejecucion where esquema_objetivo = :v_esquema; exception when others then l_ejec_id := null; end;
        l_filas := null;
        if l_ejec_id is not null then
          begin select sum(filas_procesadas) into l_filas from tdm_mask_solicitud where ejecucion_id = l_ejec_id; exception when others then l_filas := null; end;
          if :v_ejec_min is null or l_ejec_id < :v_ejec_min then :v_ejec_min := l_ejec_id; end if;
          if :v_ejec_max is null or l_ejec_id > :v_ejec_max then :v_ejec_max := l_ejec_id; end if;
        end if;
        dbms_output.put_line('   OK  ejecucion_id=' || nvl(to_char(l_ejec_id),'?') || '  filas_procesadas=' || nvl(to_char(l_filas),'?'));
        :v_reporte := :v_reporte || rpad('SRI_INGRESOS_PRIMARIOS',35) || 'OK  ejec=' || nvl(to_char(l_ejec_id),'?') || ' filas=' || nvl(to_char(l_filas),'?') || chr(10);
      end;
      :v_ok_tablas := :v_ok_tablas + 1; :v_total_columnas := :v_total_columnas + 1;
    exception when others then
      l_err := replace(replace(substr(sqlerrm,1,300),chr(10),' '),chr(13),' ');
      dbms_output.put_line('   ERROR: ' || l_err);
      :v_reporte := :v_reporte || rpad('SRI_INGRESOS_PRIMARIOS',35) || 'ERROR ' || l_err || chr(10);
      :v_err_tablas := :v_err_tablas + 1;
    end;
  end if;
end;
/
declare
  l_filas_tabla number; l_conteo_ok varchar2(1) := 'Y'; l_err varchar2(400);
begin
  dbms_output.put_line('-> SRI2006.SRI_INGRESOS_PRIMARIOS_TRAZA (1 columna(s): IP_NIF_CIF)');
  begin
    execute immediate 'SELECT COUNT(*) FROM ' || dbms_assert.enquote_name(:v_esquema,false) || '.' || dbms_assert.enquote_name('SRI_INGRESOS_PRIMARIOS_TRAZA',false) into l_filas_tabla;
  exception when others then
    l_conteo_ok := 'N';
    dbms_output.put_line('   AVISO: no se pudo contar filas (' || replace(replace(substr(sqlerrm,1,200),chr(10),' '),chr(13),' ') || '); se intenta enmascarar igual.');
  end;
  if l_conteo_ok = 'Y' and l_filas_tabla = 0 then
    dbms_output.put_line('   OMITIDA: tabla vacia (0 filas) -- no se llamo a p_mask_tab, no se creo ejecucion ad-hoc.');
    :v_vacias_tablas := :v_vacias_tablas + 1; :v_reporte := :v_reporte || rpad('SRI_INGRESOS_PRIMARIOS_TRAZA',35) || 'VACIA (0 filas)' || chr(10);
  else
    if l_conteo_ok = 'Y' then dbms_output.put_line('   Filas en tabla: ' || l_filas_tabla); end if;
    begin
      pkg_dm_enmascarar.p_mask_tab(p_esquema => :v_esquema, p_tabla => 'SRI_INGRESOS_PRIMARIOS_TRAZA', p_identificador => 'IDENTIFICADOR_IDENTIDAD', p_columna => 'IP_NIF_CIF');
      declare l_ejec_id number; l_filas number; begin
        begin select max(ejecucion_id) into l_ejec_id from tdm_ejecucion where esquema_objetivo = :v_esquema; exception when others then l_ejec_id := null; end;
        l_filas := null;
        if l_ejec_id is not null then
          begin select sum(filas_procesadas) into l_filas from tdm_mask_solicitud where ejecucion_id = l_ejec_id; exception when others then l_filas := null; end;
          if :v_ejec_min is null or l_ejec_id < :v_ejec_min then :v_ejec_min := l_ejec_id; end if;
          if :v_ejec_max is null or l_ejec_id > :v_ejec_max then :v_ejec_max := l_ejec_id; end if;
        end if;
        dbms_output.put_line('   OK  ejecucion_id=' || nvl(to_char(l_ejec_id),'?') || '  filas_procesadas=' || nvl(to_char(l_filas),'?'));
        :v_reporte := :v_reporte || rpad('SRI_INGRESOS_PRIMARIOS_TRAZA',35) || 'OK  ejec=' || nvl(to_char(l_ejec_id),'?') || ' filas=' || nvl(to_char(l_filas),'?') || chr(10);
      end;
      :v_ok_tablas := :v_ok_tablas + 1; :v_total_columnas := :v_total_columnas + 1;
    exception when others then
      l_err := replace(replace(substr(sqlerrm,1,300),chr(10),' '),chr(13),' ');
      dbms_output.put_line('   ERROR: ' || l_err);
      :v_reporte := :v_reporte || rpad('SRI_INGRESOS_PRIMARIOS_TRAZA',35) || 'ERROR ' || l_err || chr(10);
      :v_err_tablas := :v_err_tablas + 1;
    end;
  end if;
end;
/
declare
  l_filas_tabla number; l_conteo_ok varchar2(1) := 'Y'; l_err varchar2(400);
begin
  dbms_output.put_line('-> SRI2006.SRI_INGRESOS_TEMPORALES (1 columna(s): IT_NIF)');
  begin
    execute immediate 'SELECT COUNT(*) FROM ' || dbms_assert.enquote_name(:v_esquema,false) || '.' || dbms_assert.enquote_name('SRI_INGRESOS_TEMPORALES',false) into l_filas_tabla;
  exception when others then
    l_conteo_ok := 'N';
    dbms_output.put_line('   AVISO: no se pudo contar filas (' || replace(replace(substr(sqlerrm,1,200),chr(10),' '),chr(13),' ') || '); se intenta enmascarar igual.');
  end;
  if l_conteo_ok = 'Y' and l_filas_tabla = 0 then
    dbms_output.put_line('   OMITIDA: tabla vacia (0 filas) -- no se llamo a p_mask_tab, no se creo ejecucion ad-hoc.');
    :v_vacias_tablas := :v_vacias_tablas + 1; :v_reporte := :v_reporte || rpad('SRI_INGRESOS_TEMPORALES',35) || 'VACIA (0 filas)' || chr(10);
  else
    if l_conteo_ok = 'Y' then dbms_output.put_line('   Filas en tabla: ' || l_filas_tabla); end if;
    begin
      pkg_dm_enmascarar.p_mask_tab(p_esquema => :v_esquema, p_tabla => 'SRI_INGRESOS_TEMPORALES', p_identificador => 'IDENTIFICADOR_IDENTIDAD', p_columna => 'IT_NIF');
      declare l_ejec_id number; l_filas number; begin
        begin select max(ejecucion_id) into l_ejec_id from tdm_ejecucion where esquema_objetivo = :v_esquema; exception when others then l_ejec_id := null; end;
        l_filas := null;
        if l_ejec_id is not null then
          begin select sum(filas_procesadas) into l_filas from tdm_mask_solicitud where ejecucion_id = l_ejec_id; exception when others then l_filas := null; end;
          if :v_ejec_min is null or l_ejec_id < :v_ejec_min then :v_ejec_min := l_ejec_id; end if;
          if :v_ejec_max is null or l_ejec_id > :v_ejec_max then :v_ejec_max := l_ejec_id; end if;
        end if;
        dbms_output.put_line('   OK  ejecucion_id=' || nvl(to_char(l_ejec_id),'?') || '  filas_procesadas=' || nvl(to_char(l_filas),'?'));
        :v_reporte := :v_reporte || rpad('SRI_INGRESOS_TEMPORALES',35) || 'OK  ejec=' || nvl(to_char(l_ejec_id),'?') || ' filas=' || nvl(to_char(l_filas),'?') || chr(10);
      end;
      :v_ok_tablas := :v_ok_tablas + 1; :v_total_columnas := :v_total_columnas + 1;
    exception when others then
      l_err := replace(replace(substr(sqlerrm,1,300),chr(10),' '),chr(13),' ');
      dbms_output.put_line('   ERROR: ' || l_err);
      :v_reporte := :v_reporte || rpad('SRI_INGRESOS_TEMPORALES',35) || 'ERROR ' || l_err || chr(10);
      :v_err_tablas := :v_err_tablas + 1;
    end;
  end if;
end;
/
declare
  l_filas_tabla number; l_conteo_ok varchar2(1) := 'Y'; l_err varchar2(400);
begin
  dbms_output.put_line('-> SRI2006.SRI_INSERTAR_LIQUIDACIONES (1 columna(s): IL_NIF_CIF)');
  begin
    execute immediate 'SELECT COUNT(*) FROM ' || dbms_assert.enquote_name(:v_esquema,false) || '.' || dbms_assert.enquote_name('SRI_INSERTAR_LIQUIDACIONES',false) into l_filas_tabla;
  exception when others then
    l_conteo_ok := 'N';
    dbms_output.put_line('   AVISO: no se pudo contar filas (' || replace(replace(substr(sqlerrm,1,200),chr(10),' '),chr(13),' ') || '); se intenta enmascarar igual.');
  end;
  if l_conteo_ok = 'Y' and l_filas_tabla = 0 then
    dbms_output.put_line('   OMITIDA: tabla vacia (0 filas) -- no se llamo a p_mask_tab, no se creo ejecucion ad-hoc.');
    :v_vacias_tablas := :v_vacias_tablas + 1; :v_reporte := :v_reporte || rpad('SRI_INSERTAR_LIQUIDACIONES',35) || 'VACIA (0 filas)' || chr(10);
  else
    if l_conteo_ok = 'Y' then dbms_output.put_line('   Filas en tabla: ' || l_filas_tabla); end if;
    begin
      pkg_dm_enmascarar.p_mask_tab(p_esquema => :v_esquema, p_tabla => 'SRI_INSERTAR_LIQUIDACIONES', p_identificador => 'IDENTIFICADOR_IDENTIDAD', p_columna => 'IL_NIF_CIF');
      declare l_ejec_id number; l_filas number; begin
        begin select max(ejecucion_id) into l_ejec_id from tdm_ejecucion where esquema_objetivo = :v_esquema; exception when others then l_ejec_id := null; end;
        l_filas := null;
        if l_ejec_id is not null then
          begin select sum(filas_procesadas) into l_filas from tdm_mask_solicitud where ejecucion_id = l_ejec_id; exception when others then l_filas := null; end;
          if :v_ejec_min is null or l_ejec_id < :v_ejec_min then :v_ejec_min := l_ejec_id; end if;
          if :v_ejec_max is null or l_ejec_id > :v_ejec_max then :v_ejec_max := l_ejec_id; end if;
        end if;
        dbms_output.put_line('   OK  ejecucion_id=' || nvl(to_char(l_ejec_id),'?') || '  filas_procesadas=' || nvl(to_char(l_filas),'?'));
        :v_reporte := :v_reporte || rpad('SRI_INSERTAR_LIQUIDACIONES',35) || 'OK  ejec=' || nvl(to_char(l_ejec_id),'?') || ' filas=' || nvl(to_char(l_filas),'?') || chr(10);
      end;
      :v_ok_tablas := :v_ok_tablas + 1; :v_total_columnas := :v_total_columnas + 1;
    exception when others then
      l_err := replace(replace(substr(sqlerrm,1,300),chr(10),' '),chr(13),' ');
      dbms_output.put_line('   ERROR: ' || l_err);
      :v_reporte := :v_reporte || rpad('SRI_INSERTAR_LIQUIDACIONES',35) || 'ERROR ' || l_err || chr(10);
      :v_err_tablas := :v_err_tablas + 1;
    end;
  end if;
end;
/
declare
  l_filas_tabla number; l_conteo_ok varchar2(1) := 'Y'; l_err varchar2(400);
begin
  dbms_output.put_line('-> SRI2006.SRI_INTERCAMBIO_NIF (2 columna(s): IT_NIF_NUEVO,IT_NIF_VIEJO)');
  begin
    execute immediate 'SELECT COUNT(*) FROM ' || dbms_assert.enquote_name(:v_esquema,false) || '.' || dbms_assert.enquote_name('SRI_INTERCAMBIO_NIF',false) into l_filas_tabla;
  exception when others then
    l_conteo_ok := 'N';
    dbms_output.put_line('   AVISO: no se pudo contar filas (' || replace(replace(substr(sqlerrm,1,200),chr(10),' '),chr(13),' ') || '); se intenta enmascarar igual.');
  end;
  if l_conteo_ok = 'Y' and l_filas_tabla = 0 then
    dbms_output.put_line('   OMITIDA: tabla vacia (0 filas) -- no se llamo a p_mask_tab, no se creo ejecucion ad-hoc.');
    :v_vacias_tablas := :v_vacias_tablas + 1; :v_reporte := :v_reporte || rpad('SRI_INTERCAMBIO_NIF',35) || 'VACIA (0 filas)' || chr(10);
  else
    if l_conteo_ok = 'Y' then dbms_output.put_line('   Filas en tabla: ' || l_filas_tabla); end if;
    begin
      pkg_dm_enmascarar.p_mask_tab(p_esquema => :v_esquema, p_tabla => 'SRI_INTERCAMBIO_NIF', p_identificador => 'IDENTIFICADOR_IDENTIDAD', p_columna => 'IT_NIF_NUEVO,IT_NIF_VIEJO');
      declare l_ejec_id number; l_filas number; begin
        begin select max(ejecucion_id) into l_ejec_id from tdm_ejecucion where esquema_objetivo = :v_esquema; exception when others then l_ejec_id := null; end;
        l_filas := null;
        if l_ejec_id is not null then
          begin select sum(filas_procesadas) into l_filas from tdm_mask_solicitud where ejecucion_id = l_ejec_id; exception when others then l_filas := null; end;
          if :v_ejec_min is null or l_ejec_id < :v_ejec_min then :v_ejec_min := l_ejec_id; end if;
          if :v_ejec_max is null or l_ejec_id > :v_ejec_max then :v_ejec_max := l_ejec_id; end if;
        end if;
        dbms_output.put_line('   OK  ejecucion_id=' || nvl(to_char(l_ejec_id),'?') || '  filas_procesadas=' || nvl(to_char(l_filas),'?'));
        :v_reporte := :v_reporte || rpad('SRI_INTERCAMBIO_NIF',35) || 'OK  ejec=' || nvl(to_char(l_ejec_id),'?') || ' filas=' || nvl(to_char(l_filas),'?') || chr(10);
      end;
      :v_ok_tablas := :v_ok_tablas + 1; :v_total_columnas := :v_total_columnas + 2;
    exception when others then
      l_err := replace(replace(substr(sqlerrm,1,300),chr(10),' '),chr(13),' ');
      dbms_output.put_line('   ERROR: ' || l_err);
      :v_reporte := :v_reporte || rpad('SRI_INTERCAMBIO_NIF',35) || 'ERROR ' || l_err || chr(10);
      :v_err_tablas := :v_err_tablas + 1;
    end;
  end if;
end;
/
declare
  l_filas_tabla number; l_conteo_ok varchar2(1) := 'Y'; l_err varchar2(400);
begin
  dbms_output.put_line('-> SRI2006.SRI_LIQUIDACION (1 columna(s): LI_NIF_CIF)');
  begin
    execute immediate 'SELECT COUNT(*) FROM ' || dbms_assert.enquote_name(:v_esquema,false) || '.' || dbms_assert.enquote_name('SRI_LIQUIDACION',false) into l_filas_tabla;
  exception when others then
    l_conteo_ok := 'N';
    dbms_output.put_line('   AVISO: no se pudo contar filas (' || replace(replace(substr(sqlerrm,1,200),chr(10),' '),chr(13),' ') || '); se intenta enmascarar igual.');
  end;
  if l_conteo_ok = 'Y' and l_filas_tabla = 0 then
    dbms_output.put_line('   OMITIDA: tabla vacia (0 filas) -- no se llamo a p_mask_tab, no se creo ejecucion ad-hoc.');
    :v_vacias_tablas := :v_vacias_tablas + 1; :v_reporte := :v_reporte || rpad('SRI_LIQUIDACION',35) || 'VACIA (0 filas)' || chr(10);
  else
    if l_conteo_ok = 'Y' then dbms_output.put_line('   Filas en tabla: ' || l_filas_tabla); end if;
    begin
      pkg_dm_enmascarar.p_mask_tab(p_esquema => :v_esquema, p_tabla => 'SRI_LIQUIDACION', p_identificador => 'IDENTIFICADOR_IDENTIDAD', p_columna => 'LI_NIF_CIF');
      declare l_ejec_id number; l_filas number; begin
        begin select max(ejecucion_id) into l_ejec_id from tdm_ejecucion where esquema_objetivo = :v_esquema; exception when others then l_ejec_id := null; end;
        l_filas := null;
        if l_ejec_id is not null then
          begin select sum(filas_procesadas) into l_filas from tdm_mask_solicitud where ejecucion_id = l_ejec_id; exception when others then l_filas := null; end;
          if :v_ejec_min is null or l_ejec_id < :v_ejec_min then :v_ejec_min := l_ejec_id; end if;
          if :v_ejec_max is null or l_ejec_id > :v_ejec_max then :v_ejec_max := l_ejec_id; end if;
        end if;
        dbms_output.put_line('   OK  ejecucion_id=' || nvl(to_char(l_ejec_id),'?') || '  filas_procesadas=' || nvl(to_char(l_filas),'?'));
        :v_reporte := :v_reporte || rpad('SRI_LIQUIDACION',35) || 'OK  ejec=' || nvl(to_char(l_ejec_id),'?') || ' filas=' || nvl(to_char(l_filas),'?') || chr(10);
      end;
      :v_ok_tablas := :v_ok_tablas + 1; :v_total_columnas := :v_total_columnas + 1;
    exception when others then
      l_err := replace(replace(substr(sqlerrm,1,300),chr(10),' '),chr(13),' ');
      dbms_output.put_line('   ERROR: ' || l_err);
      :v_reporte := :v_reporte || rpad('SRI_LIQUIDACION',35) || 'ERROR ' || l_err || chr(10);
      :v_err_tablas := :v_err_tablas + 1;
    end;
  end if;
end;
/
declare
  l_filas_tabla number; l_conteo_ok varchar2(1) := 'Y'; l_err varchar2(400);
begin
  dbms_output.put_line('-> SRI2006.SRI_LIQUIDACION_BORRAR (1 columna(s): LI_NIF_CIF)');
  begin
    execute immediate 'SELECT COUNT(*) FROM ' || dbms_assert.enquote_name(:v_esquema,false) || '.' || dbms_assert.enquote_name('SRI_LIQUIDACION_BORRAR',false) into l_filas_tabla;
  exception when others then
    l_conteo_ok := 'N';
    dbms_output.put_line('   AVISO: no se pudo contar filas (' || replace(replace(substr(sqlerrm,1,200),chr(10),' '),chr(13),' ') || '); se intenta enmascarar igual.');
  end;
  if l_conteo_ok = 'Y' and l_filas_tabla = 0 then
    dbms_output.put_line('   OMITIDA: tabla vacia (0 filas) -- no se llamo a p_mask_tab, no se creo ejecucion ad-hoc.');
    :v_vacias_tablas := :v_vacias_tablas + 1; :v_reporte := :v_reporte || rpad('SRI_LIQUIDACION_BORRAR',35) || 'VACIA (0 filas)' || chr(10);
  else
    if l_conteo_ok = 'Y' then dbms_output.put_line('   Filas en tabla: ' || l_filas_tabla); end if;
    begin
      pkg_dm_enmascarar.p_mask_tab(p_esquema => :v_esquema, p_tabla => 'SRI_LIQUIDACION_BORRAR', p_identificador => 'IDENTIFICADOR_IDENTIDAD', p_columna => 'LI_NIF_CIF');
      declare l_ejec_id number; l_filas number; begin
        begin select max(ejecucion_id) into l_ejec_id from tdm_ejecucion where esquema_objetivo = :v_esquema; exception when others then l_ejec_id := null; end;
        l_filas := null;
        if l_ejec_id is not null then
          begin select sum(filas_procesadas) into l_filas from tdm_mask_solicitud where ejecucion_id = l_ejec_id; exception when others then l_filas := null; end;
          if :v_ejec_min is null or l_ejec_id < :v_ejec_min then :v_ejec_min := l_ejec_id; end if;
          if :v_ejec_max is null or l_ejec_id > :v_ejec_max then :v_ejec_max := l_ejec_id; end if;
        end if;
        dbms_output.put_line('   OK  ejecucion_id=' || nvl(to_char(l_ejec_id),'?') || '  filas_procesadas=' || nvl(to_char(l_filas),'?'));
        :v_reporte := :v_reporte || rpad('SRI_LIQUIDACION_BORRAR',35) || 'OK  ejec=' || nvl(to_char(l_ejec_id),'?') || ' filas=' || nvl(to_char(l_filas),'?') || chr(10);
      end;
      :v_ok_tablas := :v_ok_tablas + 1; :v_total_columnas := :v_total_columnas + 1;
    exception when others then
      l_err := replace(replace(substr(sqlerrm,1,300),chr(10),' '),chr(13),' ');
      dbms_output.put_line('   ERROR: ' || l_err);
      :v_reporte := :v_reporte || rpad('SRI_LIQUIDACION_BORRAR',35) || 'ERROR ' || l_err || chr(10);
      :v_err_tablas := :v_err_tablas + 1;
    end;
  end if;
end;
/
declare
  l_filas_tabla number; l_conteo_ok varchar2(1) := 'Y'; l_err varchar2(400);
begin
  dbms_output.put_line('-> SRI2006.SRI_LIQUIDACION_BORRAR2 (1 columna(s): LI_NIF_CIF)');
  begin
    execute immediate 'SELECT COUNT(*) FROM ' || dbms_assert.enquote_name(:v_esquema,false) || '.' || dbms_assert.enquote_name('SRI_LIQUIDACION_BORRAR2',false) into l_filas_tabla;
  exception when others then
    l_conteo_ok := 'N';
    dbms_output.put_line('   AVISO: no se pudo contar filas (' || replace(replace(substr(sqlerrm,1,200),chr(10),' '),chr(13),' ') || '); se intenta enmascarar igual.');
  end;
  if l_conteo_ok = 'Y' and l_filas_tabla = 0 then
    dbms_output.put_line('   OMITIDA: tabla vacia (0 filas) -- no se llamo a p_mask_tab, no se creo ejecucion ad-hoc.');
    :v_vacias_tablas := :v_vacias_tablas + 1; :v_reporte := :v_reporte || rpad('SRI_LIQUIDACION_BORRAR2',35) || 'VACIA (0 filas)' || chr(10);
  else
    if l_conteo_ok = 'Y' then dbms_output.put_line('   Filas en tabla: ' || l_filas_tabla); end if;
    begin
      pkg_dm_enmascarar.p_mask_tab(p_esquema => :v_esquema, p_tabla => 'SRI_LIQUIDACION_BORRAR2', p_identificador => 'IDENTIFICADOR_IDENTIDAD', p_columna => 'LI_NIF_CIF');
      declare l_ejec_id number; l_filas number; begin
        begin select max(ejecucion_id) into l_ejec_id from tdm_ejecucion where esquema_objetivo = :v_esquema; exception when others then l_ejec_id := null; end;
        l_filas := null;
        if l_ejec_id is not null then
          begin select sum(filas_procesadas) into l_filas from tdm_mask_solicitud where ejecucion_id = l_ejec_id; exception when others then l_filas := null; end;
          if :v_ejec_min is null or l_ejec_id < :v_ejec_min then :v_ejec_min := l_ejec_id; end if;
          if :v_ejec_max is null or l_ejec_id > :v_ejec_max then :v_ejec_max := l_ejec_id; end if;
        end if;
        dbms_output.put_line('   OK  ejecucion_id=' || nvl(to_char(l_ejec_id),'?') || '  filas_procesadas=' || nvl(to_char(l_filas),'?'));
        :v_reporte := :v_reporte || rpad('SRI_LIQUIDACION_BORRAR2',35) || 'OK  ejec=' || nvl(to_char(l_ejec_id),'?') || ' filas=' || nvl(to_char(l_filas),'?') || chr(10);
      end;
      :v_ok_tablas := :v_ok_tablas + 1; :v_total_columnas := :v_total_columnas + 1;
    exception when others then
      l_err := replace(replace(substr(sqlerrm,1,300),chr(10),' '),chr(13),' ');
      dbms_output.put_line('   ERROR: ' || l_err);
      :v_reporte := :v_reporte || rpad('SRI_LIQUIDACION_BORRAR2',35) || 'ERROR ' || l_err || chr(10);
      :v_err_tablas := :v_err_tablas + 1;
    end;
  end if;
end;
/
declare
  l_filas_tabla number; l_conteo_ok varchar2(1) := 'Y'; l_err varchar2(400);
begin
  dbms_output.put_line('-> SRI2006.SRI_LIQUIDACION_TRAZA (1 columna(s): LI_NIF_CIF)');
  begin
    execute immediate 'SELECT COUNT(*) FROM ' || dbms_assert.enquote_name(:v_esquema,false) || '.' || dbms_assert.enquote_name('SRI_LIQUIDACION_TRAZA',false) into l_filas_tabla;
  exception when others then
    l_conteo_ok := 'N';
    dbms_output.put_line('   AVISO: no se pudo contar filas (' || replace(replace(substr(sqlerrm,1,200),chr(10),' '),chr(13),' ') || '); se intenta enmascarar igual.');
  end;
  if l_conteo_ok = 'Y' and l_filas_tabla = 0 then
    dbms_output.put_line('   OMITIDA: tabla vacia (0 filas) -- no se llamo a p_mask_tab, no se creo ejecucion ad-hoc.');
    :v_vacias_tablas := :v_vacias_tablas + 1; :v_reporte := :v_reporte || rpad('SRI_LIQUIDACION_TRAZA',35) || 'VACIA (0 filas)' || chr(10);
  else
    if l_conteo_ok = 'Y' then dbms_output.put_line('   Filas en tabla: ' || l_filas_tabla); end if;
    begin
      pkg_dm_enmascarar.p_mask_tab(p_esquema => :v_esquema, p_tabla => 'SRI_LIQUIDACION_TRAZA', p_identificador => 'IDENTIFICADOR_IDENTIDAD', p_columna => 'LI_NIF_CIF');
      declare l_ejec_id number; l_filas number; begin
        begin select max(ejecucion_id) into l_ejec_id from tdm_ejecucion where esquema_objetivo = :v_esquema; exception when others then l_ejec_id := null; end;
        l_filas := null;
        if l_ejec_id is not null then
          begin select sum(filas_procesadas) into l_filas from tdm_mask_solicitud where ejecucion_id = l_ejec_id; exception when others then l_filas := null; end;
          if :v_ejec_min is null or l_ejec_id < :v_ejec_min then :v_ejec_min := l_ejec_id; end if;
          if :v_ejec_max is null or l_ejec_id > :v_ejec_max then :v_ejec_max := l_ejec_id; end if;
        end if;
        dbms_output.put_line('   OK  ejecucion_id=' || nvl(to_char(l_ejec_id),'?') || '  filas_procesadas=' || nvl(to_char(l_filas),'?'));
        :v_reporte := :v_reporte || rpad('SRI_LIQUIDACION_TRAZA',35) || 'OK  ejec=' || nvl(to_char(l_ejec_id),'?') || ' filas=' || nvl(to_char(l_filas),'?') || chr(10);
      end;
      :v_ok_tablas := :v_ok_tablas + 1; :v_total_columnas := :v_total_columnas + 1;
    exception when others then
      l_err := replace(replace(substr(sqlerrm,1,300),chr(10),' '),chr(13),' ');
      dbms_output.put_line('   ERROR: ' || l_err);
      :v_reporte := :v_reporte || rpad('SRI_LIQUIDACION_TRAZA',35) || 'ERROR ' || l_err || chr(10);
      :v_err_tablas := :v_err_tablas + 1;
    end;
  end if;
end;
/
declare
  l_filas_tabla number; l_conteo_ok varchar2(1) := 'Y'; l_err varchar2(400);
begin
  dbms_output.put_line('-> SRI2006.SRI_RESOLUCION_COMPENSACION (1 columna(s): RS_NIF_CIF)');
  begin
    execute immediate 'SELECT COUNT(*) FROM ' || dbms_assert.enquote_name(:v_esquema,false) || '.' || dbms_assert.enquote_name('SRI_RESOLUCION_COMPENSACION',false) into l_filas_tabla;
  exception when others then
    l_conteo_ok := 'N';
    dbms_output.put_line('   AVISO: no se pudo contar filas (' || replace(replace(substr(sqlerrm,1,200),chr(10),' '),chr(13),' ') || '); se intenta enmascarar igual.');
  end;
  if l_conteo_ok = 'Y' and l_filas_tabla = 0 then
    dbms_output.put_line('   OMITIDA: tabla vacia (0 filas) -- no se llamo a p_mask_tab, no se creo ejecucion ad-hoc.');
    :v_vacias_tablas := :v_vacias_tablas + 1; :v_reporte := :v_reporte || rpad('SRI_RESOLUCION_COMPENSACION',35) || 'VACIA (0 filas)' || chr(10);
  else
    if l_conteo_ok = 'Y' then dbms_output.put_line('   Filas en tabla: ' || l_filas_tabla); end if;
    begin
      pkg_dm_enmascarar.p_mask_tab(p_esquema => :v_esquema, p_tabla => 'SRI_RESOLUCION_COMPENSACION', p_identificador => 'IDENTIFICADOR_IDENTIDAD', p_columna => 'RS_NIF_CIF');
      declare l_ejec_id number; l_filas number; begin
        begin select max(ejecucion_id) into l_ejec_id from tdm_ejecucion where esquema_objetivo = :v_esquema; exception when others then l_ejec_id := null; end;
        l_filas := null;
        if l_ejec_id is not null then
          begin select sum(filas_procesadas) into l_filas from tdm_mask_solicitud where ejecucion_id = l_ejec_id; exception when others then l_filas := null; end;
          if :v_ejec_min is null or l_ejec_id < :v_ejec_min then :v_ejec_min := l_ejec_id; end if;
          if :v_ejec_max is null or l_ejec_id > :v_ejec_max then :v_ejec_max := l_ejec_id; end if;
        end if;
        dbms_output.put_line('   OK  ejecucion_id=' || nvl(to_char(l_ejec_id),'?') || '  filas_procesadas=' || nvl(to_char(l_filas),'?'));
        :v_reporte := :v_reporte || rpad('SRI_RESOLUCION_COMPENSACION',35) || 'OK  ejec=' || nvl(to_char(l_ejec_id),'?') || ' filas=' || nvl(to_char(l_filas),'?') || chr(10);
      end;
      :v_ok_tablas := :v_ok_tablas + 1; :v_total_columnas := :v_total_columnas + 1;
    exception when others then
      l_err := replace(replace(substr(sqlerrm,1,300),chr(10),' '),chr(13),' ');
      dbms_output.put_line('   ERROR: ' || l_err);
      :v_reporte := :v_reporte || rpad('SRI_RESOLUCION_COMPENSACION',35) || 'ERROR ' || l_err || chr(10);
      :v_err_tablas := :v_err_tablas + 1;
    end;
  end if;
end;
/
declare
  l_filas_tabla number; l_conteo_ok varchar2(1) := 'Y'; l_err varchar2(400);
begin
  dbms_output.put_line('-> SRI2006.SRI_TIPO_DEUDOR (1 columna(s): TD_NIF_CIF)');
  begin
    execute immediate 'SELECT COUNT(*) FROM ' || dbms_assert.enquote_name(:v_esquema,false) || '.' || dbms_assert.enquote_name('SRI_TIPO_DEUDOR',false) into l_filas_tabla;
  exception when others then
    l_conteo_ok := 'N';
    dbms_output.put_line('   AVISO: no se pudo contar filas (' || replace(replace(substr(sqlerrm,1,200),chr(10),' '),chr(13),' ') || '); se intenta enmascarar igual.');
  end;
  if l_conteo_ok = 'Y' and l_filas_tabla = 0 then
    dbms_output.put_line('   OMITIDA: tabla vacia (0 filas) -- no se llamo a p_mask_tab, no se creo ejecucion ad-hoc.');
    :v_vacias_tablas := :v_vacias_tablas + 1; :v_reporte := :v_reporte || rpad('SRI_TIPO_DEUDOR',35) || 'VACIA (0 filas)' || chr(10);
  else
    if l_conteo_ok = 'Y' then dbms_output.put_line('   Filas en tabla: ' || l_filas_tabla); end if;
    begin
      pkg_dm_enmascarar.p_mask_tab(p_esquema => :v_esquema, p_tabla => 'SRI_TIPO_DEUDOR', p_identificador => 'IDENTIFICADOR_IDENTIDAD', p_columna => 'TD_NIF_CIF');
      declare l_ejec_id number; l_filas number; begin
        begin select max(ejecucion_id) into l_ejec_id from tdm_ejecucion where esquema_objetivo = :v_esquema; exception when others then l_ejec_id := null; end;
        l_filas := null;
        if l_ejec_id is not null then
          begin select sum(filas_procesadas) into l_filas from tdm_mask_solicitud where ejecucion_id = l_ejec_id; exception when others then l_filas := null; end;
          if :v_ejec_min is null or l_ejec_id < :v_ejec_min then :v_ejec_min := l_ejec_id; end if;
          if :v_ejec_max is null or l_ejec_id > :v_ejec_max then :v_ejec_max := l_ejec_id; end if;
        end if;
        dbms_output.put_line('   OK  ejecucion_id=' || nvl(to_char(l_ejec_id),'?') || '  filas_procesadas=' || nvl(to_char(l_filas),'?'));
        :v_reporte := :v_reporte || rpad('SRI_TIPO_DEUDOR',35) || 'OK  ejec=' || nvl(to_char(l_ejec_id),'?') || ' filas=' || nvl(to_char(l_filas),'?') || chr(10);
      end;
      :v_ok_tablas := :v_ok_tablas + 1; :v_total_columnas := :v_total_columnas + 1;
    exception when others then
      l_err := replace(replace(substr(sqlerrm,1,300),chr(10),' '),chr(13),' ');
      dbms_output.put_line('   ERROR: ' || l_err);
      :v_reporte := :v_reporte || rpad('SRI_TIPO_DEUDOR',35) || 'ERROR ' || l_err || chr(10);
      :v_err_tablas := :v_err_tablas + 1;
    end;
  end if;
end;
/
declare
  l_filas_tabla number; l_conteo_ok varchar2(1) := 'Y'; l_err varchar2(400);
begin
  dbms_output.put_line('-> SRI2006.TMP_CONSULTA_FRACC (1 columna(s): DT_NIF)');
  begin
    execute immediate 'SELECT COUNT(*) FROM ' || dbms_assert.enquote_name(:v_esquema,false) || '.' || dbms_assert.enquote_name('TMP_CONSULTA_FRACC',false) into l_filas_tabla;
  exception when others then
    l_conteo_ok := 'N';
    dbms_output.put_line('   AVISO: no se pudo contar filas (' || replace(replace(substr(sqlerrm,1,200),chr(10),' '),chr(13),' ') || '); se intenta enmascarar igual.');
  end;
  if l_conteo_ok = 'Y' and l_filas_tabla = 0 then
    dbms_output.put_line('   OMITIDA: tabla vacia (0 filas) -- no se llamo a p_mask_tab, no se creo ejecucion ad-hoc.');
    :v_vacias_tablas := :v_vacias_tablas + 1; :v_reporte := :v_reporte || rpad('TMP_CONSULTA_FRACC',35) || 'VACIA (0 filas)' || chr(10);
  else
    if l_conteo_ok = 'Y' then dbms_output.put_line('   Filas en tabla: ' || l_filas_tabla); end if;
    begin
      pkg_dm_enmascarar.p_mask_tab(p_esquema => :v_esquema, p_tabla => 'TMP_CONSULTA_FRACC', p_identificador => 'IDENTIFICADOR_IDENTIDAD', p_columna => 'DT_NIF');
      declare l_ejec_id number; l_filas number; begin
        begin select max(ejecucion_id) into l_ejec_id from tdm_ejecucion where esquema_objetivo = :v_esquema; exception when others then l_ejec_id := null; end;
        l_filas := null;
        if l_ejec_id is not null then
          begin select sum(filas_procesadas) into l_filas from tdm_mask_solicitud where ejecucion_id = l_ejec_id; exception when others then l_filas := null; end;
          if :v_ejec_min is null or l_ejec_id < :v_ejec_min then :v_ejec_min := l_ejec_id; end if;
          if :v_ejec_max is null or l_ejec_id > :v_ejec_max then :v_ejec_max := l_ejec_id; end if;
        end if;
        dbms_output.put_line('   OK  ejecucion_id=' || nvl(to_char(l_ejec_id),'?') || '  filas_procesadas=' || nvl(to_char(l_filas),'?'));
        :v_reporte := :v_reporte || rpad('TMP_CONSULTA_FRACC',35) || 'OK  ejec=' || nvl(to_char(l_ejec_id),'?') || ' filas=' || nvl(to_char(l_filas),'?') || chr(10);
      end;
      :v_ok_tablas := :v_ok_tablas + 1; :v_total_columnas := :v_total_columnas + 1;
    exception when others then
      l_err := replace(replace(substr(sqlerrm,1,300),chr(10),' '),chr(13),' ');
      dbms_output.put_line('   ERROR: ' || l_err);
      :v_reporte := :v_reporte || rpad('TMP_CONSULTA_FRACC',35) || 'ERROR ' || l_err || chr(10);
      :v_err_tablas := :v_err_tablas + 1;
    end;
  end if;
end;
/
declare
  l_filas_tabla number; l_conteo_ok varchar2(1) := 'Y'; l_err varchar2(400);
begin
  dbms_output.put_line('-> SRI2006.TMP_COPIA_INFORME_GESTION (1 columna(s): IG_NIF_CIF)');
  begin
    execute immediate 'SELECT COUNT(*) FROM ' || dbms_assert.enquote_name(:v_esquema,false) || '.' || dbms_assert.enquote_name('TMP_COPIA_INFORME_GESTION',false) into l_filas_tabla;
  exception when others then
    l_conteo_ok := 'N';
    dbms_output.put_line('   AVISO: no se pudo contar filas (' || replace(replace(substr(sqlerrm,1,200),chr(10),' '),chr(13),' ') || '); se intenta enmascarar igual.');
  end;
  if l_conteo_ok = 'Y' and l_filas_tabla = 0 then
    dbms_output.put_line('   OMITIDA: tabla vacia (0 filas) -- no se llamo a p_mask_tab, no se creo ejecucion ad-hoc.');
    :v_vacias_tablas := :v_vacias_tablas + 1; :v_reporte := :v_reporte || rpad('TMP_COPIA_INFORME_GESTION',35) || 'VACIA (0 filas)' || chr(10);
  else
    if l_conteo_ok = 'Y' then dbms_output.put_line('   Filas en tabla: ' || l_filas_tabla); end if;
    begin
      pkg_dm_enmascarar.p_mask_tab(p_esquema => :v_esquema, p_tabla => 'TMP_COPIA_INFORME_GESTION', p_identificador => 'IDENTIFICADOR_IDENTIDAD', p_columna => 'IG_NIF_CIF');
      declare l_ejec_id number; l_filas number; begin
        begin select max(ejecucion_id) into l_ejec_id from tdm_ejecucion where esquema_objetivo = :v_esquema; exception when others then l_ejec_id := null; end;
        l_filas := null;
        if l_ejec_id is not null then
          begin select sum(filas_procesadas) into l_filas from tdm_mask_solicitud where ejecucion_id = l_ejec_id; exception when others then l_filas := null; end;
          if :v_ejec_min is null or l_ejec_id < :v_ejec_min then :v_ejec_min := l_ejec_id; end if;
          if :v_ejec_max is null or l_ejec_id > :v_ejec_max then :v_ejec_max := l_ejec_id; end if;
        end if;
        dbms_output.put_line('   OK  ejecucion_id=' || nvl(to_char(l_ejec_id),'?') || '  filas_procesadas=' || nvl(to_char(l_filas),'?'));
        :v_reporte := :v_reporte || rpad('TMP_COPIA_INFORME_GESTION',35) || 'OK  ejec=' || nvl(to_char(l_ejec_id),'?') || ' filas=' || nvl(to_char(l_filas),'?') || chr(10);
      end;
      :v_ok_tablas := :v_ok_tablas + 1; :v_total_columnas := :v_total_columnas + 1;
    exception when others then
      l_err := replace(replace(substr(sqlerrm,1,300),chr(10),' '),chr(13),' ');
      dbms_output.put_line('   ERROR: ' || l_err);
      :v_reporte := :v_reporte || rpad('TMP_COPIA_INFORME_GESTION',35) || 'ERROR ' || l_err || chr(10);
      :v_err_tablas := :v_err_tablas + 1;
    end;
  end if;
end;
/
declare
  l_filas_tabla number; l_conteo_ok varchar2(1) := 'Y'; l_err varchar2(400);
begin
  dbms_output.put_line('-> SRI2006.TMP_CRUCE_FRACC (1 columna(s): DT_NIF)');
  begin
    execute immediate 'SELECT COUNT(*) FROM ' || dbms_assert.enquote_name(:v_esquema,false) || '.' || dbms_assert.enquote_name('TMP_CRUCE_FRACC',false) into l_filas_tabla;
  exception when others then
    l_conteo_ok := 'N';
    dbms_output.put_line('   AVISO: no se pudo contar filas (' || replace(replace(substr(sqlerrm,1,200),chr(10),' '),chr(13),' ') || '); se intenta enmascarar igual.');
  end;
  if l_conteo_ok = 'Y' and l_filas_tabla = 0 then
    dbms_output.put_line('   OMITIDA: tabla vacia (0 filas) -- no se llamo a p_mask_tab, no se creo ejecucion ad-hoc.');
    :v_vacias_tablas := :v_vacias_tablas + 1; :v_reporte := :v_reporte || rpad('TMP_CRUCE_FRACC',35) || 'VACIA (0 filas)' || chr(10);
  else
    if l_conteo_ok = 'Y' then dbms_output.put_line('   Filas en tabla: ' || l_filas_tabla); end if;
    begin
      pkg_dm_enmascarar.p_mask_tab(p_esquema => :v_esquema, p_tabla => 'TMP_CRUCE_FRACC', p_identificador => 'IDENTIFICADOR_IDENTIDAD', p_columna => 'DT_NIF');
      declare l_ejec_id number; l_filas number; begin
        begin select max(ejecucion_id) into l_ejec_id from tdm_ejecucion where esquema_objetivo = :v_esquema; exception when others then l_ejec_id := null; end;
        l_filas := null;
        if l_ejec_id is not null then
          begin select sum(filas_procesadas) into l_filas from tdm_mask_solicitud where ejecucion_id = l_ejec_id; exception when others then l_filas := null; end;
          if :v_ejec_min is null or l_ejec_id < :v_ejec_min then :v_ejec_min := l_ejec_id; end if;
          if :v_ejec_max is null or l_ejec_id > :v_ejec_max then :v_ejec_max := l_ejec_id; end if;
        end if;
        dbms_output.put_line('   OK  ejecucion_id=' || nvl(to_char(l_ejec_id),'?') || '  filas_procesadas=' || nvl(to_char(l_filas),'?'));
        :v_reporte := :v_reporte || rpad('TMP_CRUCE_FRACC',35) || 'OK  ejec=' || nvl(to_char(l_ejec_id),'?') || ' filas=' || nvl(to_char(l_filas),'?') || chr(10);
      end;
      :v_ok_tablas := :v_ok_tablas + 1; :v_total_columnas := :v_total_columnas + 1;
    exception when others then
      l_err := replace(replace(substr(sqlerrm,1,300),chr(10),' '),chr(13),' ');
      dbms_output.put_line('   ERROR: ' || l_err);
      :v_reporte := :v_reporte || rpad('TMP_CRUCE_FRACC',35) || 'ERROR ' || l_err || chr(10);
      :v_err_tablas := :v_err_tablas + 1;
    end;
  end if;
end;
/
declare
  l_filas_tabla number; l_conteo_ok varchar2(1) := 'Y'; l_err varchar2(400);
begin
  dbms_output.put_line('-> SRI2006.TMP_CRUCE_FRACC2 (1 columna(s): DT_NIF)');
  begin
    execute immediate 'SELECT COUNT(*) FROM ' || dbms_assert.enquote_name(:v_esquema,false) || '.' || dbms_assert.enquote_name('TMP_CRUCE_FRACC2',false) into l_filas_tabla;
  exception when others then
    l_conteo_ok := 'N';
    dbms_output.put_line('   AVISO: no se pudo contar filas (' || replace(replace(substr(sqlerrm,1,200),chr(10),' '),chr(13),' ') || '); se intenta enmascarar igual.');
  end;
  if l_conteo_ok = 'Y' and l_filas_tabla = 0 then
    dbms_output.put_line('   OMITIDA: tabla vacia (0 filas) -- no se llamo a p_mask_tab, no se creo ejecucion ad-hoc.');
    :v_vacias_tablas := :v_vacias_tablas + 1; :v_reporte := :v_reporte || rpad('TMP_CRUCE_FRACC2',35) || 'VACIA (0 filas)' || chr(10);
  else
    if l_conteo_ok = 'Y' then dbms_output.put_line('   Filas en tabla: ' || l_filas_tabla); end if;
    begin
      pkg_dm_enmascarar.p_mask_tab(p_esquema => :v_esquema, p_tabla => 'TMP_CRUCE_FRACC2', p_identificador => 'IDENTIFICADOR_IDENTIDAD', p_columna => 'DT_NIF');
      declare l_ejec_id number; l_filas number; begin
        begin select max(ejecucion_id) into l_ejec_id from tdm_ejecucion where esquema_objetivo = :v_esquema; exception when others then l_ejec_id := null; end;
        l_filas := null;
        if l_ejec_id is not null then
          begin select sum(filas_procesadas) into l_filas from tdm_mask_solicitud where ejecucion_id = l_ejec_id; exception when others then l_filas := null; end;
          if :v_ejec_min is null or l_ejec_id < :v_ejec_min then :v_ejec_min := l_ejec_id; end if;
          if :v_ejec_max is null or l_ejec_id > :v_ejec_max then :v_ejec_max := l_ejec_id; end if;
        end if;
        dbms_output.put_line('   OK  ejecucion_id=' || nvl(to_char(l_ejec_id),'?') || '  filas_procesadas=' || nvl(to_char(l_filas),'?'));
        :v_reporte := :v_reporte || rpad('TMP_CRUCE_FRACC2',35) || 'OK  ejec=' || nvl(to_char(l_ejec_id),'?') || ' filas=' || nvl(to_char(l_filas),'?') || chr(10);
      end;
      :v_ok_tablas := :v_ok_tablas + 1; :v_total_columnas := :v_total_columnas + 1;
    exception when others then
      l_err := replace(replace(substr(sqlerrm,1,300),chr(10),' '),chr(13),' ');
      dbms_output.put_line('   ERROR: ' || l_err);
      :v_reporte := :v_reporte || rpad('TMP_CRUCE_FRACC2',35) || 'ERROR ' || l_err || chr(10);
      :v_err_tablas := :v_err_tablas + 1;
    end;
  end if;
end;
/
declare
  l_filas_tabla number; l_conteo_ok varchar2(1) := 'Y'; l_err varchar2(400);
begin
  dbms_output.put_line('-> SRI2006.TMP_CUADRE_EJERCICIO (1 columna(s): LI_NIF_CIF)');
  begin
    execute immediate 'SELECT COUNT(*) FROM ' || dbms_assert.enquote_name(:v_esquema,false) || '.' || dbms_assert.enquote_name('TMP_CUADRE_EJERCICIO',false) into l_filas_tabla;
  exception when others then
    l_conteo_ok := 'N';
    dbms_output.put_line('   AVISO: no se pudo contar filas (' || replace(replace(substr(sqlerrm,1,200),chr(10),' '),chr(13),' ') || '); se intenta enmascarar igual.');
  end;
  if l_conteo_ok = 'Y' and l_filas_tabla = 0 then
    dbms_output.put_line('   OMITIDA: tabla vacia (0 filas) -- no se llamo a p_mask_tab, no se creo ejecucion ad-hoc.');
    :v_vacias_tablas := :v_vacias_tablas + 1; :v_reporte := :v_reporte || rpad('TMP_CUADRE_EJERCICIO',35) || 'VACIA (0 filas)' || chr(10);
  else
    if l_conteo_ok = 'Y' then dbms_output.put_line('   Filas en tabla: ' || l_filas_tabla); end if;
    begin
      pkg_dm_enmascarar.p_mask_tab(p_esquema => :v_esquema, p_tabla => 'TMP_CUADRE_EJERCICIO', p_identificador => 'IDENTIFICADOR_IDENTIDAD', p_columna => 'LI_NIF_CIF');
      declare l_ejec_id number; l_filas number; begin
        begin select max(ejecucion_id) into l_ejec_id from tdm_ejecucion where esquema_objetivo = :v_esquema; exception when others then l_ejec_id := null; end;
        l_filas := null;
        if l_ejec_id is not null then
          begin select sum(filas_procesadas) into l_filas from tdm_mask_solicitud where ejecucion_id = l_ejec_id; exception when others then l_filas := null; end;
          if :v_ejec_min is null or l_ejec_id < :v_ejec_min then :v_ejec_min := l_ejec_id; end if;
          if :v_ejec_max is null or l_ejec_id > :v_ejec_max then :v_ejec_max := l_ejec_id; end if;
        end if;
        dbms_output.put_line('   OK  ejecucion_id=' || nvl(to_char(l_ejec_id),'?') || '  filas_procesadas=' || nvl(to_char(l_filas),'?'));
        :v_reporte := :v_reporte || rpad('TMP_CUADRE_EJERCICIO',35) || 'OK  ejec=' || nvl(to_char(l_ejec_id),'?') || ' filas=' || nvl(to_char(l_filas),'?') || chr(10);
      end;
      :v_ok_tablas := :v_ok_tablas + 1; :v_total_columnas := :v_total_columnas + 1;
    exception when others then
      l_err := replace(replace(substr(sqlerrm,1,300),chr(10),' '),chr(13),' ');
      dbms_output.put_line('   ERROR: ' || l_err);
      :v_reporte := :v_reporte || rpad('TMP_CUADRE_EJERCICIO',35) || 'ERROR ' || l_err || chr(10);
      :v_err_tablas := :v_err_tablas + 1;
    end;
  end if;
end;
/
declare
  l_filas_tabla number; l_conteo_ok varchar2(1) := 'Y'; l_err varchar2(400);
begin
  dbms_output.put_line('-> SRI2006.TMP_CUADRE_EJERCICIO2 (1 columna(s): LI_NIF_CIF)');
  begin
    execute immediate 'SELECT COUNT(*) FROM ' || dbms_assert.enquote_name(:v_esquema,false) || '.' || dbms_assert.enquote_name('TMP_CUADRE_EJERCICIO2',false) into l_filas_tabla;
  exception when others then
    l_conteo_ok := 'N';
    dbms_output.put_line('   AVISO: no se pudo contar filas (' || replace(replace(substr(sqlerrm,1,200),chr(10),' '),chr(13),' ') || '); se intenta enmascarar igual.');
  end;
  if l_conteo_ok = 'Y' and l_filas_tabla = 0 then
    dbms_output.put_line('   OMITIDA: tabla vacia (0 filas) -- no se llamo a p_mask_tab, no se creo ejecucion ad-hoc.');
    :v_vacias_tablas := :v_vacias_tablas + 1; :v_reporte := :v_reporte || rpad('TMP_CUADRE_EJERCICIO2',35) || 'VACIA (0 filas)' || chr(10);
  else
    if l_conteo_ok = 'Y' then dbms_output.put_line('   Filas en tabla: ' || l_filas_tabla); end if;
    begin
      pkg_dm_enmascarar.p_mask_tab(p_esquema => :v_esquema, p_tabla => 'TMP_CUADRE_EJERCICIO2', p_identificador => 'IDENTIFICADOR_IDENTIDAD', p_columna => 'LI_NIF_CIF');
      declare l_ejec_id number; l_filas number; begin
        begin select max(ejecucion_id) into l_ejec_id from tdm_ejecucion where esquema_objetivo = :v_esquema; exception when others then l_ejec_id := null; end;
        l_filas := null;
        if l_ejec_id is not null then
          begin select sum(filas_procesadas) into l_filas from tdm_mask_solicitud where ejecucion_id = l_ejec_id; exception when others then l_filas := null; end;
          if :v_ejec_min is null or l_ejec_id < :v_ejec_min then :v_ejec_min := l_ejec_id; end if;
          if :v_ejec_max is null or l_ejec_id > :v_ejec_max then :v_ejec_max := l_ejec_id; end if;
        end if;
        dbms_output.put_line('   OK  ejecucion_id=' || nvl(to_char(l_ejec_id),'?') || '  filas_procesadas=' || nvl(to_char(l_filas),'?'));
        :v_reporte := :v_reporte || rpad('TMP_CUADRE_EJERCICIO2',35) || 'OK  ejec=' || nvl(to_char(l_ejec_id),'?') || ' filas=' || nvl(to_char(l_filas),'?') || chr(10);
      end;
      :v_ok_tablas := :v_ok_tablas + 1; :v_total_columnas := :v_total_columnas + 1;
    exception when others then
      l_err := replace(replace(substr(sqlerrm,1,300),chr(10),' '),chr(13),' ');
      dbms_output.put_line('   ERROR: ' || l_err);
      :v_reporte := :v_reporte || rpad('TMP_CUADRE_EJERCICIO2',35) || 'ERROR ' || l_err || chr(10);
      :v_err_tablas := :v_err_tablas + 1;
    end;
  end if;
end;
/
declare
  l_filas_tabla number; l_conteo_ok varchar2(1) := 'Y'; l_err varchar2(400);
begin
  dbms_output.put_line('-> SRI2006.TMP_CUADRE_EJERCICIO3 (1 columna(s): LI_NIF_CIF)');
  begin
    execute immediate 'SELECT COUNT(*) FROM ' || dbms_assert.enquote_name(:v_esquema,false) || '.' || dbms_assert.enquote_name('TMP_CUADRE_EJERCICIO3',false) into l_filas_tabla;
  exception when others then
    l_conteo_ok := 'N';
    dbms_output.put_line('   AVISO: no se pudo contar filas (' || replace(replace(substr(sqlerrm,1,200),chr(10),' '),chr(13),' ') || '); se intenta enmascarar igual.');
  end;
  if l_conteo_ok = 'Y' and l_filas_tabla = 0 then
    dbms_output.put_line('   OMITIDA: tabla vacia (0 filas) -- no se llamo a p_mask_tab, no se creo ejecucion ad-hoc.');
    :v_vacias_tablas := :v_vacias_tablas + 1; :v_reporte := :v_reporte || rpad('TMP_CUADRE_EJERCICIO3',35) || 'VACIA (0 filas)' || chr(10);
  else
    if l_conteo_ok = 'Y' then dbms_output.put_line('   Filas en tabla: ' || l_filas_tabla); end if;
    begin
      pkg_dm_enmascarar.p_mask_tab(p_esquema => :v_esquema, p_tabla => 'TMP_CUADRE_EJERCICIO3', p_identificador => 'IDENTIFICADOR_IDENTIDAD', p_columna => 'LI_NIF_CIF');
      declare l_ejec_id number; l_filas number; begin
        begin select max(ejecucion_id) into l_ejec_id from tdm_ejecucion where esquema_objetivo = :v_esquema; exception when others then l_ejec_id := null; end;
        l_filas := null;
        if l_ejec_id is not null then
          begin select sum(filas_procesadas) into l_filas from tdm_mask_solicitud where ejecucion_id = l_ejec_id; exception when others then l_filas := null; end;
          if :v_ejec_min is null or l_ejec_id < :v_ejec_min then :v_ejec_min := l_ejec_id; end if;
          if :v_ejec_max is null or l_ejec_id > :v_ejec_max then :v_ejec_max := l_ejec_id; end if;
        end if;
        dbms_output.put_line('   OK  ejecucion_id=' || nvl(to_char(l_ejec_id),'?') || '  filas_procesadas=' || nvl(to_char(l_filas),'?'));
        :v_reporte := :v_reporte || rpad('TMP_CUADRE_EJERCICIO3',35) || 'OK  ejec=' || nvl(to_char(l_ejec_id),'?') || ' filas=' || nvl(to_char(l_filas),'?') || chr(10);
      end;
      :v_ok_tablas := :v_ok_tablas + 1; :v_total_columnas := :v_total_columnas + 1;
    exception when others then
      l_err := replace(replace(substr(sqlerrm,1,300),chr(10),' '),chr(13),' ');
      dbms_output.put_line('   ERROR: ' || l_err);
      :v_reporte := :v_reporte || rpad('TMP_CUADRE_EJERCICIO3',35) || 'ERROR ' || l_err || chr(10);
      :v_err_tablas := :v_err_tablas + 1;
    end;
  end if;
end;
/
declare
  l_filas_tabla number; l_conteo_ok varchar2(1) := 'Y'; l_err varchar2(400);
begin
  dbms_output.put_line('-> SRI2006.TMP_GENERACION_INGRESOS_IG (1 columna(s): IG_NIF_CIF)');
  begin
    execute immediate 'SELECT COUNT(*) FROM ' || dbms_assert.enquote_name(:v_esquema,false) || '.' || dbms_assert.enquote_name('TMP_GENERACION_INGRESOS_IG',false) into l_filas_tabla;
  exception when others then
    l_conteo_ok := 'N';
    dbms_output.put_line('   AVISO: no se pudo contar filas (' || replace(replace(substr(sqlerrm,1,200),chr(10),' '),chr(13),' ') || '); se intenta enmascarar igual.');
  end;
  if l_conteo_ok = 'Y' and l_filas_tabla = 0 then
    dbms_output.put_line('   OMITIDA: tabla vacia (0 filas) -- no se llamo a p_mask_tab, no se creo ejecucion ad-hoc.');
    :v_vacias_tablas := :v_vacias_tablas + 1; :v_reporte := :v_reporte || rpad('TMP_GENERACION_INGRESOS_IG',35) || 'VACIA (0 filas)' || chr(10);
  else
    if l_conteo_ok = 'Y' then dbms_output.put_line('   Filas en tabla: ' || l_filas_tabla); end if;
    begin
      pkg_dm_enmascarar.p_mask_tab(p_esquema => :v_esquema, p_tabla => 'TMP_GENERACION_INGRESOS_IG', p_identificador => 'IDENTIFICADOR_IDENTIDAD', p_columna => 'IG_NIF_CIF');
      declare l_ejec_id number; l_filas number; begin
        begin select max(ejecucion_id) into l_ejec_id from tdm_ejecucion where esquema_objetivo = :v_esquema; exception when others then l_ejec_id := null; end;
        l_filas := null;
        if l_ejec_id is not null then
          begin select sum(filas_procesadas) into l_filas from tdm_mask_solicitud where ejecucion_id = l_ejec_id; exception when others then l_filas := null; end;
          if :v_ejec_min is null or l_ejec_id < :v_ejec_min then :v_ejec_min := l_ejec_id; end if;
          if :v_ejec_max is null or l_ejec_id > :v_ejec_max then :v_ejec_max := l_ejec_id; end if;
        end if;
        dbms_output.put_line('   OK  ejecucion_id=' || nvl(to_char(l_ejec_id),'?') || '  filas_procesadas=' || nvl(to_char(l_filas),'?'));
        :v_reporte := :v_reporte || rpad('TMP_GENERACION_INGRESOS_IG',35) || 'OK  ejec=' || nvl(to_char(l_ejec_id),'?') || ' filas=' || nvl(to_char(l_filas),'?') || chr(10);
      end;
      :v_ok_tablas := :v_ok_tablas + 1; :v_total_columnas := :v_total_columnas + 1;
    exception when others then
      l_err := replace(replace(substr(sqlerrm,1,300),chr(10),' '),chr(13),' ');
      dbms_output.put_line('   ERROR: ' || l_err);
      :v_reporte := :v_reporte || rpad('TMP_GENERACION_INGRESOS_IG',35) || 'ERROR ' || l_err || chr(10);
      :v_err_tablas := :v_err_tablas + 1;
    end;
  end if;
end;
/
declare
  l_filas_tabla number; l_conteo_ok varchar2(1) := 'Y'; l_err varchar2(400);
begin
  dbms_output.put_line('-> SRI2006.TMP_INGRESOS_PRIMARIOS (1 columna(s): IP_NIF_CIF)');
  begin
    execute immediate 'SELECT COUNT(*) FROM ' || dbms_assert.enquote_name(:v_esquema,false) || '.' || dbms_assert.enquote_name('TMP_INGRESOS_PRIMARIOS',false) into l_filas_tabla;
  exception when others then
    l_conteo_ok := 'N';
    dbms_output.put_line('   AVISO: no se pudo contar filas (' || replace(replace(substr(sqlerrm,1,200),chr(10),' '),chr(13),' ') || '); se intenta enmascarar igual.');
  end;
  if l_conteo_ok = 'Y' and l_filas_tabla = 0 then
    dbms_output.put_line('   OMITIDA: tabla vacia (0 filas) -- no se llamo a p_mask_tab, no se creo ejecucion ad-hoc.');
    :v_vacias_tablas := :v_vacias_tablas + 1; :v_reporte := :v_reporte || rpad('TMP_INGRESOS_PRIMARIOS',35) || 'VACIA (0 filas)' || chr(10);
  else
    if l_conteo_ok = 'Y' then dbms_output.put_line('   Filas en tabla: ' || l_filas_tabla); end if;
    begin
      pkg_dm_enmascarar.p_mask_tab(p_esquema => :v_esquema, p_tabla => 'TMP_INGRESOS_PRIMARIOS', p_identificador => 'IDENTIFICADOR_IDENTIDAD', p_columna => 'IP_NIF_CIF');
      declare l_ejec_id number; l_filas number; begin
        begin select max(ejecucion_id) into l_ejec_id from tdm_ejecucion where esquema_objetivo = :v_esquema; exception when others then l_ejec_id := null; end;
        l_filas := null;
        if l_ejec_id is not null then
          begin select sum(filas_procesadas) into l_filas from tdm_mask_solicitud where ejecucion_id = l_ejec_id; exception when others then l_filas := null; end;
          if :v_ejec_min is null or l_ejec_id < :v_ejec_min then :v_ejec_min := l_ejec_id; end if;
          if :v_ejec_max is null or l_ejec_id > :v_ejec_max then :v_ejec_max := l_ejec_id; end if;
        end if;
        dbms_output.put_line('   OK  ejecucion_id=' || nvl(to_char(l_ejec_id),'?') || '  filas_procesadas=' || nvl(to_char(l_filas),'?'));
        :v_reporte := :v_reporte || rpad('TMP_INGRESOS_PRIMARIOS',35) || 'OK  ejec=' || nvl(to_char(l_ejec_id),'?') || ' filas=' || nvl(to_char(l_filas),'?') || chr(10);
      end;
      :v_ok_tablas := :v_ok_tablas + 1; :v_total_columnas := :v_total_columnas + 1;
    exception when others then
      l_err := replace(replace(substr(sqlerrm,1,300),chr(10),' '),chr(13),' ');
      dbms_output.put_line('   ERROR: ' || l_err);
      :v_reporte := :v_reporte || rpad('TMP_INGRESOS_PRIMARIOS',35) || 'ERROR ' || l_err || chr(10);
      :v_err_tablas := :v_err_tablas + 1;
    end;
  end if;
end;
/
declare
  l_filas_tabla number; l_conteo_ok varchar2(1) := 'Y'; l_err varchar2(400);
begin
  dbms_output.put_line('-> SRI2006.TMP_LIQUIDACION_MENSUAL (2 columna(s): NIF,RAZON_SOCIAL)');
  begin
    execute immediate 'SELECT COUNT(*) FROM ' || dbms_assert.enquote_name(:v_esquema,false) || '.' || dbms_assert.enquote_name('TMP_LIQUIDACION_MENSUAL',false) into l_filas_tabla;
  exception when others then
    l_conteo_ok := 'N';
    dbms_output.put_line('   AVISO: no se pudo contar filas (' || replace(replace(substr(sqlerrm,1,200),chr(10),' '),chr(13),' ') || '); se intenta enmascarar igual.');
  end;
  if l_conteo_ok = 'Y' and l_filas_tabla = 0 then
    dbms_output.put_line('   OMITIDA: tabla vacia (0 filas) -- no se llamo a p_mask_tab, no se creo ejecucion ad-hoc.');
    :v_vacias_tablas := :v_vacias_tablas + 1; :v_reporte := :v_reporte || rpad('TMP_LIQUIDACION_MENSUAL',35) || 'VACIA (0 filas)' || chr(10);
  else
    if l_conteo_ok = 'Y' then dbms_output.put_line('   Filas en tabla: ' || l_filas_tabla); end if;
    begin
      pkg_dm_enmascarar.p_mask_tab(p_esquema => :v_esquema, p_tabla => 'TMP_LIQUIDACION_MENSUAL', p_identificador => 'IDENTIFICADOR_IDENTIDAD', p_columna => 'NIF,RAZON_SOCIAL');
      declare l_ejec_id number; l_filas number; begin
        begin select max(ejecucion_id) into l_ejec_id from tdm_ejecucion where esquema_objetivo = :v_esquema; exception when others then l_ejec_id := null; end;
        l_filas := null;
        if l_ejec_id is not null then
          begin select sum(filas_procesadas) into l_filas from tdm_mask_solicitud where ejecucion_id = l_ejec_id; exception when others then l_filas := null; end;
          if :v_ejec_min is null or l_ejec_id < :v_ejec_min then :v_ejec_min := l_ejec_id; end if;
          if :v_ejec_max is null or l_ejec_id > :v_ejec_max then :v_ejec_max := l_ejec_id; end if;
        end if;
        dbms_output.put_line('   OK  ejecucion_id=' || nvl(to_char(l_ejec_id),'?') || '  filas_procesadas=' || nvl(to_char(l_filas),'?'));
        :v_reporte := :v_reporte || rpad('TMP_LIQUIDACION_MENSUAL',35) || 'OK  ejec=' || nvl(to_char(l_ejec_id),'?') || ' filas=' || nvl(to_char(l_filas),'?') || chr(10);
      end;
      :v_ok_tablas := :v_ok_tablas + 1; :v_total_columnas := :v_total_columnas + 2;
    exception when others then
      l_err := replace(replace(substr(sqlerrm,1,300),chr(10),' '),chr(13),' ');
      dbms_output.put_line('   ERROR: ' || l_err);
      :v_reporte := :v_reporte || rpad('TMP_LIQUIDACION_MENSUAL',35) || 'ERROR ' || l_err || chr(10);
      :v_err_tablas := :v_err_tablas + 1;
    end;
  end if;
end;
/
declare
  l_filas_tabla number; l_conteo_ok varchar2(1) := 'Y'; l_err varchar2(400);
begin
  dbms_output.put_line('-> SRI2006.TMP_LIQUIDACION_MENSUAL_INFGES (2 columna(s): NIF,RAZON_SOCIAL)');
  begin
    execute immediate 'SELECT COUNT(*) FROM ' || dbms_assert.enquote_name(:v_esquema,false) || '.' || dbms_assert.enquote_name('TMP_LIQUIDACION_MENSUAL_INFGES',false) into l_filas_tabla;
  exception when others then
    l_conteo_ok := 'N';
    dbms_output.put_line('   AVISO: no se pudo contar filas (' || replace(replace(substr(sqlerrm,1,200),chr(10),' '),chr(13),' ') || '); se intenta enmascarar igual.');
  end;
  if l_conteo_ok = 'Y' and l_filas_tabla = 0 then
    dbms_output.put_line('   OMITIDA: tabla vacia (0 filas) -- no se llamo a p_mask_tab, no se creo ejecucion ad-hoc.');
    :v_vacias_tablas := :v_vacias_tablas + 1; :v_reporte := :v_reporte || rpad('TMP_LIQUIDACION_MENSUAL_INFGES',35) || 'VACIA (0 filas)' || chr(10);
  else
    if l_conteo_ok = 'Y' then dbms_output.put_line('   Filas en tabla: ' || l_filas_tabla); end if;
    begin
      pkg_dm_enmascarar.p_mask_tab(p_esquema => :v_esquema, p_tabla => 'TMP_LIQUIDACION_MENSUAL_INFGES', p_identificador => 'IDENTIFICADOR_IDENTIDAD', p_columna => 'NIF,RAZON_SOCIAL');
      declare l_ejec_id number; l_filas number; begin
        begin select max(ejecucion_id) into l_ejec_id from tdm_ejecucion where esquema_objetivo = :v_esquema; exception when others then l_ejec_id := null; end;
        l_filas := null;
        if l_ejec_id is not null then
          begin select sum(filas_procesadas) into l_filas from tdm_mask_solicitud where ejecucion_id = l_ejec_id; exception when others then l_filas := null; end;
          if :v_ejec_min is null or l_ejec_id < :v_ejec_min then :v_ejec_min := l_ejec_id; end if;
          if :v_ejec_max is null or l_ejec_id > :v_ejec_max then :v_ejec_max := l_ejec_id; end if;
        end if;
        dbms_output.put_line('   OK  ejecucion_id=' || nvl(to_char(l_ejec_id),'?') || '  filas_procesadas=' || nvl(to_char(l_filas),'?'));
        :v_reporte := :v_reporte || rpad('TMP_LIQUIDACION_MENSUAL_INFGES',35) || 'OK  ejec=' || nvl(to_char(l_ejec_id),'?') || ' filas=' || nvl(to_char(l_filas),'?') || chr(10);
      end;
      :v_ok_tablas := :v_ok_tablas + 1; :v_total_columnas := :v_total_columnas + 2;
    exception when others then
      l_err := replace(replace(substr(sqlerrm,1,300),chr(10),' '),chr(13),' ');
      dbms_output.put_line('   ERROR: ' || l_err);
      :v_reporte := :v_reporte || rpad('TMP_LIQUIDACION_MENSUAL_INFGES',35) || 'ERROR ' || l_err || chr(10);
      :v_err_tablas := :v_err_tablas + 1;
    end;
  end if;
end;
/
declare
  l_filas_tabla number; l_conteo_ok varchar2(1) := 'Y'; l_err varchar2(400);
begin
  dbms_output.put_line('-> SRI2006.TMP_NIFS (1 columna(s): NIF)');
  begin
    execute immediate 'SELECT COUNT(*) FROM ' || dbms_assert.enquote_name(:v_esquema,false) || '.' || dbms_assert.enquote_name('TMP_NIFS',false) into l_filas_tabla;
  exception when others then
    l_conteo_ok := 'N';
    dbms_output.put_line('   AVISO: no se pudo contar filas (' || replace(replace(substr(sqlerrm,1,200),chr(10),' '),chr(13),' ') || '); se intenta enmascarar igual.');
  end;
  if l_conteo_ok = 'Y' and l_filas_tabla = 0 then
    dbms_output.put_line('   OMITIDA: tabla vacia (0 filas) -- no se llamo a p_mask_tab, no se creo ejecucion ad-hoc.');
    :v_vacias_tablas := :v_vacias_tablas + 1; :v_reporte := :v_reporte || rpad('TMP_NIFS',35) || 'VACIA (0 filas)' || chr(10);
  else
    if l_conteo_ok = 'Y' then dbms_output.put_line('   Filas en tabla: ' || l_filas_tabla); end if;
    begin
      pkg_dm_enmascarar.p_mask_tab(p_esquema => :v_esquema, p_tabla => 'TMP_NIFS', p_identificador => 'IDENTIFICADOR_IDENTIDAD', p_columna => 'NIF');
      declare l_ejec_id number; l_filas number; begin
        begin select max(ejecucion_id) into l_ejec_id from tdm_ejecucion where esquema_objetivo = :v_esquema; exception when others then l_ejec_id := null; end;
        l_filas := null;
        if l_ejec_id is not null then
          begin select sum(filas_procesadas) into l_filas from tdm_mask_solicitud where ejecucion_id = l_ejec_id; exception when others then l_filas := null; end;
          if :v_ejec_min is null or l_ejec_id < :v_ejec_min then :v_ejec_min := l_ejec_id; end if;
          if :v_ejec_max is null or l_ejec_id > :v_ejec_max then :v_ejec_max := l_ejec_id; end if;
        end if;
        dbms_output.put_line('   OK  ejecucion_id=' || nvl(to_char(l_ejec_id),'?') || '  filas_procesadas=' || nvl(to_char(l_filas),'?'));
        :v_reporte := :v_reporte || rpad('TMP_NIFS',35) || 'OK  ejec=' || nvl(to_char(l_ejec_id),'?') || ' filas=' || nvl(to_char(l_filas),'?') || chr(10);
      end;
      :v_ok_tablas := :v_ok_tablas + 1; :v_total_columnas := :v_total_columnas + 1;
    exception when others then
      l_err := replace(replace(substr(sqlerrm,1,300),chr(10),' '),chr(13),' ');
      dbms_output.put_line('   ERROR: ' || l_err);
      :v_reporte := :v_reporte || rpad('TMP_NIFS',35) || 'ERROR ' || l_err || chr(10);
      :v_err_tablas := :v_err_tablas + 1;
    end;
  end if;
end;
/
declare
  l_filas_tabla number; l_conteo_ok varchar2(1) := 'Y'; l_err varchar2(400);
begin
  dbms_output.put_line('-> SRI2006.TMP_NIFS_CERTIF (1 columna(s): NIF)');
  begin
    execute immediate 'SELECT COUNT(*) FROM ' || dbms_assert.enquote_name(:v_esquema,false) || '.' || dbms_assert.enquote_name('TMP_NIFS_CERTIF',false) into l_filas_tabla;
  exception when others then
    l_conteo_ok := 'N';
    dbms_output.put_line('   AVISO: no se pudo contar filas (' || replace(replace(substr(sqlerrm,1,200),chr(10),' '),chr(13),' ') || '); se intenta enmascarar igual.');
  end;
  if l_conteo_ok = 'Y' and l_filas_tabla = 0 then
    dbms_output.put_line('   OMITIDA: tabla vacia (0 filas) -- no se llamo a p_mask_tab, no se creo ejecucion ad-hoc.');
    :v_vacias_tablas := :v_vacias_tablas + 1; :v_reporte := :v_reporte || rpad('TMP_NIFS_CERTIF',35) || 'VACIA (0 filas)' || chr(10);
  else
    if l_conteo_ok = 'Y' then dbms_output.put_line('   Filas en tabla: ' || l_filas_tabla); end if;
    begin
      pkg_dm_enmascarar.p_mask_tab(p_esquema => :v_esquema, p_tabla => 'TMP_NIFS_CERTIF', p_identificador => 'IDENTIFICADOR_IDENTIDAD', p_columna => 'NIF');
      declare l_ejec_id number; l_filas number; begin
        begin select max(ejecucion_id) into l_ejec_id from tdm_ejecucion where esquema_objetivo = :v_esquema; exception when others then l_ejec_id := null; end;
        l_filas := null;
        if l_ejec_id is not null then
          begin select sum(filas_procesadas) into l_filas from tdm_mask_solicitud where ejecucion_id = l_ejec_id; exception when others then l_filas := null; end;
          if :v_ejec_min is null or l_ejec_id < :v_ejec_min then :v_ejec_min := l_ejec_id; end if;
          if :v_ejec_max is null or l_ejec_id > :v_ejec_max then :v_ejec_max := l_ejec_id; end if;
        end if;
        dbms_output.put_line('   OK  ejecucion_id=' || nvl(to_char(l_ejec_id),'?') || '  filas_procesadas=' || nvl(to_char(l_filas),'?'));
        :v_reporte := :v_reporte || rpad('TMP_NIFS_CERTIF',35) || 'OK  ejec=' || nvl(to_char(l_ejec_id),'?') || ' filas=' || nvl(to_char(l_filas),'?') || chr(10);
      end;
      :v_ok_tablas := :v_ok_tablas + 1; :v_total_columnas := :v_total_columnas + 1;
    exception when others then
      l_err := replace(replace(substr(sqlerrm,1,300),chr(10),' '),chr(13),' ');
      dbms_output.put_line('   ERROR: ' || l_err);
      :v_reporte := :v_reporte || rpad('TMP_NIFS_CERTIF',35) || 'ERROR ' || l_err || chr(10);
      :v_err_tablas := :v_err_tablas + 1;
    end;
  end if;
end;
/
declare
  l_filas_tabla number; l_conteo_ok varchar2(1) := 'Y'; l_err varchar2(400);
begin
  dbms_output.put_line('-> SRI2006.tmp_SRI_IMPORT_INFGESTION_IDEN (2 columna(s): APENOM_DEUDOR,NIF_DEUDOR)');
  begin
    execute immediate 'SELECT COUNT(*) FROM ' || dbms_assert.enquote_name(:v_esquema,false) || '.' || dbms_assert.enquote_name('tmp_SRI_IMPORT_INFGESTION_IDEN',false) into l_filas_tabla;
  exception when others then
    l_conteo_ok := 'N';
    dbms_output.put_line('   AVISO: no se pudo contar filas (' || replace(replace(substr(sqlerrm,1,200),chr(10),' '),chr(13),' ') || '); se intenta enmascarar igual.');
  end;
  if l_conteo_ok = 'Y' and l_filas_tabla = 0 then
    dbms_output.put_line('   OMITIDA: tabla vacia (0 filas) -- no se llamo a p_mask_tab, no se creo ejecucion ad-hoc.');
    :v_vacias_tablas := :v_vacias_tablas + 1; :v_reporte := :v_reporte || rpad('tmp_SRI_IMPORT_INFGESTION_IDEN',35) || 'VACIA (0 filas)' || chr(10);
  else
    if l_conteo_ok = 'Y' then dbms_output.put_line('   Filas en tabla: ' || l_filas_tabla); end if;
    begin
      pkg_dm_enmascarar.p_mask_tab(p_esquema => :v_esquema, p_tabla => 'tmp_SRI_IMPORT_INFGESTION_IDEN', p_identificador => 'IDENTIFICADOR_IDENTIDAD', p_columna => 'APENOM_DEUDOR,NIF_DEUDOR');
      declare l_ejec_id number; l_filas number; begin
        begin select max(ejecucion_id) into l_ejec_id from tdm_ejecucion where esquema_objetivo = :v_esquema; exception when others then l_ejec_id := null; end;
        l_filas := null;
        if l_ejec_id is not null then
          begin select sum(filas_procesadas) into l_filas from tdm_mask_solicitud where ejecucion_id = l_ejec_id; exception when others then l_filas := null; end;
          if :v_ejec_min is null or l_ejec_id < :v_ejec_min then :v_ejec_min := l_ejec_id; end if;
          if :v_ejec_max is null or l_ejec_id > :v_ejec_max then :v_ejec_max := l_ejec_id; end if;
        end if;
        dbms_output.put_line('   OK  ejecucion_id=' || nvl(to_char(l_ejec_id),'?') || '  filas_procesadas=' || nvl(to_char(l_filas),'?'));
        :v_reporte := :v_reporte || rpad('tmp_SRI_IMPORT_INFGESTION_IDEN',35) || 'OK  ejec=' || nvl(to_char(l_ejec_id),'?') || ' filas=' || nvl(to_char(l_filas),'?') || chr(10);
      end;
      :v_ok_tablas := :v_ok_tablas + 1; :v_total_columnas := :v_total_columnas + 2;
    exception when others then
      l_err := replace(replace(substr(sqlerrm,1,300),chr(10),' '),chr(13),' ');
      dbms_output.put_line('   ERROR: ' || l_err);
      :v_reporte := :v_reporte || rpad('tmp_SRI_IMPORT_INFGESTION_IDEN',35) || 'ERROR ' || l_err || chr(10);
      :v_err_tablas := :v_err_tablas + 1;
    end;
  end if;
end;
/
declare
  l_filas_tabla number; l_conteo_ok varchar2(1) := 'Y'; l_err varchar2(400);
begin
  dbms_output.put_line('-> SRI2006.TMP_SRI_INFORME_GESTION (1 columna(s): IG_NIF_CIF)');
  begin
    execute immediate 'SELECT COUNT(*) FROM ' || dbms_assert.enquote_name(:v_esquema,false) || '.' || dbms_assert.enquote_name('TMP_SRI_INFORME_GESTION',false) into l_filas_tabla;
  exception when others then
    l_conteo_ok := 'N';
    dbms_output.put_line('   AVISO: no se pudo contar filas (' || replace(replace(substr(sqlerrm,1,200),chr(10),' '),chr(13),' ') || '); se intenta enmascarar igual.');
  end;
  if l_conteo_ok = 'Y' and l_filas_tabla = 0 then
    dbms_output.put_line('   OMITIDA: tabla vacia (0 filas) -- no se llamo a p_mask_tab, no se creo ejecucion ad-hoc.');
    :v_vacias_tablas := :v_vacias_tablas + 1; :v_reporte := :v_reporte || rpad('TMP_SRI_INFORME_GESTION',35) || 'VACIA (0 filas)' || chr(10);
  else
    if l_conteo_ok = 'Y' then dbms_output.put_line('   Filas en tabla: ' || l_filas_tabla); end if;
    begin
      pkg_dm_enmascarar.p_mask_tab(p_esquema => :v_esquema, p_tabla => 'TMP_SRI_INFORME_GESTION', p_identificador => 'IDENTIFICADOR_IDENTIDAD', p_columna => 'IG_NIF_CIF');
      declare l_ejec_id number; l_filas number; begin
        begin select max(ejecucion_id) into l_ejec_id from tdm_ejecucion where esquema_objetivo = :v_esquema; exception when others then l_ejec_id := null; end;
        l_filas := null;
        if l_ejec_id is not null then
          begin select sum(filas_procesadas) into l_filas from tdm_mask_solicitud where ejecucion_id = l_ejec_id; exception when others then l_filas := null; end;
          if :v_ejec_min is null or l_ejec_id < :v_ejec_min then :v_ejec_min := l_ejec_id; end if;
          if :v_ejec_max is null or l_ejec_id > :v_ejec_max then :v_ejec_max := l_ejec_id; end if;
        end if;
        dbms_output.put_line('   OK  ejecucion_id=' || nvl(to_char(l_ejec_id),'?') || '  filas_procesadas=' || nvl(to_char(l_filas),'?'));
        :v_reporte := :v_reporte || rpad('TMP_SRI_INFORME_GESTION',35) || 'OK  ejec=' || nvl(to_char(l_ejec_id),'?') || ' filas=' || nvl(to_char(l_filas),'?') || chr(10);
      end;
      :v_ok_tablas := :v_ok_tablas + 1; :v_total_columnas := :v_total_columnas + 1;
    exception when others then
      l_err := replace(replace(substr(sqlerrm,1,300),chr(10),' '),chr(13),' ');
      dbms_output.put_line('   ERROR: ' || l_err);
      :v_reporte := :v_reporte || rpad('TMP_SRI_INFORME_GESTION',35) || 'ERROR ' || l_err || chr(10);
      :v_err_tablas := :v_err_tablas + 1;
    end;
  end if;
end;
/
declare
  l_filas_tabla number; l_conteo_ok varchar2(1) := 'Y'; l_err varchar2(400);
begin
  dbms_output.put_line('-> SRI2006.tmp_TMP_LIQUIDACION_MENSUAL (2 columna(s): NIF,RAZON_SOCIAL)');
  begin
    execute immediate 'SELECT COUNT(*) FROM ' || dbms_assert.enquote_name(:v_esquema,false) || '.' || dbms_assert.enquote_name('tmp_TMP_LIQUIDACION_MENSUAL',false) into l_filas_tabla;
  exception when others then
    l_conteo_ok := 'N';
    dbms_output.put_line('   AVISO: no se pudo contar filas (' || replace(replace(substr(sqlerrm,1,200),chr(10),' '),chr(13),' ') || '); se intenta enmascarar igual.');
  end;
  if l_conteo_ok = 'Y' and l_filas_tabla = 0 then
    dbms_output.put_line('   OMITIDA: tabla vacia (0 filas) -- no se llamo a p_mask_tab, no se creo ejecucion ad-hoc.');
    :v_vacias_tablas := :v_vacias_tablas + 1; :v_reporte := :v_reporte || rpad('tmp_TMP_LIQUIDACION_MENSUAL',35) || 'VACIA (0 filas)' || chr(10);
  else
    if l_conteo_ok = 'Y' then dbms_output.put_line('   Filas en tabla: ' || l_filas_tabla); end if;
    begin
      pkg_dm_enmascarar.p_mask_tab(p_esquema => :v_esquema, p_tabla => 'tmp_TMP_LIQUIDACION_MENSUAL', p_identificador => 'IDENTIFICADOR_IDENTIDAD', p_columna => 'NIF,RAZON_SOCIAL');
      declare l_ejec_id number; l_filas number; begin
        begin select max(ejecucion_id) into l_ejec_id from tdm_ejecucion where esquema_objetivo = :v_esquema; exception when others then l_ejec_id := null; end;
        l_filas := null;
        if l_ejec_id is not null then
          begin select sum(filas_procesadas) into l_filas from tdm_mask_solicitud where ejecucion_id = l_ejec_id; exception when others then l_filas := null; end;
          if :v_ejec_min is null or l_ejec_id < :v_ejec_min then :v_ejec_min := l_ejec_id; end if;
          if :v_ejec_max is null or l_ejec_id > :v_ejec_max then :v_ejec_max := l_ejec_id; end if;
        end if;
        dbms_output.put_line('   OK  ejecucion_id=' || nvl(to_char(l_ejec_id),'?') || '  filas_procesadas=' || nvl(to_char(l_filas),'?'));
        :v_reporte := :v_reporte || rpad('tmp_TMP_LIQUIDACION_MENSUAL',35) || 'OK  ejec=' || nvl(to_char(l_ejec_id),'?') || ' filas=' || nvl(to_char(l_filas),'?') || chr(10);
      end;
      :v_ok_tablas := :v_ok_tablas + 1; :v_total_columnas := :v_total_columnas + 2;
    exception when others then
      l_err := replace(replace(substr(sqlerrm,1,300),chr(10),' '),chr(13),' ');
      dbms_output.put_line('   ERROR: ' || l_err);
      :v_reporte := :v_reporte || rpad('tmp_TMP_LIQUIDACION_MENSUAL',35) || 'ERROR ' || l_err || chr(10);
      :v_err_tablas := :v_err_tablas + 1;
    end;
  end if;
end;
/
