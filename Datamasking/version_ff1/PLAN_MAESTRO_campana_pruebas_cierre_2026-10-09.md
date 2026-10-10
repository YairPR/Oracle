# Plan maestro de la campana de pruebas de cierre del motor FF1 (v2)

Fecha: 2026-10-09. Sustituye a la v1 de hoy y al orden de ejecucion del runbook anterior (`runbook_cierre_pruebas_fuerza_2026-10-09.md`), cuyos bloques se reutilizan como procedimientos.

Cambio de enfoque de la v2, por indicacion del usuario: el motor es lo que descubre, enmascara y propaga dependencias, y se prueba solo eso; el piso de version es Oracle 11.2 en adelante. **Export/import con Data Pump queda fuera** (no es parte del motor; `pkg_dm_export` es un companion y no se prueba aqui; tampoco se usa Data Pump para la infraestructura de pruebas). Las pruebas se organizan segun los cinco pilares que el usuario define para el motor.

## 1. Definicion del motor y pilares a demostrar

| Pilar | Afirmacion defendible | Como se mide |
|---|---|---|
| D. Descubrimiento autonomo | Detecta de forma autonoma las columnas sensibles con alto acierto y pocos falsos positivos | Verdad conocida por construccion (tabla de verdad del generador) contra el resultado: recall y falsos positivos por nivel de confianza |
| M. Enmascarado y propagacion | Enmascara correctamente y propaga las dependencias de forma pulcra | Oraculo `VERIFICAR` (seccion 4) |
| P. Portabilidad 11.2 en adelante | El mismo codigo corre en cualquier base 11gR2 o superior | Auditoria estatica (hecha, ver diagnostico) + compilacion y pasadas en PREFORM 19c. Sin instancia 11.2 disponible: se declara como limitacion |
| S. Escala | El tuning permite manejar grandes volumenes | Pasadas M (unos 10 M filas) y L (unos 60 M), linealidad, recursos |
| T. Trazabilidad ordenada | Cada tabla de rastro tiene una funcion unica y clara, y cada procedimiento y funcion tiene su proposito documentado | Pruebas T-xx (seccion 6) y catalogo funcional |

Ademas, como defensa de seguridad: FF1 conforme a NIST SP 800-38G (vectores oficiales), pepper efimero, y ausencia de datos originales en las tablas de rastro.

## 2. Por que se acaban las recargas

El enmascarado es destructivo y no idempotente. Tres decisiones:

1. **Copia dorada y restauracion de un comando** por esquema de prueba (`*_GOLD`, copia dentro de la misma base, sin Data Pump). Restaurar es un bloque, no una recarga.
2. **Cada pasada responde a muchas preguntas** (seccion 5). Siete restauraciones en total.
3. **Oraculo automatico** (`VERIFICAR`): devuelve PASS/FAIL por criterio; se pega esa tabla en vez de revisar salidas a ojo.

## 3. Entornos y datos

| Esquema | Para que | Tamano |
|---|---|---|
| `DM_DUMMY` (S) | correccion, descubrimiento, interrupciones | ya existente, unos 0,5-1 M filas (dos tablas de 150 k) |
| `DM_PERF` (M) | rendimiento y reanudacion a escala media | unos 10 M filas, una tabla > 1 M (cruza el escalon de chunk de 8000 bloques) |
| `DM_PERF` (L) | volumen tipo SRI2006 | unos 60 M filas, una tabla > 10 M (escalon de 20000 bloques) |

M y L se generan con `CREATE TABLE ... AS SELECT ... CONNECT BY LEVEL`, en paralelo, no con el PL/SQL FORALL del script actual. El generador escribe a la vez los datos y la **tabla de verdad** (que columnas son sensibles y de que identificador), lo que permite medir el pilar D tambien a escala. Los datos incluyen los casos que ya rompieron el motor: DNI/NIE/CIF validos, IBAN ES, texto libre con PII embebida, dominios de 4 digitos, tablas con trigger de UPDATE por clave de negocio, FK en cadena, CLOB, columnas con nombre engañoso (senuelos) y columnas sensibles con nombre neutro.

Restauracion: por tabla `TRUNCATE` + `INSERT /*+ APPEND PARALLEL */ SELECT` desde la dorada, FK deshabilitadas durante la carga y rehabilitadas con validacion. Como la carga directa ignora PCTFREE, el layout fisico de las tablas de reanudacion se reaplica al final. La dorada de L es una copia de esquema; si el espacio no alcanza para el doble, L se corre una sola vez y se documenta.

## 4. El oraculo `VERIFICAR <esquema> <ejecucion>` (pilar M, y A de seguridad)

1. Filas por tabla iguales a la dorada.
2. Columnas NO marcadas Y: MINUS contra la dorada = 0.
3. Columnas Y: valor = funcion del motor aplicada al original con el pepper de la ejecucion. Completo en S; muestreo del 1 % por `ORA_HASH` en M y L. Las columnas con funciones especiales (documento segun tipo, IBAN continuo) se verifican con su funcion propia; cualquier otra diferencia es hallazgo.
4. Doble cifrado: `f(f(original))` = 0 filas. Sin enmascarar: 0 filas salvo justificacion.
5. Formato y longitud preservados por identificador.
6. Biyeccion: `COUNT(DISTINCT enmascarado) = COUNT(DISTINCT original)` en columnas con PK/UNIQUE.
7. Propagacion: mismo original en tablas distintas = mismo enmascarado; FK sin huerfanos; constraints, triggers e indices en su estado original y VALID.
8. Estado del motor: ejecucion FINALIZADA, 0 errores, sin tareas `TDM_%` ni jobs `TASK$` residuales, 0 objetos invalidos.
9. Sin fugas: ningun valor original (muestra) aparece en las tablas de rastro (`TDM_MASK_TRACE`, `TDM_EJECUCION_ERROR`, `TDM_COLUMNA_HIST`, `TDM_MASK_SOLICITUD`).

## 5. Las pasadas

| Pasada | Esquema | Que hace | Pilares | Restauraciones |
|---|---|---|---|---|
| P0 | S | Preparar dorada, tabla de verdad, restauracion y oraculo. Una vez | infraestructura | 0 |
| P1 | S | Gate de seguridad (vectores NIST), descubrimiento sin excepciones y con excepciones (mide recall y falsos positivos contra la verdad), pasada limpia, oraculo, observador de paralelismo, pruebas T-xx | D, M, T | 1 |
| P2 | S | UNA ejecucion interrumpida varias veces seguidas: durante una tabla en nivel 2 (jobs), la de trigger en nivel 1, una de menos de 100 k filas (UPDATE directo, se revierte entera y se rehace), post-dependencias, y entre columnas. Tras cada kill: monitor y reanudar. Al final: oraculo | M, T (reanudacion en todas las rutas) | 1 |
| P3 | S | Kill + `cancel DESCARTAR`, estado limpio, y nueva ejecucion sobre datos restaurados con el mismo resultado que P1. Pepper: ORA-20099 / ORA-20100 / purga sana | M, T | 1 |
| P4 | M | Descubrimiento a escala (tiempo y acierto), pasada limpia con AWR, tiempos por columna y por tamano de chunk, oraculo muestreado | S, D | 1 |
| P5 | M | Kill en la tabla grande con muchos chunks, reanudar, comparar contra P4 (coste de la interrupcion), oraculo | S, M | 1 |
| P6 | L | Pasada limpia unos 60 M: AWR/ASH, redo, undo, temp, FRA, tiempo total, oraculo muestreado | S | 1 |
| P7 | L | Un kill en la mayor tabla y reanudar (opcional: caida de instancia real si PREFORM lo permite) | S, M | 1 |

Siete restauraciones. Portabilidad (pilar P): compilacion limpia y P1 en 19c; el piso 11.2 queda respaldado por auditoria estatica.

## 6. Pruebas de trazabilidad (pilar T)

| ID | Comprobacion | Esperado |
|---|---|---|
| T-01 | Toda fila de `TDM_EJECUCION_ERROR` tiene su evento `ERROR.REGISTRADO` en `TDM_MASK_TRACE` (detalle `error_id=N ...`) y viceversa | 0 discrepancias |
| T-02 | Los pares (fase, paso) de `TDM_MASK_TRACE` pertenecen al vocabulario documentado | 0 fuera de catalogo |
| T-03 | Para una tabla cualquiera se recupera su historia: enmascarado en la traza (`detalle LIKE 'ESQUEMA.TABLA.%'`), clasificacion en `TDM_COLUMNA_HIST`, errores en `TDM_EJECUCION_ERROR` | las tres consultas devuelven datos coherentes entre si |
| T-04 | Tras cada interrupcion, el rastro permite saber desde donde se reanuda | coincide con el monitor |
| T-05 | Tiempo por columna disponible en el rastro (para el pilar S): `APPLY_COL` con `duracion_seg` | presente en todas las columnas Y |
| T-06 | Ninguna tabla de rastro contiene valores originales | 0 coincidencias |

T-01, T-02, T-03 y T-05 requieren los cambios de trazabilidad, **ya aplicados el 2026-10-09 en el codigo** (ver `TRAZA_ordenada_y_catalogo_funcional_2026-10-09.md`, que trae las consultas listas para cada prueba). Hasta que se compilen y se ejecute una corrida real siguen sin probar. T-06 se mide en el oraculo `VERIFICAR`.

## 7. Metricas de aceptacion

Pilar D (a acordar con el usuario, propuesta inicial): sobre columnas realmente sensibles, recall >= 95 % entre CONFIRMADO y PROBABLE; falsos positivos <= 2 % de las columnas con enmascarar = Y. Se reporta tambien por nivel de confianza y por tipo de identificador, y se listan uno a uno los fallos para clasificarlos (falta de regla, regla demasiado laxa, dato ya enmascarado).

Pilar S: no se inventa un objetivo. Referencia existente: ejecucion real 1 = 55 columnas, 23,2 M filas, 37 min (aprox. 630 000 filas por minuto). Hipotesis: tiempo por millon de filas aproximadamente constante de M a L, con tolerancia de 1,5 veces; mas es hallazgo a analizar con AWR. El nivel 1 (tablas con trigger) se mide aparte como coste de la proteccion contra deadlock GES. Recursos: pico de undo, temp, redo y FRA.

## 8. Comprobaciones previas de recursos (antes de P4)

```sql
select tablespace_name, round(sum(bytes)/1024/1024/1024,1) gb_libres
  from dba_free_space group by tablespace_name order by 2 desc;
select name, round(space_limit/1024/1024/1024,1) limite_gb, round(space_used/1024/1024/1024,1) usado_gb
  from v$recovery_file_dest;
select owner, round(sum(bytes)/1024/1024/1024,2) gb from dba_segments where owner like 'DM_%' group by owner;
select log_mode from v$database;
show parameter undo_retention
```

## 9. Que se entrega

1. `tests/campana_cierre.sql`: un unico script con modos `PREPARAR`, `GENERAR`, `RESTAURAR <esquema>`, `VERIFICAR <esquema> <ejecucion>`, `INFORME`. Sin scripts sueltos adicionales.
2. Informe por pasada con PASS/FAIL, tiempos y recursos, en el proyecto.

## 10. Fuera de alcance explicito

Export/import con Data Pump (no es parte del motor). E-05 (provocar deadlock apagando la proteccion), E-06 y G-03..G-06 (forzar ORA-06502/00001/12899 aislados): sin dato dedicado, ya reproducidos en incidentes reales documentados. Certificacion CAVP/CMVP: no existe para esta implementacion.

## 11. Estado

Hecho: N-02 (0 y 0), L-06; auditoria estatica de portabilidad y mapa de trazabilidad (ver `diagnostico_portabilidad_trazabilidad_2026-10-09.md`).
Decidido: piso de portabilidad 11.2, sin tocar la ruta paralela. Hecho el 2026-10-09 (sin compilar aun): traza ordenada, TDM_PARAMETRO con el catalogo de eventos, limpieza de duplicados, cabecera estandar en las 107 unidades, `ONLINE` retirado de los indices (el motor ya no exige Enterprise por eso). Pendiente: acuerdo de metricas del pilar D, comprobacion de recursos, P0 y todas las pasadas.
