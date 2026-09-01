# Handoff — Migración del generador biyectivo: afín → Feistel/FPE con clave (`DBMS_CRYPTO`)

> **Antigravity: alcance ESTRICTO y quirúrgico.** Este cambio **solo reemplaza el cuerpo de `f_map_bijective`** en `06_dm_pkg_func_mask.sql` por una permutación pseudoaleatoria con clave (Feistel/FPE con cycle-walking). **La firma `(p_val NUMBER, p_mod NUMBER) RETURN NUMBER` no cambia**, así que **todos los call sites quedan idénticos** (`func_nif`, `func_telefono`, `func_cuenta`, `func_iban`), el **mapa biyectivo (`tdm_mask_key_map`) y la propagación (Union-Find) no se tocan**, y el fail-closed, las fases y la trazabilidad tampoco. Solo se sustituye el *generador*.

---

## 1. Por qué (resumen del hallazgo)

El generador actual `f_map_bijective(x,m) = (a·x + c) mod m` es un **cifrado afín**: con **dos** pares `(original, enmascarado)` conocidos se despeja `a` y `c` (`a = (y₁−y₂)·(x₁−x₂)⁻¹ mod m`, `c = y₁−a·x₁`) y se **revierte todo el dominio**, sin necesitar el pepper. Y como `a`,`c` derivan solo del pepper (globales para NIF/teléfono/cuenta/IBAN), dos pares de un dominio rompen todos. Es **pseudonimización reversible, no anonimización**.

El objetivo es una función que sea **las dos cosas a la vez**: biyectiva (sin colisiones — lo que ya se ganó) **e** irreversible sin la clave (resistente a known-plaintext). Una función lineal no puede; una **permutación pseudoaleatoria con clave (Feistel/FPE)** sí. Beneficio extra: al usar **cycle-walking**, funciona sobre **cualquier módulo** (no solo `10^k`), lo que **elimina también el riesgo de coprimalidad de `func_cuenta`**.

---

## 2. Prerrequisito (una sola vez, fase SYS del instalador)

```sql
GRANT EXECUTE ON SYS.DBMS_CRYPTO TO ASTSYSADMIN;
```
`DBMS_CRYPTO` **no consume licencia** (Advanced Security cubre TDE/wallet/redaction, no la llamada al paquete). Añadir este grant en `99_install_datamasking.sql`, en el bloque que se ejecuta como SYS.

> **Compatibilidad de versión:** el diseño usa `HMAC_SH1`, disponible en **11g** en adelante. En 12c+ puede subirse a `HMAC_SH256` cambiando una constante (ver nota en `f_prf`). No usar `HMAC_SH256` si el piso real es 11g (allí no existe).

---

## 3. Diseño (reemplaza el cuerpo de `f_map_bijective` en `06`)

### 3.1 Clave HMAC cacheada por sesión
Junto a `g_pepper` (que ya existe), añadir:
```sql
  g_pepper_raw RAW(128);

  FUNCTION f_key_raw RETURN RAW IS
  BEGIN
    IF g_pepper_raw IS NULL THEN
      g_pepper_raw := UTL_RAW.CAST_TO_RAW(f_get_pepper);   -- reutiliza el pepper de tdm_secreto
    END IF;
    RETURN g_pepper_raw;
  END;
```

### 3.2 PRF con clave (función de ronda)
```sql
  -- PRF pseudoaleatoria con clave: HMAC-SHA1(pepper, ronda||dato) -> NUMBER
  FUNCTION f_prf(p_round PLS_INTEGER, p_data NUMBER) RETURN NUMBER IS
    l_mac RAW(20);
  BEGIN
    l_mac := DBMS_CRYPTO.MAC(
               UTL_RAW.CAST_TO_RAW(p_round||':'||TO_CHAR(p_data)),
               DBMS_CRYPTO.HMAC_SH1,        -- 11g-safe. En 12c+: DBMS_CRYPTO.HMAC_SH256
               f_key_raw);
    -- 14 hex (56 bits) -> NUMBER; suficiente para reducir mod 10^h (h<=10)
    RETURN TO_NUMBER(SUBSTR(RAWTOHEX(l_mac),1,14), 'XXXXXXXXXXXXXX');
  END;
```

### 3.3 Nuevo cuerpo de `f_map_bijective` (Feistel balanceado + cycle-walking)
**Misma firma. Solo cambia el interior.**
```sql
  FUNCTION f_map_bijective(p_val NUMBER, p_mod NUMBER) RETURN NUMBER IS
    c_rounds CONSTANT PLS_INTEGER := 8;   -- >=4 por Luby-Rackoff; 8 es holgado
    l_k   PLS_INTEGER;
    l_h   PLS_INTEGER;
    l_hi  NUMBER;      -- 10^h  (tamaño de cada mitad)
    l_x   NUMBER;
    l_l   NUMBER;
    l_r   NUMBER;
    l_t   NUMBER;
  BEGIN
    IF p_val IS NULL OR p_mod IS NULL OR p_mod <= 1 THEN
      RETURN p_val;
    END IF;
    l_k  := LENGTH(TO_CHAR(p_mod - 1));   -- nº de dígitos para representar [0, p_mod)
    l_h  := CEIL(l_k/2);
    l_hi := POWER(10, l_h);               -- dominio externo = l_hi*l_hi = 10^(2h) >= p_mod
    l_x  := MOD(ABS(p_val), p_mod);       -- normalizar al rango

    LOOP                                   -- cycle-walking: repite hasta caer en [0, p_mod)
      l_l := TRUNC(l_x / l_hi);
      l_r := MOD(l_x, l_hi);
      FOR i IN 1..c_rounds LOOP            -- red Feistel balanceada
        l_t := MOD(l_l + f_prf(i, l_r), l_hi);
        l_l := l_r;
        l_r := l_t;
      END LOOP;
      l_x := l_l * l_hi + l_r;             -- resultado en [0, 10^(2h))
      EXIT WHEN l_x < p_mod;              -- dentro de rango -> biyectivo sobre [0, p_mod)
    END LOOP;

    RETURN l_x;
  END;
```

**Por qué es correcto:**
- Una red Feistel es una **permutación por construcción** para *cualquier* función de ronda determinista → biyección garantizada, **sin colisiones** (mantiene lo ganado) y **sin depender de coprimalidad** (arregla `func_cuenta`).
- La función de ronda es una **PRF con clave** (HMAC): dos pares `(x,y)` conocidos **no** permiten derivar la clave ni predecir otros valores (a diferencia de la afín). **Irreversible sin el pepper.**
- **Cycle-walking** mantiene el resultado en `[0, p_mod)` y sigue siendo biyección; termina en ~10 iteraciones como mucho (un dígito extra).
- **Determinista:** pepper fijo → `f_prf` fija → misma entrada produce misma salida. La propagación por mapa sigue funcionando idéntica.

---

## 4. Qué NO tocar (obligatorio)

- **No cambiar la firma** de `f_map_bijective` ni ningún call site (`func_nif` L413, `func_telefono` L420/428, `func_cuenta` L465, `func_iban` L507). Siguen llamando `f_map_bijective(l_orig_num, <mod>)` igual.
- **No tocar** `tdm_mask_key_map`, `proc_dm_build_domain_map`, `proc_dm_pre_build_maps`, el Union-Find (`proc_dm_propaga_dominios`), el fail-closed C-1, las fases PRE/MASK/PROPAGACION/POST ni la trazabilidad.
- **No eliminar** `f_hash` ni el pepper de `tdm_secreto`: la clave HMAC se deriva del **mismo** pepper (reutilización, no un secreto nuevo).
- Mantener `DBMS_ASSERT` en el SQL dinámico existente. `DBMS_CRYPTO` se invoca **dentro** de funciones PL/SQL (no directamente en SQL), que es el patrón válido.
- Compatibilidad **11g**: usar `HMAC_SH1`. No introducir `HMAC_SH256` salvo que el piso confirmado sea 12c+.

---

## 5. Rendimiento (a tener en cuenta, no bloqueante)

- La FPE cuesta ~`c_rounds` llamadas HMAC por valor (8 por defecto). **Para columnas de dominio no importa**: `proc_dm_build_domain_map` llama al generador **una vez por valor DISTINTO**, no por fila. Para columnas de atributo enmascaradas inline por fila, es coste por fila; si alguna es de volumen muy alto, bajar `c_rounds` a 4 (sigue siendo PRP seguro por Luby-Rackoff) o enrutarla por un "dominio sintético" para pasar por el mapa.
- `f_key_raw` cachea la clave por sesión (como `g_pepper`), evitando re-derivarla por llamada. Esto además **elimina la redundancia** de la afín, que recalculaba `a`,`c` en cada invocación.

---

## 6. Criterios de aceptación (verificables)

1. **Compila** en la versión objetivo (`DBA_ERRORS` vacía). Con `HMAC_SH1` debe compilar en 11g+.
2. **Biyección / sin colisiones:** para un dominio de prueba, enmascarar N valores distintos y verificar N salidas distintas (0 duplicados). En particular, `KPI-06` (unicidad) y `KPI-08` (huérfanos/RI) siguen en verde sobre un esquema real.
3. **Cualquier módulo (arregla `func_cuenta`):** probar `f_map_bijective` con un `p_mod` que **no** sea potencia de 10 (p.ej. 999983) y verificar biyección sobre `[0, p_mod)` (inyectiva y en rango).
4. **Irreversibilidad / no-linealidad:** comprobar que **no** es afín — tomar tres valores `x, x+1, x+2` y verificar que las diferencias `f(x+1)−f(x)` y `f(x+2)−f(x+1)` **no** son constantes (una afín daría diferencia constante `a`). Este test debe **fallar** con la afín vieja y **pasar** con la FPE.
5. **Determinismo / RI:** enmascarar dos veces el mismo esquema con el mismo pepper → valores idénticos; padre e hija de cada FK con el mismo valor (KPI-08 = 0 huérfanos).
6. **Compatibilidad de datos:** el resultado respeta la longitud del dominio (nº de dígitos ≤ `l_k`) para que el dígito de control (DNI/NIE/CIF) y el checksum IBAN se calculen sobre un número válido — verificar `KPI-04`/`KPI-05` en verde.
7. **Rendimiento:** medir el tiempo de construcción de mapa de un dominio grande; si degrada demasiado, ajustar `c_rounds` (documentar el valor elegido).

---

## 7. Nota de documentación

Tras esta migración, actualizar el **README**: la versión `biyeccion` pasa de "unicidad determinista (pseudonimización reversible)" a **"biyección con permutación pseudoaleatoria con clave (anonimización: sin colisiones e irreversible sin el pepper)"**. Ese es el enunciado correcto una vez sustituido el generador.

---

## 8. Orden de implementación

1. Grant `DBMS_CRYPTO` en `99` (SYS).
2. `06`: añadir `g_pepper_raw`, `f_key_raw`, `f_prf`; reemplazar el cuerpo de `f_map_bijective`.
3. Recompilar (`dm_recompilar` / `99` ya valida `DBA_ERRORS`).
4. Ejecutar los criterios 1–7. Actualizar README.

Nada más cambia. Si algún criterio de aceptación no se cumple, **no** marcar como hecho.
