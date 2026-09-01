# Handoff de implementación — Propagación referencial y trazabilidad de logs

> **Antigravity: alcance ESTRICTO y no destructivo.** Este handoff corrige dos áreas —**propagación** y **logs/errores**— sin rehacer el motor. El enmascarado por mapa biyectivo, el Union-Find y el fail-closed **ya funcionan y deben conservarse**. Aquí solo se: (1) hace la propagación de FK una fase visible, correcta respecto a la validación del cliente y trazada con jerarquía; (2) cierra la trazabilidad de errores para que cada log se guarde en su nivel correcto. Cada cambio es aditivo o quirúrgico. Lee la sección 2 (principios) y la 3 (modelo de trazabilidad) antes de tocar código, y no marques nada como "hecho" sin cumplir su criterio de aceptación (sección 6).

---

## 1. Contexto

Motor propio de Data Masking (esquema `ASTSYSADMIN`) para desarrollo/preproducción. Flujo operativo:

1. **Descubrir** → detecta columnas sensibles y **referencias FK** (Union-Find de componentes + `tdm_dependencia_final`).
2. CSV al cliente → el cliente **valida** (deja `enmascarar='Y'`, pone `'N'`, o fuerza con `tdm_excepcion_col` FORCE).
3. **Enmascarar**: deshabilitar dependencias → enmascarar sensibles → **propagar** a la integridad referencial → rehabilitar. Todo trazado.
4. Validar (`dm_validar_flujo`) y exportar.

Estado actual verificado: la propagación de valores funciona (mapa biyectivo compartido por dominio), pero se ejecuta **en el descubrimiento** y está **disuelta dentro del paso de enmascarado**, sin traza de fase ni jerarquía. Y la trazabilidad de errores tiene un eslabón roto (`tdm_ejecucion_error` sin `solicitud_id`) y errores de dependencia que no llegan a la tabla de error.

---

## 2. Principios (obligatorios)

- **No romper la lógica existente.** No eliminar el mapa biyectivo, el Union-Find, el fail-closed C-1, ni `ORA_HASH(columna)`. No cambiar firmas públicas salvo donde se indique explícitamente (logger).
- **Usar los campos reales de cada tabla** (ver sección 3). No inventar columnas; si falta una, se añade con `ALTER TABLE` documentado.
- **Respetar la jerarquía de trazabilidad**: cada log/evento se guarda en el nivel que le corresponde y con las claves que permiten recorrer la jerarquía de arriba abajo.
- **Mantener `DBMS_ASSERT`** (`f_qname`/`f_norm`) en todo SQL dinámico.
- **Compatibilidad Oracle 11g en adelante.**

---

## 3. Modelo de trazabilidad (dónde va cada cosa)

```
tdm_ejecucion (ejecucion_id)
 ├─ tdm_ejecucion_error   (FK ejecucion_id)          -> errores de nivel ejecución
 └─ tdm_mask_solicitud    (FK ejecucion_id)
     ├─ tdm_mask_trace     (FK solicitud_id + ejecucion_id) -> detalle de eventos
     └─ tdm_mask_dep_estado(FK solicitud_id)          -> estado PRE/POST de dependencias
```

Campos reales por tabla (usar EXACTAMENTE estos):

- **`tdm_ejecucion_error`**: `error_id` (PK), `ejecucion_id` (FK), `etapa`, `owner_name`, `table_name`, `column_name`, `codigo_error`, `mensaje_error`, `backtrace`, `fecha_error`. **[Se añade `solicitud_id` — ver L1].**
- **`tdm_mask_trace`**: `trace_id` (PK), `solicitud_id` (FK), `ejecucion_id` (FK), `nivel`, `fase`, `paso`, `detalle`, `fecha_evento`. API: `proc_dm_trace(p_solicitud_id, p_ejecucion_id, <fase>, <paso>, <detalle>)`.
- **`tdm_mask_dep_estado`**: `solicitud_id` (FK), `tipo_objeto`, `owner_name`, `table_name`, `objeto_name`, `estado_previo`, `deshabilitado_ok`, `estado_posterior`, `habilitado_ok`, `fecha_pre`, `fecha_post`.
- **`tdm_columna_final`**: `owner_name`, `table_name`, `column_name`, `identificador`, `enmascarar`, `dominio`.
- **`tdm_mask_key_map`**: `dominio`, `valor_orig`, `valor_masc` (UNIQUE `(dominio, valor_masc)`).

Regla de oro de trazabilidad:
- Error de **descubrimiento/ejecución** → `tdm_ejecucion_error` con `ejecucion_id` y `solicitud_id = NULL`.
- Error de **enmascaramiento/dependencia** → `tdm_ejecucion_error` con `ejecucion_id` **y `solicitud_id`**, + su detalle en `tdm_mask_trace` (y en `tdm_mask_dep_estado` si es dependencia).
- Evento de detalle → `tdm_mask_trace` con `solicitud_id` **y** `ejecucion_id`.

---

## BLOQUE A — PROPAGACIÓN

### A.1 — Re-propagar al inicio del enmascaramiento (respetar la validación del cliente)

**Problema:** `proc_dm_propaga_dominios` corre solo en el **descubrimiento** (`proc_dm_sync_col_final`), antes de que el cliente valide. Si el cliente pone `'N'` a una columna o añade un `FORCE` después del descubrimiento, esos cambios **no se re-propagan** → padre enmascarado / hija no → huérfano.

**Cambio (fichero `04` y `05`):**
1. En `pkg_dm_descubrimiento` (spec), **exponer `proc_dm_propaga_dominios` como pública** (hoy es privada del body).
2. En `pkg_dm_enmascarar.p_dm_enmascara`, **justo antes de `proc_dm_pre_build_maps`**, invocarla para recalcular componentes con los flags ya validados:
```sql
proc_dm_trace(l_solicitud_id, p_ejecucion_id, 'PROPAGACION', 'PROPAGA_START',
              'Recalculando dominios FK con la validacion del cliente');
pkg_dm_descubrimiento.proc_dm_propaga_dominios(l_esquema);
proc_dm_trace(l_solicitud_id, p_ejecucion_id, 'PROPAGACION', 'PROPAGA_END',
              'Dominios FK propagados');
proc_dm_pre_build_maps(l_esquema);   -- ya existe
```
Usa los campos existentes `tdm_columna_final.dominio / .identificador / .enmascarar`. No cambia el algoritmo Union-Find, solo su momento de ejecución.

**Criterio de aceptación A.1:** tras el descubrimiento, poner `enmascarar='N'` en una hija de un componente cuyo padre queda `'Y'`, ejecutar el enmascarado, y verificar (KPI-08) **cero huérfanos** en esa FK — porque la re-propagación volvió a incluir la hija.

### A.2 — Política de exclusión a nivel de dominio, con traza de re-inclusión

**Semántica:** si el cliente excluye una columna (`'N'`) pero su componente tiene otra en `'Y'`, la re-propagación la vuelve a marcar `'Y'` (la RI manda). Esto ya ocurre en la MERGE de `proc_dm_propaga_dominios`. **Falta dejar constancia.**

**Cambio (fichero `04`, dentro de `proc_dm_propaga_dominios`):** cuando la MERGE re-marque a `'Y'` una columna que estaba en `'N'`, emitir traza:
```sql
proc_dm_trace(NULL, NULL, 'PROPAGACION', 'RI_REINCLUYE',
   owner_name||'.'||table_name||'.'||column_name||
   ' re-incluida (Y) por integridad referencial del dominio '||dominio);
```
> Nota: como este proc vive en descubrimiento, usar el mismo patrón de llamada cruzada a `proc_dm_trace` que ya emplea el `PROPAGA_DOMINIOS_ERR` existente. `solicitud_id`/`ejecucion_id` pueden ir NULL aquí (evento de descubrimiento); si se llama desde el enmascarado (A.1), pasar los IDs reales.

**Criterio de aceptación A.2:** el escenario de A.1 deja una traza `RI_REINCLUYE` por cada columna re-incluida.

### A.3 — Traza de jerarquía FK (padre ← hija) en PRE

**Problema:** al deshabilitar dependencias no se registra la jerarquía padre/hija de las tablas enmascaradas. El orden hija→padre en el enmascarado es irrelevante (las FK van deshabilitadas), pero la **traza** debe reflejar la jerarquía por buena práctica.

**Cambio (fichero `05`, en `proc_dm_pre_dep`, al inicio):** enumerar las FK de las tablas a enmascarar desde el diccionario y trazar una línea por relación, ordenando hija→padre:
```sql
FOR fk IN (
  SELECT c.owner        child_owner,  c.table_name child_table,
         c.constraint_name fk_name,    c.status,
         pk.table_name    parent_table, c.r_owner parent_owner
    FROM dba_constraints c
    JOIN dba_constraints pk ON pk.owner = c.r_owner AND pk.constraint_name = c.r_constraint_name
   WHERE c.constraint_type = 'R'
     AND c.owner = l_esquema
     AND c.table_name IN (SELECT DISTINCT table_name FROM tdm_columna_final
                           WHERE owner_name = l_esquema AND enmascarar = 'Y')
   ORDER BY c.table_name, pk.table_name   -- hija, luego padre
) LOOP
  proc_dm_trace(p_solicitud_id, p_ejecucion_id, 'PRE', 'FK_JERARQUIA',
     'hija: '||fk.child_owner||'.'||fk.child_table||
     ' -> padre: '||fk.parent_owner||'.'||fk.parent_table||
     ' (constraint '||fk.fk_name||', estado '||fk.status||')');
END LOOP;
```
Escribe en `tdm_mask_trace` vía `proc_dm_trace` con `solicitud_id` **y** `ejecucion_id` (respeta la jerarquía). No ejecuta DDL: es solo traza.

**Criterio de aceptación A.3:** para un esquema con FK entre tablas enmascaradas, `tdm_mask_trace` contiene eventos `FK_JERARQUIA` con `hija -> padre` y el estado de cada FK.

---

## BLOQUE B — LOGS Y CONTROL DE ERRORES

### B.1 — Añadir `solicitud_id` a `tdm_ejecucion_error` (cerrar la cadena de trazabilidad)

**Problema:** `tdm_ejecucion_error` solo tiene `ejecucion_id`. Un error de enmascaramiento no se puede bajar a su `solicitud` → trace → dep_estado.

**Cambios:**
1. **DDL (fichero `01`, donde se crea la tabla):** añadir columna y FK nullable:
```sql
solicitud_id NUMBER NULL,
CONSTRAINT fk_tdm_ejec_err_sol FOREIGN KEY (solicitud_id)
    REFERENCES tdm_mask_solicitud (solicitud_id)
```
   (Nullable a propósito: los errores de **descubrimiento** no tienen solicitud.)
2. **`98_uninstall.sql`**: sin cambios (la tabla ya se dropea con purge).
3. **Logger (fichero `05`, `proc_dm_log_ejec_error`):** añadir parámetro `p_solicitud_id IN NUMBER DEFAULT NULL` e incluirlo en el INSERT en la columna `solicitud_id`.
4. **Call sites:** en las llamadas desde enmascaramiento (`MASK_APPLY`, `MASK_CAT`, `POST_SYNC`, handler global) pasar `l_solicitud_id`. En llamadas de descubrimiento (si las hubiera) pasar `NULL`.

**Criterio de aceptación B.1:** un error provocado durante el enmascaramiento aparece en `tdm_ejecucion_error` con `ejecucion_id` **y** `solicitud_id`, y ese `solicitud_id` cruza con `tdm_mask_trace`/`tdm_mask_dep_estado`.

### B.2 — Errores de dependencia también a la tabla de error

**Problema:** en `proc_dm_pre_dep`/`proc_dm_post_dep`, cuando una constraint/trigger falla al deshabilitar o rehabilitar, el `WHEN OTHERS` solo actualiza `tdm_mask_dep_estado` (`deshabilitado_ok`/`habilitado_ok = 'N'`) y traza `WARN_*`. **No** registra en `tdm_ejecucion_error`.

**Cambio (fichero `05`, en los `WHEN OTHERS` de pre_dep y post_dep):** conservar la actualización de `dep_estado` y la traza `WARN_*` (nivel solicitud), y **añadir** el registro de nivel ejecución:
```sql
proc_dm_log_ejec_error(
  p_ejecucion_id => p_ejecucion_id,
  p_solicitud_id => p_solicitud_id,
  p_owner_name   => l_owner,
  p_table_name   => l_tabla,
  p_column_name  => NULL,
  p_etapa        => 'POST_DEP',   -- o 'PRE_DEP' según el bloque
  p_codigo_error => SQLCODE,
  p_mensaje      => SQLERRM,
  p_backtrace    => DBMS_UTILITY.FORMAT_ERROR_BACKTRACE
);
```
Así el fallo de dependencia queda en su nivel de detalle (`dep_estado` + `trace`, por `solicitud_id`) **y** en el nivel ejecución (`tdm_ejecucion_error`, con ambas claves).

**Criterio de aceptación B.2:** forzar el fallo de un `ENABLE VALIDATE` (p. ej. una FK con huérfanos) y verificar que aparece en las tres: `tdm_mask_dep_estado.habilitado_ok='N'`, `tdm_mask_trace` (`WARN_CONSTRAINT`), y `tdm_ejecucion_error` (`etapa='POST_DEP'`, con `solicitud_id`).

### B.3 — Check de invalidez post-rehabilitado, sin silenciar

**Problema:** tras `post_dep` se cuentan las dependencias con `habilitado_ok='N'` y se suma a `l_mask_errors` (bien), pero: (a) **no** se verifica invalidez de objetos, y (b) el check está dentro de `EXCEPTION WHEN OTHERS THEN NULL`, así que puede saltarse en silencio.

**Cambios (fichero `05`, bloque posterior a `proc_dm_post_dep` en `p_dm_enmascara`):**
1. **Quitar el `WHEN OTHERS THEN NULL`** que envuelve el conteo de `habilitado_ok='N'` (o, si se conserva, que registre el fallo del propio check en `tdm_ejecucion_error` con `etapa='POST_CHECK'`). El check de seguridad no puede saltarse en silencio.
2. **Añadir verificación de invalidez** sobre el/los esquema(s) afectados:
```sql
-- Objetos INVALID
SELECT COUNT(*) INTO l_invalidos
  FROM dba_objects
 WHERE owner = l_esquema
   AND status = 'INVALID';

-- Constraints que debian quedar ENABLED y no lo estan
SELECT COUNT(*) INTO l_cons_mal
  FROM tdm_mask_dep_estado d
  JOIN dba_constraints c
    ON c.owner = d.owner_name AND c.constraint_name = d.objeto_name
 WHERE d.solicitud_id = l_solicitud_id
   AND d.tipo_objeto  = 'CONSTRAINT'
   AND d.estado_previo = 'ENABLED'
   AND c.status <> 'ENABLED';

IF l_invalidos > 0 OR l_cons_mal > 0 THEN
  l_mask_errors := l_mask_errors + l_invalidos + l_cons_mal;
  proc_dm_trace(l_solicitud_id, p_ejecucion_id, 'POST', 'POST_CHECK_INVALID',
     'Objetos INVALID='||l_invalidos||' ; constraints no ENABLED='||l_cons_mal);
  proc_dm_log_ejec_error(
     p_ejecucion_id => p_ejecucion_id, p_solicitud_id => l_solicitud_id,
     p_owner_name => l_esquema, p_table_name => NULL, p_column_name => NULL,
     p_etapa => 'POST_CHECK', p_codigo_error => -20203,
     p_mensaje => 'Invalidez tras rehabilitar: INVALID='||l_invalidos||' cons_no_enabled='||l_cons_mal,
     p_backtrace => NULL);
END IF;
```
Como `l_mask_errors` ya alimenta el veredicto final (`ERROR`/`CON_ERRORES`), la invalidez **tumba la ejecución**, que es lo correcto antes de exportar a cliente.

**Criterio de aceptación B.3:** dejar deliberadamente un objeto INVALID o una constraint sin rehabilitar y verificar que la ejecución termina en `ERROR`, con traza `POST_CHECK_INVALID` y registro en `tdm_ejecucion_error` (`etapa='POST_CHECK'`, con `solicitud_id`).

---

## 4. Orden de implementación sugerido

1. **B.1** (columna `solicitud_id` + firma del logger) — base de todo lo demás en logs.
2. **B.2** y **B.3** (errores de dependencia + check de invalidez).
3. **A.1** (re-propagar en enmascarado) — cierra el hueco de RI real.
4. **A.3** (traza `FK_JERARQUIA`) y **A.2** (traza `RI_REINCLUYE`).

Cada punto es aislado y compila por separado; el motor debe quedar operativo entre punto y punto.

---

## 5. Restricciones "no romper"

- No eliminar ni alterar: mapa biyectivo (`tdm_mask_key_map`, `proc_dm_build_domain_map`, `proc_dm_pre_build_maps`), fail-closed C-1, `ORA_HASH(columna)`, `f_rank_ident`/Union-Find, la garantía PRE/POST (el `WHEN OTHERS` global sigue llamando a `proc_dm_post_dep`).
- No cambiar firmas públicas salvo `proc_dm_log_ejec_error` (se le añade `p_solicitud_id` con DEFAULT NULL, compatible hacia atrás) y la exposición pública de `proc_dm_propaga_dominios`.
- No introducir literales sin `DBMS_ASSERT` en SQL dinámico nuevo.
- `tdm_ejecucion_error.solicitud_id` **nullable**; nunca romper el INSERT de errores de descubrimiento.

---

## 6. Batería de pruebas (criterio objetivo de cierre)

1. **Compilación limpia:** `dba_errors` sin errores para los tres paquetes tras los cambios.
2. **Determinismo intacto:** enmascarar dos veces (mismo pepper) → valores idénticos (no se rompió la lógica).
3. **RI con validación del cliente (A.1):** hija puesta a `N` → tras enmascarar, KPI-08 = 0 huérfanos.
4. **Traza de jerarquía (A.3):** existen eventos `FK_JERARQUIA` con `hija -> padre`.
5. **Re-inclusión trazada (A.2):** existe `RI_REINCLUYE` para columnas re-incluidas.
6. **Cadena de error completa (B.1/B.2):** un fallo de dependencia aparece en `dep_estado` + `trace` + `tdm_ejecucion_error`, y el `solicitud_id` del error cruza con su trace.
7. **Invalidez tumba la ejecución (B.3):** objeto INVALID o constraint no rehabilitada → estado `ERROR` + `POST_CHECK_INVALID` + registro en tabla de error.
8. **Jerarquía de trazabilidad:** desde un `ejecucion_id` se alcanza `tdm_ejecucion_error`, y desde un error de enmascaramiento se baja por `solicitud_id` a `tdm_mask_trace`/`tdm_mask_dep_estado`.

---

## 7. Checklist para el revisor (Yair)

- [ ] `tdm_ejecucion_error` tiene `solicitud_id` (nullable, FK) y el logger lo puebla en errores de enmascaramiento.
- [ ] Errores de dependencia PRE/POST aparecen en `tdm_ejecucion_error` además de en `dep_estado`/`trace`.
- [ ] El check post-enable verifica invalidez y **no** está envuelto en `WHEN OTHERS THEN NULL`.
- [ ] `proc_dm_propaga_dominios` se ejecuta al inicio del enmascarado y respeta la validación del cliente.
- [ ] `tdm_mask_trace` muestra `FK_JERARQUIA` (hija→padre) y `RI_REINCLUYE`.
- [ ] `dm_validar_flujo`: KPI-08 y KPI-09 en verde sobre un esquema real; sin `APPLY_COL_MAP_GAP`.
- [ ] El motor compila y una corrida limpia termina `FINALIZADO`.
