# OCLUMON: formatos, tiempo y calidad

Validación local del 5 de octubre de 2026. Las evidencias originales y sus informes no se sobrescriben. Los informes regenerados, bases y mediciones reproducibles están en `.work-oclumon/`, excluido de Git.

## Procedencia, formato y versión de Database

La procedencia declarada por el usuario es CHM/Grid **11.2.0.4** para los TXT de DEPT300 y recolector **19c** para los CSV de bov-wdrac-03/04/07. Es información documentada de estos archivos de prueba, no una regla del parser. Se mantienen tres conceptos independientes:

| Concepto | Evidencia | Uso |
|---|---|---|
| Versión del recolector/Grid | Manifest explícito con versión y referencia a la evidencia; desconocida si no se aporta | Información de procedencia por fuente |
| Formato | Cabeceras, secciones y registros leídos | Adaptador legacy o CSV por secciones |
| Versión de Oracle Database | Evidencia independiente de AWR/Database | Identidad de la base; no se copia de la versión del recolector |

Oracle presenta `-format csv` como novedad de **CHM 12.2.0.1.1** en [los cambios de esa versión](https://docs.oracle.com/en/database/oracle/oracle-database/12.2/atnms/changes-in-AHF-12-2-0-1.html). La referencia 11g muestra la salida legacy y no incluye ese parámetro. Esto precisa «desde 12c» sin asumir que todas las revisiones 12c lo incorporan. Tampoco significa que CSV identifique una Database 12c o 19c: versiones posteriores admiten también `-format legacy`.

Ambos adaptadores alimentan el mismo modelo y los mismos gráficos. Un `.csv` con texto legacy se interpreta como legacy; un `.txt` con cabeceras CSV se interpreta como CSV. Las pruebas comprueban esta independencia. `memavl` se presenta solo si existe una observación válida; no se rellena con `physmemfree`. Los contadores protocolarios siguen siendo acumulativos aunque vengan en CSV. Las tasas se identifican por su campo, unidad y definición Oracle, sin aplicar una conversión general «CSV → tasa».

La procedencia se incorpora con `--procedencia`, usando [el manifest de estos casos](procedencia-casos.json). No cambia los archivos de evidencia ni introduce versiones por defecto:

```text
python Analizer/analizador.py CARPETA_CASO --db SALIDA.duckdb --salida INFORME.html --procedencia Analizer/docs/oclumon-formatos-calidad/procedencia-casos.json
```

La calidad del informe muestra **formato detectado**, **recolector/Grid declarado** y **evidencia** por fuente. Sin manifest, el recolector queda «No documentado». El modo solo-reporte conserva la procedencia persistida y no acepta reemplazarla mediante el flag.

Orden de referencias: Oracle define métricas, unidades y comportamiento por versión; los originales demuestran lo observado; Brendan Gregg organiza utilización/saturación/errores; NIST sustenta los criterios estadísticos y el tratamiento de valores atípicos; el artículo de Marco orienta la presentación. Una heurística puede señalar una observación como cuestionada, pero no modificarla, contradecir su definición ni descartar silenciosamente un extremo.

## Causas confirmadas

1. Los CSV se reconocían como OCLUMON por contenido, pero el parser esperaba cabeceras legacy y fechas `MM-DD-YY`. Detectaba bloques `Node` sin aceptar muestras; la generación posterior tampoco toleraba un reloj ausente. El nuevo adaptador reconoce cabeceras por nombre y relojes con offset.
2. El nombre `nodo1` aparece en los tres archivos: no identifica al host. La identidad proviene de `Node`. Resultado verificado: `bov-wdrac-03`, `bov-wdrac-04`, `bov-wdrac-07`, 721 muestras por host y 721 instantes compartidos.
3. PROTOCOLS CSV contiene subtablas TCP, UDP e IP. Se interpretan por sus propias cabeceras. Sus contadores acumulativos se diferencian una sola vez; un inicio, reinicio o discontinuidad no equivale a cero errores.
4. El valor `764641210` de `xvdct` está en la fuente legacy, acompañado de una advertencia CHM. No se sustituye ni se interpreta como duración del episodio. Se conserva como observado cuestionado, con hora real del máximo y línea original.
5. El filesystem `/` declara `rootfs`, capacidad cero y `ifree%: -1` en la fuente. No constituye un disco de cero capacidad útil: se presenta como capacidad no disponible. Un filesystem con capacidad válida sigue representándose.
6. Las NIC de los CSV declaran `CLUSTER,ASM`, no `PRIVATE`. Se conservan los tipos e interfaces originales; no se atribuyen contadores del host a una interfaz ni se exige que exista PRIVATE para generar el informe.

## Interpretación y ejemplos

| Fuente | Interpretación | Transformación y presentación |
|---|---|---|
| `Clock: 2026-10-05 10.30.00+0200` | Instante con offset conocido | `2026-10-05T08:30:00Z`; originales y offset conservados. El navegador no cambia el instante por su zona local. |
| CPU inicial de wdrac03: `12.59` | Utilización del host | 12,59 %, sin transformación ni interpolación. wdrac04: 15,37 %; wdrac07: 37,05 %. |
| `physmemtotal=205768192` KB | Memoria física declarada | `/1024/1024 = 196,23583984375 GiB`; cabecera 196,24 GiB, por host. |
| `swpin` / `swpout` | Tasas KB/s | Actividad de swap cuando la tasa válida es positiva; swap ocupado por sí solo no demuestra actividad. |
| Contador protocolar constante | Total histórico del host | Incremento válido cero en el intervalo; no reproduce el total como errores actuales. |
| `wait: 764641210;...` en xvdct, 02-10-2026 09:54:16 | Media por I/O declarada y anotada por CHM | 764641210 ms conservados, calidad cuestionada; la regla >1 millón ms es una heurística del proyecto, no límite Oracle. Un valor válido de 1200 ms sigue siendo válido. |
| `mount: / type: rootfs total: 0 ... ifree%: -1` | Capacidad no disponible | Series de capacidad/porcentaje nulas; valores originales permanecen en DuckDB. |
| `N/C`, vacío, `-`, campo ausente | No representable/no disponible | Nulo, nunca cero; error de conversión se diagnostica por separado. |

Las unidades y significados se contrastaron con [Oracle 11g: Cluster Health Monitor](https://docs.oracle.com/cd/E11882_01/rac.112/e41959/troubleshoot.htm) y [Oracle: exportación dumpnodeview CSV](https://docs.oracle.com/en/database/oracle/oracle-database/12.2/atnms/oclumon-dumpnodeview.html). No se traslada arquitectura GIMR de versiones posteriores al caso 11g.

## Cambios

Adaptador común CSV/legacy, inventario dinámico, observaciones originales comprimidas en DuckDB dentro de la transacción de ingesta, identificación de duplicados/conflictos, cadencia observada y segmentos sin interpolación. Los episodios separan entidades y segmentos, distinguen comienzo y máximo, e incluyen fuente y línea.

El filtro aplicado gobierna gráficos, cronología, resúmenes de procesos y comparación A/B. Elegir una captura limita las fechas a esa captura; «Todas» permite una ventana personalizada más amplia. Borradores de fechas sobreviven al cambio de pestaña. Los gráficos conservan carga diferida, scroll libre sobre el canvas y cursor compartido entre los gráficos visibles.

La comparación A/B expone duración, cobertura, muestras válidas, medias, P95 lineal de muestras, máximo y hora, carga del host y cambios absolutos/relativos. Para tasas se usan intervalos completos y media ponderada por tiempo. Para `wait`, el P95 es de medias por intervalo: no es P95 de las operaciones originales. Los procesos se resumen por máximo individual entre PIDs listados del mismo nombre; no por suma atribuida íntegramente a Oracle. La resolución analítica es original, sin reducción visual.

Se usa la distinción de utilización, saturación y errores de [USE](https://www.brendangregg.com/usemethod.html); los umbrales del proyecto no demuestran causa de una eviction. La interpolación de percentiles es explícita porque existen diferentes convenciones, como recoge [NIST](https://www.itl.nist.gov/div898/handbook/eda/section3/eda35h.htm).

## Reproducción

En Windows usar un Python real, por ejemplo `.venv-pr3\Scripts\python.exe`, con las dependencias del proyecto.

```text
python Analizer/tests/smoke_test.py Analizer/tests
python -m unittest discover -s Analizer/tests -p test_contracts.py
python -m unittest discover -s Analizer/tests -p test_oclumon_formats.py
python -m compileall -q Analizer
cd Analizer/dashboard-ui
npm ci
npm test
npm run build
git diff --check
```

Para incluir los originales en las pruebas de formatos, definir `OCLUMON_CSV_CASE` y `OCLUMON_LEGACY_CASE` con las carpetas respectivas. Para medir una ejecución completa sin alterar evidencias:

```text
python Analizer/tests/profile_case.py CARPETA_CASO CARPETA_SALIDA
python Analizer/tests/browser_oclumon_test.py INFORME.html CARPETA_SALIDA --hosts 3
```

El navegador headless prueba apertura offline en Madrid, Los Ángeles y Tokio, filtros, captura, comparación A/B, rango vacío, cambios de pestaña, scroll sobre canvas y vista móvil. Las capturas y métricas acompañan los resultados en la carpeta de validación.

Resultado de la primera adaptación: smoke **19 comprobaciones OK**, contratos **4 tests OK**, formatos **11 tests OK incluyendo ambas pruebas sobre evidencias reales** (118,08 s), tests temporales y estadísticos frontend OK, TypeScript/build OK, `compileall` y `git diff --check` OK. Chromium validó cinco informes —CSV real de tres nodos, legacy real de dos y fixtures de uno/dos/cuatro— en tres zonas cada uno: **15 escenarios OK**. La cabecera legacy también se revisó visualmente: [captura](cabecera-legacy.png).

La primera repetición de formatos en el entorno restringido falló al crear fixtures en Temp; las dos pruebas de lectura real pasaron. La repetición con acceso autorizado a temporales pasó los once tests. En PowerShell, unittest escribe el progreso en stderr y la redirección puede presentarlo como `NativeCommandError`; el resultado de la suite está al final del log (`Ran 11 tests ... OK`).

## Rendimiento y límites

La primera referencia usa el código publicado `4149194`, los mismos archivos y el mismo entorno. El CSV anterior tarda 45,54 s y consume 132,67 MB de RSS máximo, pero acepta **cero muestras**; no constituye una comparación funcional de velocidad. La primera adaptación, **antes de las optimizaciones posteriores**, acepta 2163 muestras y 19467 hechos, tarda 109,57 s, consume 1474,27 MB de RSS máximo y genera 22,10 MB de HTML. El coste incluye observaciones originales durables y series de procesos a resolución completa. Las mediciones JSON separan ingesta, almacenamiento, episodios, serialización y navegador. Las cifras usan MB decimales y tiempos de una ejecución, no un benchmark estadístico. La siguiente sección contrasta la adaptación funcional con su versión optimizada.

| Caso y versión | Ejecución completa (s) | RSS máximo (MB) | HTML (MB) |
|---|---:|---:|---:|
| Tres CSV, antes (cero datos aceptados) | 45,54 | 132,67 | 0,73 |
| Tres CSV, después | 109,57 | 1474,27 | 22,10 |
| Legacy completo + cinco AWR, antes | 97,65 | 1186,52 | 16,07 |
| Legacy completo + cinco AWR, después | 347,31 | 4720,24 | 80,58 |

En legacy, la nueva ingesta tarda 171,84 s, episodios 155,76 s (incluye 44,56 s de persistencia) y HTML 18,01 s. En CSV: 73,20 / 31,84 / 3,94 s. La inserción conserva Arrow por lotes de 20000 y transacciones por archivo; el tiempo de persistir la fuente original se mide por separado. No se atribuye el coste completo a DuckDB. Los cuatro conjuntos AWR mantienen **cantidad y hash exactos** antes/después: cinco snapshots, 50 esperas, cinco filas en cada dimensión. Los hechos CHM aumentan de siete a nueve por muestra al incorporar tasas de swap.

En Chromium, tres zonas por informe: apertura CSV 1,54–2,43 s, filtro 169–280 ms, heap JS inicial 46,24–46,70 MB; legacy 4,30–5,85 s, filtro 251–315 ms, heap 113,87–118,94 MB. El heap JS no equivale al RSS total del navegador. Las pruebas no descargan recursos externos y no registran errores JavaScript. La prueba inspecciona metadatos sin transferir todo el payload al proceso de automatización.

Referencia del navegador con el mismo Chromium: CSV antiguo sin datos, apertura 0,24–0,31 s y heap 2,85 MB; legacy antiguo, 1,14–1,43 s y heap 71,15–78,32 MB. Mediciones: [CSV anterior](navegador-csv-antes.json) y [legacy anterior](navegador-legacy-antes.json). Estas aperturas confirman también el coste adicional del HTML ampliado; no se comparan filtros de interfaces con distinto contrato.

La primera adaptación tiene una **regresión de coste** respecto al código inicial, con capacidades distintas. La optimización posterior conserva cada observación y los originales durables; no reduce resolución para esconder el coste.

## Contraste Python / DuckDB y optimizaciones posteriores

Se mantiene la ingesta por Arrow `INSERT SELECT`, lotes de 20000 y transacciones por archivo. Coincide con [la ingesta Arrow de DuckDB](https://duckdb.org/docs/current/clients/python/data_ingestion) y evita [inserciones fila a fila](https://duckdb.org/docs/current/data/insert). No se sustituyó por `executemany`, no se quitaron restricciones de datos ni se desactivó la durabilidad.

`profile_oclumon.py` separa parsing y creación de series **sin DuckDB** sobre los primeros 180 bloques íntegros de cada archivo real; guarda hash del fragmento y de todos los puntos observados. Las pruebas después de optimizar conservan ambos hashes exactamente. `cProfile` localiza funciones/cantidad de llamadas; los tiempos comparables se miden **sin cProfile**, porque [Python advierte de su sobrecoste](https://docs.python.org/3/library/profile.html).

Hallazgos: reconstrucción repetida del diccionario de alias (354690 llamadas en legacy; 481545 en CSV), conversión repetida de los mismos timestamps, búsqueda lineal del mismo dispositivo para cada campo y matrices de procesos con millones de puntos ausentes. Las consultas de contexto AWR/CHM tardan décimas de segundo. La primera medición asignaba «persistir fuente» a almacenamiento, pero mezclaba JSON/gzip Python y SQL: ahora se publican `serializar_fuente_seg` y `sql_fuente_seg` por separado.

Cambios focalizados: cachés acotadas de nombres normalizados y conversiones de hora, índice por nombre de dispositivo conservando la primera observación y representación dispersa de **ausencias** de procesos. Cada tramo nulo conserva ambos extremos; se conserva **cada punto no nulo**, incluidos ceros y máximos. La cadencia procede del reloj completo del host. Las estadísticas para ventanas exhaustivas sobre la fixture de ausencias dan exactamente los mismos resultados que la representación completa. Los registros originales y su calidad permanecen en DuckDB.

No hay gráficos específicos por versión; se corrigió la activación por capacidad real tanto en series normales como en las compactas persistidas. Una lista de nulos ya no activa `memavl`; una observación cero sí cuenta como disponible.

Estas mediciones señalan el coste dominante en la transformación/representación Python de **estos casos**; no demuestran que DuckDB nunca pueda ser un cuello de botella. Los siguientes objetivos, si hicieran falta, serían reducir copias JSON/gzip y serializar por bloques antes de cambiar índices o parámetros SQL sin evidencia.

Resultados completos, comparando dos versiones **funcionales con los mismos datos aceptados**:

| Caso | Tiempo antes → optimizado | RSS máximo antes → optimizado | HTML antes → optimizado |
|---|---|---|---|
| Tres CSV | 109,57 → **58,36 s** | 1474,27 → **852,55 MB** | 22,10 → **12,40 MB** |
| Legacy + cinco AWR | 347,31 → **256,70 s** | 4720,24 → **2483,91 MB** | 80,58 → **40,89 MB** |

SQL de ingesta medido en la versión optimizada: CSV, hechos + commit **0,43 s**, originales **1,43 s**, frente a **7,79 s** de JSON/gzip de originales y 40,75 s de ingesta completa. Legacy, hechos + commit **6,18 s**, originales **4,61 s**, frente a **27,40 s** de JSON/gzip y 156,47 s de ingesta. Los tiempos SQL incluyen la interfaz Python y el enlace de parámetros: no son tiempos internos puros del motor. Persistir episodios sigue costando 29,72 s en legacy y generar HTML 16,04 s; queda margen para optimización. Las ejecuciones fueron secuenciales, sin cProfile; son observaciones de una ejecución por versión, con posible variación de carga/caché del equipo.

Equivalencia verificada en ambos casos: cantidades y hashes de todas las tablas de hechos/AWR; BLOBs gzip de originales **idénticos byte a byte**; cada valor, hora y marca de límite en **6139 series CSV / 4800 legacy**; episodios, cronología y ventanas de captura idénticos. El manifest modifica solo la procedencia documentada. Evidencia: [equivalencia completa](optimized-equivalence.json), [series CSV](csv-series-equivalence.json), [series legacy](legacy-series-equivalence.json), [CSV optimizado](csv-optimizado.json), [legacy optimizado](legacy-optimizado.json).

En navegador, nueva apertura CSV 1,72–2,10 s y legacy 2,94–3,44 s. Heap JS inicial CSV 38,48–45,53 MB y legacy 76,66–85,81 MB. El filtro varía entre 229–372 ms en CSV y 252–337 ms en legacy: no se afirma mejora del filtrado, que conserva el mismo funcionamiento. [Mediciones CSV](navegador-csv-optimizado.json), [mediciones legacy](navegador-legacy-optimizado.json).

Resultado final optimizado: **19 smoke**, **4 contratos**, **14 tests de formatos con ambas evidencias reales** (97,20 s), estadísticas/tiempo frontend y TypeScript/build OK, compileall y diff-check OK. Los dos informes reales pasaron tres zonas por informe, filtros, A/B, rango vacío, scroll, móvil, procedencia independiente y activación correcta de `memavl`: **6 escenarios reales offline**, sin errores JS ni peticiones externas. Capturas actuales revisadas visualmente: [CSV](cabecera-csv.png), [legacy sin memavl inventado](cabecera-legacy.png), [móvil](movil-csv.png).

Para repetir la investigación:

```text
python Analizer/tests/profile_oclumon.py ARCHIVO_REAL SALIDA_PERFIL --blocks 180
python Analizer/tests/profile_case.py CARPETA_CASO SALIDA_COMPLETA --provenance Analizer/docs/oclumon-formatos-calidad/procedencia-casos.json
python Analizer/tests/compare_report_state.py BASE_ANTES.duckdb BASE_DESPUES.duckdb EQUIVALENCIA.json
```

Perfiles del fragmento: [legacy antes](perfil-legacy-before.txt), [legacy después](perfil-legacy-after.txt), [CSV antes](perfil-csv-before.txt), [CSV después](perfil-csv-after.txt). Los JSON homónimos guardan los tiempos sin profiler y los hashes del fragmento/puntos válidos. Los tiempos de cProfile sirven para localizar operaciones, no para anunciar porcentajes globales de mejora.

Resultados: [CSV antes](csv-antes.json), [CSV después](csv-despues.json), [aceptación de los tres CSV](csv-aceptacion.json), [legacy antes](legacy-antes.json), [legacy después](legacy-despues.json), [equivalencia AWR](awr-equivalencia.json), [evidencia original](evidencia-fuentes.json), [navegador CSV](navegador-csv.json), [navegador legacy](navegador-legacy.json). Capturas verificadas: [cabecera](cabecera-csv.png), [móvil](movil-csv.png), [periodo vacío](periodo-vacio.png).

PROCESS AGGREGATE, NFS, ADVM y ASMINST_DB se conservan como registros originales y se declaran omitidos de la analítica. Dos HTML AWR del caso antiguo se clasifican como desconocidos en este pipeline; los cinco AWR de texto mantienen su procesamiento existente. Los registros raw se consultan en DuckDB; no se duplica todo el texto original en el HTML.

Una fuente legacy sin offset no adquiere una zona inventada. Si un informe mezcla zona desconocida y offset conocido, la comparación A/B se desactiva. No se infieren pertenencia configurada al RAC, CPU agregada de procesos, atribución física de bonds/discos ni causalidad de errores/MTU. El soporte de futuras variantes de unidades requiere verificar sus cabeceras antes de ampliar el contrato.
