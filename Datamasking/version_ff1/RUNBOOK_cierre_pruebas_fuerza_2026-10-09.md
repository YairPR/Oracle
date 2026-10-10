# Runbook de cierre de pruebas de fuerza y testeo del motor FF1 (sin volumen)

Fecha: 2026-10-09 · Entorno: PREFORM (RAC, 19c), esquema de pruebas DM_DUMMY · Alcance acordado: "cierre defendible sin volumen".

Cierra: E-01, E-03, E-04 · L-01, L-02*, L-03..L-12 · G-02, G-07 · N-01, N-02, y valida end-to-end el rediseño de interrupciones (monitor / reanudar / cancel) con la prueba de "no doble cifrado".
Queda fuera (ventana aparte, con evidencia existente): I-01..I-04, P-01..P-04 (60M filas, horas), E-05, E-06, G-03..G-06 (ya declarados fuera de alcance). Ver sección final.

## Convenciones

- Dos ventanas: **W1** (lanza el motor) y **W2** (observador / kill). Ambas como SYS (o EYPURISACA), con el directorio actual de SQL*Plus en la carpeta FF1 (los `@dm_*` están ahí; los tests en `tests/`).
- Esquema del motor: `ASTSYSADMIN` en los SQL (si PREFORM usa `ACC_ADMIN`, sustituir).
- Cada bloque es un pegado. Anota los IDs (`A`, `B`, `C`, `D`, `E`) y los pegas de vuelta junto con la salida.
- Nada de lo que sigue modifica código del motor. Los únicos objetos nuevos son tablas de foto en EYPURISACA (`TMP_*`), que se borran en el bloque 10.
- Orden obligatorio: cada pasada de enmascarado cambia datos; las fotos `TMP_*_ORIG` se toman UNA vez, antes de la pasada 1, y todas las comprobaciones son relativas a esa foto (no hace falta que el dato de partida sea "virgen").

## Mapa prueba → bloque

| Bloque | Pruebas | Qué demuestra |
|---|---|---|
| 0 | precondiciones, N-02 (antes) | Entorno sano, privilegios directos, foto de código |
| 1 | L-03, L-04, L-01, L-05, L-08, L-09 | Descubrimiento sin excepciones: errores limpios, línea base nueva |
| 2 | N-01, L-06, N-02 (después) | Cliente nuevo = solo datos; código idéntico |
| 3 | E-04 (observador) | Con trigger de UPDATE corre en serie; sin trigger, en paralelo |
| 4 | E-03, L-07, L-10, validar_flujo, prueba de no doble cifrado | Pasada 1 normal, correcta y determinista |
| 5 | — | Retirado (Data Pump fuera del alcance del motor) |
| 6 | E-01, G-07, G-02 (a) | Kill real a mitad de columna + reanudación sin doble cifrado |
| 7 | rediseño: cancel, G-02 (b) | Cancelación completa y limpia |
| 8 | L-12, G-02 (c) | SKIP_DEP_NOT_FOUND y purga de pepper en ejecución sana |
| 9 | L-02 | Línea base del esquema real equivalente |
| 10 | limpieza | Borrado de fotos |

---

## Bloque 0 — Precondiciones y fotos (W1)

```sql
set lines 200 pages 100 serveroutput on size unlimited

-- 0.1 sin objetos inválidos (esperado: 0 filas)
select owner, object_name, object_type from dba_objects
 where status='INVALID' and owner in ('ASTSYSADMIN','DM_DUMMY');

-- 0.2 privilegios DIRECTOS del dueño del motor (roles no cuentan en definer rights).
--     Esperado: UPDATE ANY TABLE y CREATE JOB como mínimo (el resto según política).
select privilege from dba_sys_privs
 where grantee='ASTSYSADMIN'
   and privilege in ('UPDATE ANY TABLE','SELECT ANY TABLE','ALTER ANY TABLE','ALTER ANY TRIGGER','CREATE JOB')
 order by 1;

-- 0.3 ni tareas huérfanas ni ejecuciones vivas (esperado: 0 filas en ambas)
select task_owner, task_name, status from dba_parallel_execute_tasks where task_name like 'TDM\_%' escape '\';
select ejecucion_id, estado, fase_proceso from astsysadmin.tdm_ejecucion where estado='EJECUTANDO';

-- 0.4 foto N-02 ANTES: código de los paquetes del motor
begin execute immediate 'drop table eypurisaca.tmp_n02 purge'; exception when others then null; end;
/
create table eypurisaca.tmp_n02 as
select 'ANTES' momento, name, type, count(*) lineas, sum(ora_hash(line||text)) h
  from dba_source
 where owner='ASTSYSADMIN' and type in ('PACKAGE','PACKAGE BODY')
 group by name, type;
select momento, count(*) paquetes, sum(lineas) lineas from eypurisaca.tmp_n02 group by momento;

-- 0.5 fotos de datos (relativas a ellas se comprueba todo)
begin execute immediate 'drop table eypurisaca.tmp_lote_orig purge';   exception when others then null; end;
/
begin execute immediate 'drop table eypurisaca.tmp_gestor_orig purge'; exception when others then null; end;
/
create table eypurisaca.tmp_lote_orig   as select lote_id, nombre_completo from dm_dummy.tbl_lote_resume;
create table eypurisaca.tmp_gestor_orig as select gestor_id, gestor, cod_acceso_corto from dm_dummy.tbl_gestor_cartera;
select (select count(*) from eypurisaca.tmp_lote_orig)   lote_150000,
       (select count(*) from eypurisaca.tmp_gestor_orig) gestor_1000,
       (select count(*) from astsysadmin.tdm_excepcion_col) excepciones_antes
  from dual;
```

Esperado: 0.1 y 0.3 sin filas; 0.2 con los privilegios; fotos con 150000 / 1000 filas. Si 0.3 devuelve tareas, se tratan con `@dm_enmascara_cancel <id> CONFIRMAR DESCARTAR` antes de seguir.

---

## Bloque 1 — Descubrimiento sin excepciones (W1)

**1.1 L-03 — esquema inexistente.**

```
@dm_descubre DM_DUMMYX %
```
```sql
select count(*) fantasmas from astsysadmin.tdm_ejecucion where ora_esquema='DM_DUMMYX';
```
Esperado: `ORA-20016` limpio y `fantasmas = 0`.

**1.2 Partida limpia para L-04.** ⚠ `@dm_reset_ejecuciones` vacía TODO el historial del motor en PREFORM (ejecuciones, hist, trazas, peppers). Hazlo solo si ya no necesitas la evidencia anterior de DM_DUMMY; si prefieres conservarla, salta este paso y L-04 se documenta como "no ejecutable con historial previo" (se cierra con CEFCEN_OWN, cuya primera ejecución ya existe).

```
@dm_reset_ejecuciones CONFIRMAR
```
(El 0.3 ya garantizó que no hay tareas: `dm_reset_ejecuciones` mira `user_parallel_execute_tasks`, que ve solo las tareas del usuario conectado y no las de ASTSYSADMIN. Por eso el 0.3 con `dba_` es la guarda real. Hallazgo anotado abajo.)

**1.3 L-04 + L-01 — primera ejecución con `Y` y línea base nueva.**

```
@dm_descubre DM_DUMMY Y
```
Anota `A` = ejecucion_id.

```sql
define A=<id>
select estado, fase_proceso, error_count, tablas_total, columnas_total
  from astsysadmin.tdm_ejecucion where ejecucion_id=&A;

-- L-01: línea base nueva (la anterior era 18 tablas / 59 columnas / 50 con Y, antes de las 6 tablas del cierre)
select count(distinct table_name) tablas, count(*) columnas,
       count(case when enmascarar='Y' then 1 end) con_Y
  from astsysadmin.tdm_columna_hist where ejecucion_id=&A;

-- L-05, L-08, L-09: columnas de interés
select table_name, column_name, identificador, estado_final, enmascarar, score_total
  from astsysadmin.tdm_columna_hist
 where ejecucion_id=&A
   and ( table_name='TBL_GESTOR_CARTERA'
      or lower(column_name) like '%edificio%' or lower(column_name) like '%direccion%'
      or lower(column_name) like '%calle%'    or lower(column_name) like '%observ%')
 order by table_name, column_name;
```

Esperado:
- L-04: FINALIZADO, error_count 0 (la `Y` en primera ejecución es no-op).
- L-05: `GESTOR` NO queda `IDENTIFICADOR_PERSONAL` confirmado (REVISAR/DESCARTADO/OBS, nunca CONFIRMADO como personal).
- L-08: EDIFICIO / direccion / calle_completa al menos `REVISAR` (no `DESCARTADO`).
- L-09: observaciones con PII embebida → PROBABLE/CONFIRMADO; `observaciones_rrhh` de `tbl_empleado_vol` (sin PII) → REVISAR o DESCARTADO, nunca confirmado.
- L-01: apunta los tres números; son la línea base de aquí en adelante.

---

## Bloque 2 — Genericidad: cliente nuevo solo con datos (W1)

```sql
alter session set current_schema = ASTSYSADMIN;
@tests/carga_excepciones_dummy_cliente_ficticio
commit;
-- (o EYPURISACA)
alter session set current_schema = SYS;

-- antes + 2 filas FORCE
select count(*) excepciones_despues from astsysadmin.tdm_excepcion_col;

-- N-02 DESPUÉS: el código no cambió ni un carácter
create table eypurisaca.tmp_n02_d as
select 'DESPUES' momento, name, type, count(*) lineas, sum(ora_hash(line||text)) h
  from dba_source where owner='ASTSYSADMIN' and type in ('PACKAGE','PACKAGE BODY') group by name, type;

select count(*) paquetes_distintos from (
  select name, type, lineas, h from eypurisaca.tmp_n02
  minus
  select name, type, lineas, h from eypurisaca.tmp_n02_d)
union all
select count(*) from (
  select name, type, lineas, h from eypurisaca.tmp_n02_d
  minus
  select name, type, lineas, h from eypurisaca.tmp_n02);
```
Esperado N-01/N-02: `excepciones_despues = antes + 2` (o más si el loader trae más filas) y **0 y 0** en el diff de código.

Re-descubrimiento con las excepciones (`Y` fuerza reevaluación completa):

```
@dm_descubre DM_DUMMY Y
```
Anota `B`.

```sql
define B=<id>
-- L-06: FORCE manda sobre la clasificación automática
select table_name, column_name, identificador, enmascarar
  from astsysadmin.tdm_columna_final
 where ora_owner='DM_DUMMY' and table_name='TBL_GESTOR_CARTERA' order by column_name;
select estado, error_count from astsysadmin.tdm_ejecucion where ejecucion_id=&B;
```
Esperado L-06: `GESTOR` → IDENTIFICADOR_PERSONAL / Y; `COD_ACCESO_CORTO` → IDENTIFICADOR_BANCARIO / Y; `B` FINALIZADO sin errores.

---

## Bloque 2b — Rehacer N-01 / L-05 / L-06 (si las excepciones ya existían)

En PREFORM las 2 excepciones FORCE ya estaban cargadas de antes (el loader dijo "2 filas fusionadas", es un MERGE sobre filas existentes), así que el bloque 1 ya descubrió con ellas y L-05 y N-01 no se pudieron comprobar. Se rehacen quitando solo esas 2 filas:

```sql
delete from astsysadmin.tdm_excepcion_col where ora_owner='DM_DUMMY' and table_name='TBL_GESTOR_CARTERA';
commit;
```
```
@dm_descubre DM_DUMMY Y
```
```sql
define S1=<id>
select table_name, column_name, identificador, estado_final, enmascarar, score_total
  from astsysadmin.tdm_columna_hist where ejecucion_id=&S1 and table_name='TBL_GESTOR_CARTERA' order by column_name;
```
Esperado L-05: `GESTOR` NO es IDENTIFICADOR_PERSONAL confirmado y `COD_ACCESO_CORTO` NO queda en Y. Después se da de alta el cliente solo con datos y se vuelve a descubrir:

```sql
alter session set current_schema = ASTSYSADMIN;
@tests/carga_excepciones_dummy_cliente_ficticio
commit;
alter session set current_schema = SYS;
```
```
@dm_descubre DM_DUMMY Y
```
Esperado N-01/L-06: GESTOR → IDENTIFICADOR_PERSONAL/Y y COD_ACCESO_CORTO → IDENTIFICADOR_BANCARIO/Y. **El id de este último descubrimiento es el `B` que se enmascara en el bloque 4.** El diff de código N-02 ya dio 0 y 0 y no hay que repetirlo.

Línea base L-01 con excepciones (ejecución 4): 22 tablas, 64 columnas, 51 con Y.

> Regla de pegado en SQL*Plus: nunca dejar un comentario `-- ...` detrás de un `;` en la misma línea; la sentencia no se ejecuta y queda esperando (le pasó a dos sentencias del bloque 2). En este runbook los comentarios van en línea aparte.

---

## Bloque 3 — E-04: observador de paralelismo (W2, ANTES de lanzar el bloque 4)

Se lanza en W2 y se deja corriendo; luego en W1 el bloque 4. Observa dos tareas: `TBL_SUCURSAL_RIESGO` (tiene trigger de UPDATE → debe ir en serie) y `TBL_LOTE_RESUME` (sin trigger → control positivo, debe usar 2 jobs).

```sql
set serveroutput on size unlimited
declare
  type t_s is table of varchar2(200) index by pls_integer;
  type t_n is table of number        index by pls_integer;
  v_nom  t_s; v_tarea t_s; v_vista t_n; v_maxj t_n; v_lvl t_s;
  v_n number; v_j number; v_activas number;
  t0 number := dbms_utility.get_time;
begin
  v_nom(1) := 'TBL_SUCURSAL_RIESGO.TITULAR_PRINCIPAL';
  v_nom(2) := 'TBL_LOTE_RESUME.NOMBRE_COMPLETO';
  for i in 1..2 loop
    v_tarea(i) := 'TDM_'||to_char(dbms_utility.get_hash_value('DM_DUMMY.'||v_nom(i),1,1000000000));
    v_vista(i) := 0; v_maxj(i) := 0; v_lvl(i) := 'n/d';
  end loop;
  dbms_output.put_line('Observando... lanza ahora el enmascarado en W1.');
  loop
    v_activas := 0;
    for i in 1..2 loop
      select count(*) into v_n from dba_parallel_execute_tasks where task_name = v_tarea(i);
      if v_n > 0 then
        v_activas := v_activas + 1;
        if v_vista(i) = 0 then
          v_vista(i) := 1;
          begin   -- la columna PARALLEL_LEVEL puede no existir en esta version: la evidencia real son los jobs
            execute immediate 'select to_char(parallel_level) from dba_parallel_execute_tasks where task_name=:1'
              into v_lvl(i) using v_tarea(i);
          exception when others then v_lvl(i) := 'n/d'; end;
          dbms_output.put_line('Tarea vista: '||v_nom(i)||' (parallel_level='||v_lvl(i)||')');
        end if;
        select count(*) into v_j from dba_scheduler_running_jobs
         where owner='ASTSYSADMIN' and job_name like 'TASK$%';
        if v_j > v_maxj(i) then v_maxj(i) := v_j; end if;
      elsif v_vista(i) = 1 and v_vista(i) <> 2 then
        v_vista(i) := 2;
        dbms_output.put_line('Tarea terminada: '||v_nom(i)||' -> maximo de jobs TASK$ simultaneos = '||v_maxj(i));
      end if;
    end loop;
    exit when v_vista(1) = 2 and v_vista(2) = 2;
    if (dbms_utility.get_time - t0)/100 > 3600 then
      dbms_output.put_line('TIMEOUT 1 h sin ver ambas tareas.'); exit;
    end if;
    dbms_lock.sleep(0.3);
  end loop;
end;
/
```
Esperado E-04: `TBL_SUCURSAL_RIESGO` → **0 jobs** simultáneos (corre en la sesión que llama, nivel 1); `TBL_LOTE_RESUME` → **2 jobs** (control positivo). Y en el bloque 4, sin `ORA-00060` en `tdm_ejecucion_error`.

(Si una tabla no aparece, es que no se clasificó o fue por la ruta directa ≤100k filas: se anota y se revisa.)

---

## Bloque 4 — Pasada 1 normal (E-03, L-07, L-10)

**W1:**

```
@dm_enmascara <B>
```
Al terminar, el propio script ejecuta `dm_validar_flujo`. Anota el tiempo total y el de `TBL_LOTE_RESUME` (trazas).

```sql
define B=<id>
select estado, progreso_pct, error_count from astsysadmin.tdm_ejecucion where ejecucion_id=&B;

-- E-03: sin ORA-20330/20331 ni errores
select count(*) errores, count(case when codigo_error in (-20330,-20331) then 1 end) huerfanas
  from astsysadmin.tdm_ejecucion_error where ejecucion_id=&B;

-- E-03 / no doble cifrado: lo enmascarado == f(original) UNA sola vez, con el pepper de esta ejecución
exec astsysadmin.pkg_dm_func_mask.proc_dm_set_ejecucion(&B)
select count(*) total,
       sum(case when t.nombre_completo = astsysadmin.pkg_dm_func_mask.func_dm_nombre(o.nombre_completo) then 1 else 0 end) igual_f_1_vez,
       sum(case when t.nombre_completo = o.nombre_completo then 1 else 0 end) sin_enmascarar,
       sum(case when t.nombre_completo = astsysadmin.pkg_dm_func_mask.func_dm_nombre(
                                         astsysadmin.pkg_dm_func_mask.func_dm_nombre(o.nombre_completo)) then 1 else 0 end) igual_f_2_veces
  from dm_dummy.tbl_lote_resume t join eypurisaca.tmp_lote_orig o on o.lote_id = t.lote_id;
```
Esperado E-03: `B` FINALIZADO, 0 errores; **`igual_f_1_vez = total`, `sin_enmascarar = 0`, `igual_f_2_veces = 0`**.
(Nota: si `func_dm_nombre` devuelve el mismo valor para algún nombre muy corto, `sin_enmascarar` y `igual_f_2_veces` pueden ser > 0 por coincidencia en esas filas; se justifica fila a fila, no se ignora.)

**L-07 — dominio de 4 dígitos (fallback NIST, no FF1 puro):**

```sql
select count(*) total,
       count(case when regexp_like(t.cod_acceso_corto,'^[0-9]{4}$') then 1 end) cuatro_digitos,
       count(case when t.cod_acceso_corto = o.cod_acceso_corto then 1 end)      iguales_al_original
  from dm_dummy.tbl_gestor_cartera t join eypurisaca.tmp_gestor_orig o on o.gestor_id = t.gestor_id;

-- determinismo: el mismo original da siempre el mismo enmascarado (esperado: 0 filas)
select o.cod_acceso_corto, count(distinct t.cod_acceso_corto) distintos
  from dm_dummy.tbl_gestor_cartera t join eypurisaca.tmp_gestor_orig o on o.gestor_id = t.gestor_id
 group by o.cod_acceso_corto having count(distinct t.cod_acceso_corto) > 1;
```
Esperado: `cuatro_digitos = total`, `iguales_al_original` ≈ 0,01 % del dominio (unas pocas filas como mucho), y 0 filas en el segundo select.

**L-10 — coherencia cruzada por FK (el mismo valor real da el mismo enmascarado en padre e hijos):**

```sql
declare
  l_n number; l_bad number := 0;
begin
  for r in (
    select c.table_name hijo, cc.column_name col_h, p.table_name padre, pc.column_name col_p
      from dba_constraints c
      join dba_cons_columns cc on cc.owner=c.owner and cc.constraint_name=c.constraint_name
      join dba_constraints p   on p.owner=c.r_owner and p.constraint_name=c.r_constraint_name
      join dba_cons_columns pc on pc.owner=p.owner and pc.constraint_name=p.constraint_name and pc.position=cc.position
     where c.owner='DM_DUMMY' and c.constraint_type='R'
       and (select count(*) from dba_cons_columns x where x.owner=c.owner and x.constraint_name=c.constraint_name)=1) loop
    execute immediate 'select count(*) from dm_dummy."'||r.hijo||'" h where h."'||r.col_h||'" is not null '||
                      'and not exists (select 1 from dm_dummy."'||r.padre||'" p where p."'||r.col_p||'" = h."'||r.col_h||'")'
      into l_n;
    dbms_output.put_line(rpad(r.hijo||'.'||r.col_h||' -> '||r.padre||'.'||r.col_p,70)||' huerfanos='||l_n);
    l_bad := l_bad + l_n;
  end loop;
  dbms_output.put_line('TOTAL huerfanos FK = '||l_bad);
end;
/
```
Esperado: `huerfanos = 0` en todas las FK de una columna (si el enmascarado rompiera la coherencia padre/hijo, aparecerían hijos sin padre). Para las columnas lógicas de DNI sin FK declarada (`tbl_personas`/`tbl_clientes`/`tbl_empleados`/`tbl_direcciones`/`tbl_documentacion`), usa también la consulta 10.B de `02_poc_esquema_dummy_dml.sql` de tu carpeta (no está en esta copia de trabajo).

**Validación del flujo:**
```
@dm_validar_flujo DM_DUMMY <B>
```
Esperado: sin FAIL.

---

## Bloque 5 — RETIRADO (L-11: export + import)

Retirado por decisión del usuario (2026-10-09): el export/import con Data Pump no forma parte del motor y no se prueba aquí. El ordenamiento de los bloques 6 en adelante no depende de él.

---

## Bloque 6 — E-01 / G-07 / G-02(a): kill real y reanudación

El objetivo es interrumpir la sesión principal Y los jobs a mitad de `TBL_LOTE_RESUME.NOMBRE_COMPLETO`, con algunos chunks ya comprometidos y otros sin terminar, y comprobar que la reanudación no cifra dos veces.

**6.1 Preparar (W1).** Se restauran los datos de la foto y se reparten en más chunks sin cambiar el nº de filas (PCTFREE alto → más bloques; el motor trocea a 2000 bloques):

```sql
update dm_dummy.tbl_lote_resume t
   set nombre_completo = (select o.nombre_completo from eypurisaca.tmp_lote_orig o where o.lote_id = t.lote_id);
commit;
alter table dm_dummy.tbl_lote_resume move pctfree 90;
alter index dm_dummy.pk_tbl_lote_resume rebuild;
exec dbms_stats.gather_table_stats('DM_DUMMY','TBL_LOTE_RESUME')
select num_rows, blocks, ceil(blocks/2000) chunks_aprox from dba_tables where owner='DM_DUMMY' and table_name='TBL_LOTE_RESUME';
```
Esperado: `num_rows` ≈ 150000 (>100000, por tanto ruta paralela) y `chunks_aprox` ≥ 4. Si da menos de 4, repite el `MOVE` con `pctfree 95`.

Nuevo descubrimiento y anota `C` (hay que descubrir de nuevo porque cada ejecución enmascara una sola vez):

```
@dm_descubre DM_DUMMY Y
```
Comprueba que `TBL_LOTE_RESUME.NOMBRE_COMPLETO` sigue en `tdm_columna_final` con `IDENTIFICADOR_PERSONAL` / Y:
```sql
select identificador, enmascarar from astsysadmin.tdm_columna_final
 where ora_owner='DM_DUMMY' and table_name='TBL_LOTE_RESUME';
```

**6.2 Guardia de kill (W2).** Lánzalo primero; queda esperando. Cuando la tarea de la columna tenga ≥1 chunk PROCESSED y ≥1 sin terminar, mata la sesión principal y los jobs `TASK$`, y avisa.

```sql
set serveroutput on size unlimited
declare
  c_tarea constant varchar2(60) := 'TDM_'||to_char(dbms_utility.get_hash_value('DM_DUMMY.TBL_LOTE_RESUME.NOMBRE_COMPLETO',1,1000000000));
  v_ok number; v_pend number; v_tot number; v_visto boolean := false;
  v_ej number; v_sid number; v_ser number; v_inst number;
  t0 number := dbms_utility.get_time;
begin
  dbms_output.put_line('Esperando chunks de '||c_tarea||' ... lanza @dm_enmascara en W1.');
  loop
    select count(case when status='PROCESSED' then 1 end),
           count(case when status in ('UNASSIGNED','ASSIGNED') then 1 end),
           count(*)
      into v_ok, v_pend, v_tot
      from dba_parallel_execute_chunks where task_name = c_tarea;
    if v_tot > 0 then v_visto := true; end if;
    exit when v_ok >= 1 and v_pend >= 1;
    if v_visto and (v_tot = 0 or v_pend = 0) then
      raise_application_error(-20990,'La tarea termino antes de poder interrumpirla ('||v_tot||' chunks). Sube pctfree o repite.');
    end if;
    if (dbms_utility.get_time - t0)/100 > 3600 then raise_application_error(-20991,'Timeout 1 h.'); end if;
    dbms_lock.sleep(0.2);
  end loop;

  select ejecucion_id, sesion_sid, sesion_serial, sesion_inst_id into v_ej, v_sid, v_ser, v_inst
    from (select ejecucion_id, sesion_sid, sesion_serial, sesion_inst_id
            from astsysadmin.tdm_ejecucion
           where ora_esquema='DM_DUMMY' and estado='EJECUTANDO' and fase_proceso='ENMASCARAMIENTO'
           order by ejecucion_id desc)
   where rownum = 1;

  execute immediate 'alter system kill session '''||v_sid||','||v_ser||',@'||v_inst||''' immediate';
  for j in (select s.sid, s.serial#, s.inst_id
              from dba_scheduler_running_jobs r
              join gv$session s on s.sid = r.session_id and s.inst_id = r.running_instance
             where r.owner='ASTSYSADMIN' and r.job_name like 'TASK$%') loop
    begin
      execute immediate 'alter system kill session '''||j.sid||','||j.serial#||',@'||j.inst_id||''' immediate';
    exception when others then dbms_output.put_line('AVISO kill job: '||substr(sqlerrm,1,100)); end;
  end loop;
  dbms_output.put_line('KILL ejecutado sobre ejecucion '||v_ej||' (chunks PROCESSED='||v_ok||', pendientes='||v_pend||', total='||v_tot||').');
end;
/
```

**6.3 Lanzar (W1):**
```
@dm_enmascara <C>
```
Esperado: W2 imprime `KILL ejecutado...`; la sesión de W1 muere (ORA-00028 / se corta). Si W2 dice `terminó antes de poder interrumpirla`, no es fallo del motor: restaura (6.1, primer `update` solamente) y repite con más bloques.

**6.4 Estado tras el kill (W2, sesión nueva):**

```sql
define C=<id>
-- sigue EJECUTANDO
select ejecucion_id, estado, fase_proceso from astsysadmin.tdm_ejecucion where ejecucion_id=&C;
```
```
@dm_monitor <C>
```
Esperado: el monitor dice **SE QUEDÓ SIN SESIÓN PRINCIPAL**, muestra la tarea de `TBL_LOTE_RESUME.NOMBRE_COMPLETO` con chunks PROCESSED / pendientes, "INTERRUMPIDA EN" / "SE REANUDARÍA DESDE" y como siguiente paso `@dm_enmascara_reanudar` o `@dm_enmascara_cancel`. Pega la salida completa.

**6.5 G-02(a) y G-07 (W1).** El orden importa: primero la purga (la ejecución debe seguir EJECUTANDO), después el intento ciego (que puede cambiar su estado).

```sql
define C=<id>
-- G-02 (a): purgar el pepper de una ejecución EJECUTANDO debe fallar con ORA-20099
exec astsysadmin.pkg_dm_enmascarar.proc_dm_pepper_purgar(&C)
-- 1
select count(*) pepper_sigue from astsysadmin.tdm_secreto where clave='PEPPER_MASK:'||&C;
```
Esperado: `ORA-20099` y `pepper_sigue = 1`. Luego G-07, el reintento ciego:

```
@dm_enmascara <C>
```
Esperado: **no reprocesa**. Se acepta cualquiera de estos rechazos y se anota cuál salió: `ORA-20330` (misma columna, tarea huérfana), `ORA-20331` (hay tareas huérfanas), o el guard de concurrencia/ejecución viva. Lo que NO se acepta es que avance en silencio. Si el intento ciego dejó la ejecución en ERROR, `@dm_enmascara_reanudar` sigue siendo válido (reanuda desde el mismo punto).

**6.6 Reanudar (W1):**
```
@dm_enmascara_reanudar <C>
```
Esperado: narra [1/4] REVISIÓN → [2/4] LIMPIEZA → [3/4] LIMPIEZA COMPLETADA → [4/4] REANUDANDO, indica la tabla y el desde dónde, termina `FINALIZADO` con 0 errores.

**6.7 Prueba de no doble cifrado (E-01, W1):**

```sql
define C=<id>
exec astsysadmin.pkg_dm_func_mask.proc_dm_set_ejecucion(&C)
select count(*) total,
       sum(case when t.nombre_completo = astsysadmin.pkg_dm_func_mask.func_dm_nombre(o.nombre_completo) then 1 else 0 end) igual_f_1_vez,
       sum(case when t.nombre_completo = o.nombre_completo then 1 else 0 end) sin_enmascarar,
       sum(case when t.nombre_completo = astsysadmin.pkg_dm_func_mask.func_dm_nombre(
                                         astsysadmin.pkg_dm_func_mask.func_dm_nombre(o.nombre_completo)) then 1 else 0 end) igual_f_2_veces
  from dm_dummy.tbl_lote_resume t join eypurisaca.tmp_lote_orig o on o.lote_id = t.lote_id;
-- 0 filas
select task_name, status from dba_parallel_execute_tasks where task_name like 'TDM\_%' escape '\';
```
Esperado E-01: **`igual_f_1_vez = total`, `sin_enmascarar = 0`, `igual_f_2_veces = 0`**, sin tareas residuales. Esto demuestra que el kill a mitad de columna + reanudación deja cada fila cifrada exactamente una vez: los chunks que ya estaban PROCESSED no se repitieron y los pendientes sí se completaron.

---

## Bloque 7 — Cancelación completa (rediseño) y G-02(b)

Misma preparación, pero se cancela en vez de reanudar.

**7.1** Restaurar los datos (solo el `update` + `commit` + `gather_stats` del 6.1; el `MOVE` ya está hecho) y `@dm_descubre DM_DUMMY Y` → anota `D`.

**7.2** Guardia de kill en W2 (mismo bloque 6.2) y `@dm_enmascara <D>` en W1. Esperado: KILL ejecutado.

**7.3 Cancelar (W1):**
```
@dm_enmascara_cancel <D> CONFIRMAR DESCARTAR
```
Esperado: 1/5 `proc_dm_cancelar` → 2/5 no queda sesión principal → 3/5 no quedan workers → 4/5 tareas descartadas → 5/5 fila cerrada en ABORTADA.

```sql
define D=<id>
-- ABORTADA
select estado from astsysadmin.tdm_ejecucion where ejecucion_id=&D;
-- 0 filas
select task_name, status from dba_parallel_execute_tasks where task_name like 'TDM\_%' escape '\';
-- 0
select count(*) jobs_vivos from dba_scheduler_running_jobs where owner='ASTSYSADMIN' and job_name like 'TASK$%';
```

**7.4 G-02(b) — pepper de ejecución ABORTADA:**
```
@dm_pepper_purgar <D>
```
Esperado: `ORA-20100` (podría reanudarse). Con `exec astsysadmin.pkg_dm_enmascarar.proc_dm_pepper_purgar(&D,'Y')` sí purga y `select ... from astsysadmin.tdm_secreto where clave='PEPPER_MASK:'||&D` devuelve 0.

---

## Bloque 8 — L-12 (SKIP_DEP_NOT_FOUND) y G-02(c)

**8.1** Restaurar `TBL_LOTE_RESUME` (como en 7.1) y descubrir: `@dm_descubre DM_DUMMY Y` → `E`.

**8.2** Entre el descubrimiento y el enmascarado, cambiar el nombre de la FK sin nombre de `TBL_RENOVACION_CONSTRAINT` (W1):

```sql
select constraint_name from dba_constraints
-- SYS_C00... (anótalo)
 where owner='DM_DUMMY' and table_name='TBL_RENOVACION_CONSTRAINT' and constraint_type='R';
```
```sql
alter table dm_dummy.tbl_renovacion_constraint drop constraint <SYS_C_anotado>;
alter table dm_dummy.tbl_renovacion_constraint add foreign key (dni_ref) references dm_dummy.tbl_personas(dni);
select constraint_name from dba_constraints
-- otro SYS_C00... distinto
 where owner='DM_DUMMY' and table_name='TBL_RENOVACION_CONSTRAINT' and constraint_type='R';
```

**8.3** Enmascarado normal (sin kill):
```
@dm_enmascara <E>
```
```sql
define E=<id>
select estado, error_count from astsysadmin.tdm_ejecucion where ejecucion_id=&E;
select nivel, fase, paso, substr(detalle,1,200) detalle
  from astsysadmin.tdm_mask_trace where ejecucion_id=&E and paso like 'SKIP_DEP%' order by trace_id;
```
Esperado L-12: `E` FINALIZADO; la traza `SKIP_DEP_NOT_FOUND` aparece para la constraint vieja y NO aborta la tabla.

**8.4** `@dm_validar_flujo DM_DUMMY <E>` sin FAIL; luego G-02(c): pepper de ejecución sana libre de purgar:
```
@dm_pepper_purgar <E>
```
Esperado: "semilla eliminada. El dato enmascarado ya no es reversible." y la comprobación final sin filas. (Tras purgar, la prueba de 6.7 sobre `E` falla por falta de pepper: es la irreversibilidad esperada.)

---

## Bloque 9 — L-02

`@dm_descubre DATAM_ARCA_OWN %` si existe en PREFORM; línea base histórica: `Tablas=44, Columnas=142, Con enmascarar=Y=19`. Si no existe, L-02 se documenta como "no ejecutable en este entorno" y la evidencia equivalente es el run real sobre CEFCEN_OWN (ejec 2: FINALIZADO, 0 errores, 4/4 dependencias).

---

## Bloque 10 — Limpieza (W1)

```sql
drop table eypurisaca.tmp_n02 purge;
drop table eypurisaca.tmp_n02_d purge;
drop table eypurisaca.tmp_lote_orig purge;
drop table eypurisaca.tmp_gestor_orig purge;
drop user dm_dummy_imp cascade;
```

---

## Criterio de cierre de este runbook

Todas las filas del cuadro final en "Confirmado" o "Confirmado con hallazgo documentado". Resultados a pegar por bloque: 0.1–0.3, 1.1–1.3, 2 (diff N-02 y L-06), 3+4 (salida del observador, E-03, L-07, L-10, validar_flujo), 6.4–6.7, 7.3–7.4, 8.2–8.4.

| Prueba | Evidencia que la cierra | Estado |
|---|---|---|
| E-01 | 6.4 (monitor), 6.7 (f_1_vez = total, doble = 0) | Pendiente |
| E-03 | 4: FINALIZADO, 0 errores, igual_f_1_vez = total | Pendiente |
| E-04 | 3: 0 jobs en SUCURSAL_RIESGO, 2 en LOTE_RESUME | Pendiente |
| G-02 | 6.5 (a: ORA-20099), 7.4 (b: ORA-20100), 8.4 (c: libre) | Pendiente |
| G-07 | 6.5: rechazo ORA-20330/20331/guard, sin avance silencioso | Pendiente |
| L-01 | 1.3: línea base nueva | Pendiente |
| L-02 | 9 | Pendiente |
| L-03 | 1.1: ORA-20016, 0 fantasmas | Pendiente |
| L-04 | 1.3 | Pendiente |
| L-05 | 1.3 | Pendiente |
| L-06 | 2 | Pendiente |
| L-07 | 4 | Pendiente |
| L-08 / L-09 | 1.3 | Pendiente |
| L-10 | 4 (FK huérfanos = 0 + 10.B) | Pendiente |
| L-12 | 8.3 | Pendiente |
| N-01 / N-02 | 2 | Pendiente |
| Rediseño: monitor / reanudar / cancel | 6.4, 6.6, 7.3 | Pendiente |

## Fuera de esta ventana (se documenta, no se oculta)

- **I-01..I-04, P-01..P-04** (60M filas, horas): requieren ventana dedicada con `c_escala=1.0`, AWR/ASH y `JC_DATAMASKING` opcional. Evidencia ya existente que respalda el comportamiento a volumen: ejecución real SRI2006 (79 tablas, ~100M filas), y la ejecución 1 de 55 columnas / 23,2M filas en 37 min (`claude/hallazgos_prueba_volumen_sri2006_2026-09-18.md`, `claude/jc_datamasking_y_poc_volumen_50m_2026-09-23.md`).
- **E-05** (provocar el deadlock GES desactivando a propósito la protección) y **E-06 / G-03..G-06** (forzar `ORA-06502`, `ORA-00001`, `ORA-12899` aislados): sin dato dummy dedicado y declarados fuera de alcance en el plan; los tres tipos de error ya se reprodujeron en incidentes reales documentados.
- **I-03** (limpieza de huérfanas con `dm_reset_ejecuciones`): ver hallazgo siguiente; la limpieza fiable de huérfanas es `dm_enmascara_cancel ... DESCARTAR` (bloque 7).

## Hallazgos y limitaciones a declarar

1. **`dm_reset_ejecuciones.sql` usa `user_parallel_execute_tasks`.** Las tareas las crea el paquete (definer rights) y pertenecen a ASTSYSADMIN; `user_*` refleja el usuario conectado, no el `current_schema`. Conectado como SYS/EYPURISACA el reset no vería ni podría borrar esas tareas. Hasta que se corrija (consulta `dba_` + descarte desde el paquete), la guarda es el 0.3 de este runbook y la vía soportada es `dm_enmascara_cancel ... DESCARTAR`. Pendiente de corregir y verificar.
2. **Supuesto sin verificar en este entorno:** la columna `SQL_STMT` en `DBA_PARALLEL_EXECUTE_TASKS` (si no existiera, los scripts se detienen con ORA-00904: falla cerrado) y la forma corta de `RESUME_TASK(task, force)`.
3. **Sin certificación CAVP/CMVP** de la implementación FF1 (se valida contra vectores NIST, no está certificada).
4. **Privilegios para auditoría:** el dueño del motor necesita `UPDATE ANY TABLE` (o por tabla) y `CREATE JOB` directos; los roles no cuentan en PL/SQL con derechos de definidor. Lo informa la sección 1.1b de `99_install_datamasking.sql`; no concede nada.
5. **Fuera de lo probado aquí:** comportamiento con volumen real (ver arriba) y caída de instancia RAC real (el kill de sesión y de jobs es la simulación defendible; una caída de nodo exigiría una ventana propia).
