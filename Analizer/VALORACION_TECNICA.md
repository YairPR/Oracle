# Valoración técnica de RAC Forensic Lab

Fecha de revisión: 2026-10-03  
Alcance revisado: pipeline local de ingesta y análisis de OCLUMON/CHM, AWR y SAR, almacenamiento DuckDB y reporte HTML autocontenido.

## 1. Resumen ejecutivo

El proyecto contiene una base técnica aprovechable: separa enrutamiento, parsers, persistencia, motor analítico y presentación; usa DuckDB para trabajar sin servidor; valida parte del contrato del dashboard con Pydantic; y el frontend compila con TypeScript. Sin embargo, **todavía no es confiable como herramienta de diagnóstico**. La prueba de humo incluida falla con los propios datos del repositorio, dos formatos/fuentes tienen soporte incompleto y el informe carga más información y gráficos de la necesaria desde el inicio.

Los síntomas reportados no son problemas aislados de CSS:

1. **Carga incorrecta o incompleta de métricas (criticidad alta).** OCLUMON se interpreta dos veces por motores diferentes; el parser de persistencia descarta secciones que el motor de episodios sí usa. AWR HTML se clasifica como desconocido y SAR sólo extrae memoria/swap, sin CPU, disco ni red.
2. **Lentitud de gráficos (criticidad alta).** El HTML incrusta el payload completo, hasta 50 000 eventos aunque sólo renderiza 500, y crea todos los objetos ECharts al arrancar, incluidos los de pestañas y paneles ocultos. Después conecta todos los gráficos en un único grupo y redimensiona todos ante cada cambio de tamaño.
3. **Falta de selección temporal (criticidad alta).** No existe control de fecha/hora ni un filtro temporal global. `dataZoom` permite acercar cada gráfico, pero no acota KPIs, episodios, tablas ni el resto de los gráficos de forma coherente.
4. **Confiabilidad insuficiente (criticidad alta).** El smoke test falla y termina por una excepción. Además, el pipeline omite errores por archivo y muchas consultas convierten excepciones en listas vacías, lo que puede presentar “sin datos” cuando en realidad hubo un error.
5. **Modelo de ejecución frágil (criticidad media/alta).** La carpeta se recorre completa, sin exclusiones ni orden determinista; una nueva ejecución borra todas las tablas del archivo DuckDB; y no existe validación explícita de solapamiento temporal entre fuentes.

**Valoración global: 4/10 (prototipo avanzado, no listo para uso operacional).** La prioridad debe ser corregir exactitud y observabilidad antes de pulir visualmente el HTML.

## 2. Evidencia reproducible

Se ejecutaron las comprobaciones existentes sobre el repositorio:

| Comprobación | Resultado | Lectura técnica |
|---|---|---|
| `python tests/smoke_test.py tests` | Falla | Se obtienen 1 260 filas OCLUMON frente a 2 520 esperadas; el porcentaje DB CPU del `snapshot_id=1` no coincide y después el test aborta al no encontrar un evento. |
| `npm run typecheck` | Pasa | Los contratos TypeScript son sintácticamente consistentes. No valida rendimiento ni comportamiento del navegador. |
| `python -m compileall -q Analizer` | Pasa | No hay errores sintácticos Python; no demuestra corrección funcional. |

El fallo ligado a `snapshot_id=1` también revela un defecto del propio test: la clasificación usa `os.walk()` sin ordenar archivos y los IDs se asignan en memoria según orden de ingesta. Por eso un ID técnico no es una referencia de negocio estable para afirmar qué snapshot contiene un evento. Las aserciones deben localizar el snapshot por host, instancia y rango de snapshots/tiempo.

## 3. Hallazgos por componente

### 3.1 Ingesta y descubrimiento de archivos

**Hallazgo A1 — recorrido indiscriminado de la carpeta (alto).** `clasificar_carpeta()` abre todos los archivos recursivamente. No excluye el DuckDB de salida, el HTML generado, directorios ocultos, dependencias, archivos grandes no compatibles ni enlaces simbólicos. Si la salida está dentro del caso, las ejecuciones sucesivas aumentan el trabajo de clasificación y el ruido `unknown`.

**Hallazgo A2 — procesamiento no determinista (alto).** Ni directorios ni archivos se ordenan antes de procesarse. Esto cambia IDs, orden de snapshots y resultados de pruebas entre sistemas de archivos.

**Hallazgo A3 — no hay manifiesto de entrada (alto).** No se registra tamaño, hash, fecha de modificación, tipo detectado, parser/version, filas aceptadas/rechazadas ni motivo de rechazo por archivo. El conteo actual no permite responder por qué “faltan métricas”.

**Hallazgo A4 — alineación temporal implícita (alto).** Se calcula un mínimo/máximo global, pero no se valida que AWR, OCLUMON y SAR correspondan a la misma zona horaria ni que sus ventanas se solapen. Tampoco se advierte sobre huecos, desfases o fuentes completamente disjuntas. Las fechas son `datetime` ingenuos, sin zona horaria.

**Hallazgo A5 — identificación débil del caso (medio).** El nombre base del directorio es el `caso_id`; dos rutas distintas con el mismo nombre colisionan conceptualmente. Es preferible un UUID de corrida más un nombre legible y un hash del manifiesto.

### 3.2 Parsers y calidad de métricas

**Hallazgo P1 — dos implementaciones de OCLUMON (crítico).** La ingesta llama a `parsers/oclumon.py`, mientras el análisis vuelve a abrir y parsear los mismos archivos mediante `core/episode_engine.py`. Esto duplica CPU/memoria y permite resultados contradictorios. El primer parser reconoce `TOP CONSUMERS`, `PROCESSES`, `DEVICES`, `FILESYSTEMS` y `NICS`, pero deliberadamente no extrae sus datos; el segundo sí construye estructuras ricas a partir del archivo crudo.

**Hallazgo P2 — AWR HTML no soportado (alto).** La propia prueba documenta que dos de siete reportes AWR HTML quedan como `unknown`. En un flujo manual es muy probable recibir AWR HTML, por lo que perder casi 29 % de una muestra válida no debe considerarse un caso marginal.

**Hallazgo P3 — SAR incompleto y no calibrado (alto).** El router y el parser declaran explícitamente que no fueron verificados contra una muestra real. El parser sólo persiste `MEM_USED_PCT`, `MEM_FREE_KB` y `SWAP_USED_PCT`; ignora CPU, `%iowait`, run queue, disco y red, métricas esenciales para correlacionar un incidente Oracle.

**Hallazgo P4 — errores degradados a ausencia de datos (alto).** Los parsers y la construcción del payload priorizan “nunca lanzar”. La resiliencia por archivo es correcta, pero el informe debe diferenciar claramente: sin fuente, formato no soportado, cero filas válidas, filas parcialmente rechazadas y error interno. Hoy varias de estas condiciones convergen en paneles vacíos.

**Hallazgo P5 — unidades y semántica sin catálogo central (medio).** Los nombres de métricas y unidades están repartidos entre parsers, motor de episodios, consultas, plantilla y specs de gráficos. Esto facilita que una métrica exista en DuckDB pero no se grafique o que el mismo concepto tenga claves distintas.

### 3.3 Persistencia y consultas

**Hallazgo D1 — borrado total en cada conexión de escritura (alto).** `ForensicStorage` limpia las ocho tablas por defecto, no sólo la corrida/caso actual. El esquema contiene `caso_id`, pero la implementación impide comparar casos o corridas en un mismo DuckDB. Si la limpieza falla, se continúa y pueden quedar duplicados.

**Hallazgo D2 — transacciones de alcance insuficiente (alto).** Cada lote de telemetría es transaccional, pero el caso completo no. Un fallo intermedio deja una base parcial que luego puede convertirse en un informe aparentemente válido.

**Hallazgo D3 — vista unificada costosa (medio/alto).** `_sql_eventos_unificados()` expande cada snapshot y wait event en muchas ramas `UNION ALL`; después esa expresión se ejecuta repetidamente para resumen, rango, tabla y cobertura. Se debería materializar una vista/tabla de presentación o resolver cada agregado sobre las tablas tipadas, con filtros de caso y tiempo.

**Hallazgo D4 — aislamiento de caso incompleto (alto).** Varias consultas de dashboard no filtran por `caso_id`. Hoy el borrado total oculta el problema; en cuanto se habilite comparación real entre corridas, mezclarán datos.

### 3.4 Payload, gráficos y rendimiento

**Hallazgo R1 — sobrecarga innecesaria del HTML (alto).** El payload lleva hasta 50 000 eventos al navegador, aunque la plantilla sólo genera 500 filas de tabla cruda. Además, el objeto `motor_episodios` incluye series completas y estructuras de diagnóstico. El mismo dato puede aparecer en tablas, series y evidencias derivadas.

**Hallazgo R2 — render eager de todos los gráficos (alto).** `montarCharts()` recorre cada `[data-chart]` durante el arranque. Inicializa canvas, datasets y opciones aun si la pestaña o el selector están ocultos. Esto explica la carga inicial lenta y obliga a redimensionamientos diferidos para corregir canvas creados con tamaño cero.

**Hallazgo R3 — sincronización global excesiva (medio/alto).** Todos los charts se guardan globalmente y `echarts.connect()` los conecta. Una interacción puede propagarse a gráficos no visibles o con dominios semánticos diferentes. El resize de ventana crea un temporizador por evento sin cancelación/debounce real y llama `resize()` sobre todas las instancias.

**Hallazgo R4 — no hay reducción de puntos (alto).** Las series se copian con `map()` y se entregan completas a ECharts. Para ventanas largas se necesita downsampling preservando extremos (por ejemplo LTTB/min-max por píxel), límites por serie y carga progresiva.

**Hallazgo R5 — informe autocontenido sin presupuesto (medio).** El enfoque offline es válido, pero falta un presupuesto verificable: tamaño máximo del HTML, número máximo de puntos visibles, tiempo de generación y tiempo hasta primera interacción. Sin estos límites, el comportamiento degrada proporcionalmente al caso.

### 3.5 Filtro de calendario y comparación temporal

**Hallazgo T1 — funcionalidad ausente (crítico respecto al requisito).** No existe `<input type="datetime-local">`, selector de rango ni calendario. `dataZoom` sólo altera la ventana visual de ECharts y no recalcula ni filtra el resto del reporte.

La solución recomendada es una **barra temporal global** con:

- fecha/hora inicial y final, con zona horaria visible;
- botones “Todo”, “Últimos 15 min”, “Última hora” y “Ventana del episodio”;
- validación `inicio <= fin` y aviso si una fuente queda fuera de rango;
- aplicación atómica a todos los gráficos, timeline, tablas, KPIs, episodios y top waits;
- contador de puntos/filas visibles y opción para restaurar el rango;
- persistencia del rango en la URL/hash o en `localStorage` para un HTML local;
- para comparación, dos ventanas etiquetadas A/B y normalización opcional por tiempo relativo (`T+00:00`) sin perder la fecha real.

La primera versión puede filtrar en cliente porque el informe es offline, pero sólo después de reducir el payload. Para volúmenes grandes, el modo `--servir` debería exponer consultas agregadas por rango.

### 3.6 HTML, UX y accesibilidad

**Hallazgo U1 — jerarquía extensa y repetitiva (medio).** AWR genera un panel/tabla por snapshot; OCLUMON puede generar múltiples paneles por nodo/dispositivo/filesystem. Conviene una vista resumen, drill-down y comparación, no una página que crece linealmente.

**Hallazgo U2 — trazabilidad temporal inconsistente (medio).** Algunos gráficos ya muestran fecha y hora, pero tablas de evidencia y tabla cruda siguen presentando sólo la hora. Esto es ambiguo al cruzar medianoche.

**Hallazgo U3 — estados vacíos no siempre accionables (medio).** El texto a veces explica una limitación, pero no presenta un resumen uniforme de archivos aceptados/rechazados ni una acción concreta para corregirlos.

**Hallazgo U4 — accesibilidad parcial (medio).** Las pestañas son botones, pero falta verificar semántica completa (`role=tablist/tab/tabpanel`, `aria-selected`, asociación y teclado). Los canvas necesitan alternativa textual/resumen tabular, y el contraste no sustituye etiquetas y unidades consistentes.

## 4. Diseño funcional propuesto desde la perspectiva DBA

La interfaz no debe ser una reproducción completa del reporte AWR ni una colección fija de gráficos. Debe responder, en este orden, las preguntas que un DBA necesita para hacer triage:

1. **¿La base estuvo realmente bajo carga?** DB Time, DB CPU, AAS, sesiones/CPU disponibles y duración exacta del snapshot.
2. **¿Dónde se consumió el DB Time?** CPU frente a clases de espera y eventos foreground, sin mezclar eventos background ni porcentajes con denominadores diferentes.
3. **¿Qué SQL explica la carga?** SQL ordenado por elapsed time, CPU time, buffer gets, physical reads y executions.
4. **¿La causa probable es CPU, I/O, concurrencia, aplicación o RAC?** Correlación con OCLUMON/SAR en la misma ventana y nodo.
5. **¿Qué evidencia permite verificar la conclusión?** Snapshot, instancia, SQL ID, evento, archivo y sección de origen; el texto crudo sólo como drill-down final.

Los nombres de Tim Hall, Tom Kyte, Mike Dietrich o FlashDBA pueden orientar la selección editorial, pero no deben convertirse en reglas codificadas bajo el nombre de una persona. Cada cálculo debe indicar numerador, denominador, unidad y sección AWR de procedencia; cada recomendación debe estar ligada a documentación Oracle y a evidencia del caso.

### 4.1 Cabecera adaptativa del dashboard

La cabecera debe dejar de ser sólo marca y navegación. Debe dividirse en tres niveles:

**Nivel 1 — identidad del caso**

- caso y `run_id`;
- DB name, DBID, versión, RAC/no RAC;
- instancia(s), host(s) y número de CPU/cores;
- snapshots inicial/final, fecha completa, zona horaria y duración;
- archivos cargados/aceptados/parciales/rechazados por fuente.

**Nivel 2 — control global**

- selector `Desde`/`Hasta` de fecha y hora;
- fuente, instancia/nodo y modo `Absoluto`/`Comparar A-B`;
- accesos rápidos a ventana completa, episodio seleccionado, 15 minutos y 1 hora;
- indicador de cobertura: una banda por AWR, OCLUMON y SAR que muestre huecos y solapamiento.

**Nivel 3 — síntesis condicionada por los datos**

- estado `Completo`, `Parcial` o `No interpretable`, nunca “OK” si falta una fuente requerida;
- DB Time, DB CPU, AAS máximo/promedio y capacidad CPU;
- clase de espera dominante;
- SQL ID de mayor impacto, únicamente si la sección SQL fue extraída;
- máximo `%iowait`/latencia de dispositivo, únicamente si SAR/OCLUMON aportan esa métrica.

En escritorio, identidad y filtros pueden compartir dos filas sticky. Por debajo de 900 px los filtros pasan a un panel desplegable; por debajo de 600 px cada KPI ocupa ancho completo, las tablas cambian a tarjetas y la cabecera deja de ser sticky para no consumir la pantalla. La adaptación debe depender del ancho del contenedor, no sólo del viewport, y ningún canvas puede tener ancho fijo.

### 4.2 Paneles AWR mínimos y reglas de activación

#### A. Carga y capacidad

| Visual | Datos | Decisión que soporta |
|---|---|---|
| AAS y capacidad CPU | `DB Time / elapsed`, CPU/cores | Determinar si la concurrencia activa supera la capacidad aproximada de CPU. No declarar saturación sólo porque AAS > 0. |
| DB Time frente a DB CPU | segundos por segundo y total por snapshot | Separar carga consumiendo CPU de carga esperando. |
| Throughput de negocio | executions/s, transactions/s, user calls/s, redo/s | Distinguir más trabajo real de una regresión de coste por operación. |
| Lecturas | logical reads/s, physical reads/s y writes/s | Identificar cambio de intensidad lógica/física; no interpretar logical reads como I/O físico. |

Los KPI se muestran sólo si hay al menos dos snapshots comparables o un snapshot con duración válida. Si se combinan instancias RAC, se debe permitir `Por instancia` y `Cluster`, dejando claro cuándo un valor es suma y cuándo promedio ponderado.

#### B. Composición del DB Time y esperas

- gráfico apilado por snapshot con `DB CPU` y wait classes foreground;
- tabla Top Events con evento, clase, waits, tiempo total, `% DB Time` y espera media;
- tendencia de los eventos dominantes, limitada por contribución acumulada al DB Time en vez de un “top 10” arbitrario;
- histograma de waits cuando AWR lo aporte, porque un promedio puede ocultar colas largas;
- background waits en un panel separado y colapsado: nunca sumarlos al `% DB Time` foreground.

Antes de dibujar, se debe validar que los porcentajes usan el mismo denominador. El código actual conserva FG/BG en la estructura rica pero sólo persiste TOP; el cambio correcto es modelar `scope` y `denominator`, no copiar todos a `pct_dbtime`.

#### C. SQL de mayor impacto

Se necesitan tablas tipadas para, al menos, estas secciones:

- SQL ordered by Elapsed Time;
- SQL ordered by CPU Time;
- SQL ordered by Gets;
- SQL ordered by Reads;
- SQL ordered by Executions;
- SQL ordered by Parse Calls, si está presente.

Cada fila debe conservar `sql_id`, plan hash value si existe, módulo, schema, executions, elapsed, CPU, buffer gets, disk reads, rows processed, fetches, parse calls, versión/plano y fragmento de SQL. Deben calcularse, sin inventar ceros cuando el denominador falte:

- elapsed/exec y CPU/exec;
- buffer gets/exec y reads/exec;
- porcentaje de DB Time atribuido;
- diferencia CPU–elapsed como señal de espera, no como wait event exacto;
- participación acumulada para mostrar el conjunto mínimo de SQL que explica, por ejemplo, el 80 % del coste disponible.

La vista predeterminada debe ser una tabla ordenable con barras en celda, no seis gráficos repetidos. Al seleccionar un SQL ID se abre un detalle con sus dimensiones, texto truncado de forma segura, snapshots en los que aparece y evolución. Un mismo SQL que aparece en varias listas debe deduplicarse por snapshot/instancia/SQL ID/plan hash y conservar las medidas de todas las listas.

#### D. I/O

- throughput y solicitudes por `IOStat by Function`;
- latencia/tiempo de servicio únicamente cuando la sección aporte tiempo y operaciones compatibles;
- reads/writes por tablespace o file type sólo para los mayores contribuyentes;
- correlación temporal con `%iowait`, queue depth y latencia de device de SAR/OCLUMON;
- asociación entre datafile y dispositivo únicamente si existe un mapeo verificable; nunca inferirlo por parecido de nombre.

El dashboard debe distinguir **demanda** (MB/s, IOPS), **latencia** (ms/op) y **tiempo de DB atribuido a User I/O**. Son conceptos relacionados pero no intercambiables.

#### E. RAC e interconnect

Este bloque sólo aparece para RAC y cuando existan datos:

- Global Cache Load Profile;
- tiempos de block receive/ping por instancia;
- eventos `gc cr*` y `gc current*` por tiempo y espera media;
- volumen de interconnect y errores/descartes de NIC privada;
- alineación por instancia/nodo entre AWR y OCLUMON.

La UI no debe afirmar “problema de interconnect” sólo por un evento `gc`. Debe mostrar conjuntamente contribución a DB Time, latencia de bloque, errores de red y asimetría entre nodos, e indicar qué evidencia falta.

#### F. Parsing, eficiencia y memoria

- executions frente a parses y hard parses;
- parse calls/exec y hard parse ratio, con volumen absoluto al lado;
- reloads/invalidations y métricas de library cache cuando estén disponibles;
- PGA/SGA y advisory sólo si el reporte fuente los contiene y se implementa semántica específica.

Los porcentajes de “Instance Efficiency” no deben convertirse por sí solos en semáforos. Un ratio alto puede coexistir con un volumen absoluto costoso; se usan como contexto y se correlacionan con parses, gets, waits y SQL.

### 4.3 Qué no se debe mostrar por defecto

- volcado de 50 000 métricas sin agrupación;
- una tarjeta por cada snapshot;
- todos los dispositivos/filesystems aunque no tengan actividad;
- ratios sin volumen y unidad;
- SQL text completo en una tabla general;
- un gráfico vacío por cada sección ausente;
- conclusiones universales basadas en un umbral fijo sin baseline, versión y capacidad.

La “tabla cruda” debe reemplazarse por un **explorador de evidencia** paginado y filtrable, inicialmente cerrado, al que se llegue desde “Ver evidencia” en un hallazgo. Cada fila debe incluir fuente, archivo, sección, snapshot, instancia, timestamp completo, métrica, valor y unidad.

### 4.4 Modelo de datos requerido

La estructura rica que ya produce `AwrSectionParser` no llega al almacenamiento. En vez de convertirla a unas pocas columnas de snapshot, se proponen hechos especializados:

```text
fact_awr_snapshot       -- identidad, tiempos y carga general
fact_awr_time_model     -- stat_name, time_s, pct_db_time
fact_awr_wait           -- scope, event, wait_class, waits, time_s, avg_ms, pct, denominator
fact_awr_sql            -- una fila canónica por snapshot/instancia/sql_id/plan_hash
bridge_awr_sql_ranking  -- ranking_type, rank, contribution_pct
fact_awr_iostat         -- function/filetype/tablespace, ops, bytes, time_s
fact_awr_rac            -- instancia/par, bloques, tiempo, ping, errores
fact_os_metric          -- OCLUMON/SAR normalizados con unidad y granularidad
source_file             -- hash, formato, parser_version, estado y diagnósticos
```

No conviene una tabla EAV genérica para todo AWR: simplifica la inserción pero complica tipos, unidades, claves y consultas. Sí puede mantenerse una tabla genérica sólo para métricas OS extensibles. Todas las tablas deben incluir `run_id`, `source_file_id`, `instance_id`, snapshot inicial/final y claves naturales únicas.

### 4.5 Estrategia concreta de parser AWR

1. Mantener el corte genérico por encabezado y posiciones de columnas usado por `AwrSectionParser` para texto.
2. Crear un registro de secciones con alias por versión de Oracle, columnas requeridas/opcionales, convertidores y validador semántico.
3. Hacer que cada extractor devuelva `rows`, `warnings`, `source_span` y `coverage`; nunca sólo una lista vacía.
4. Separar parseo de normalización. Primero preservar el valor y encabezado original; después convertir unidad y nombre canónico.
5. Añadir fixtures “golden” de cada sección y versión soportada, con totales conciliados contra el reporte.
6. Implementar AWR HTML mediante DOM/tablas, compartiendo la misma capa de normalización; no eliminar etiquetas HTML con regex para simular texto.
7. Persistir la estructura completa en una transacción de corrida y generar gráficos exclusivamente desde DuckDB.

La implementación actual ya extrae Time Model, Wait Class, histograma, Service Statistics, Instance Activity, IOStat e interconnect, pero deja esos datos en `ultima_estructura_completa`. Ése es el punto de extensión correcto: persistir y tipar esa salida antes de añadir visualizaciones. Para SQL será necesario extender el registro de secciones, porque las tablas `SQL ordered by ...` todavía no forman parte del contrato persistido.

Los dos archivos FlashDBA indicados por el usuario (`ejemplo_parse_flashdba.py` y `copia_web_flashdba_post.txt`) no están presentes en este checkout. Deben incorporarse como referencia versionada antes de implementar esa compatibilidad. El código tomado como ejemplo se tratará como referencia de formato/algoritmo, no como fuente de verdad de las fórmulas; también se debe comprobar su licencia y atribución antes de reutilizar código literal.

### 4.6 Motor de hallazgos, no motor de frases

Cada hallazgo debe ser un objeto auditable:

```text
id, categoría, severidad, intervalo, entidades,
observaciones[], cálculo, evidencia_ids[],
hipótesis[], evidencia_a_favor[], evidencia_en_contra[], faltantes[]
```

Ejemplo: “SQL concentró carga” sólo se emite si existe cobertura de la sección SQL y se puede cuantificar contribución. “Posible cuello de I/O” requiere DB Time en User I/O junto con latencia/throughput o declara explícitamente que falta corroboración OS. Los umbrales deben ser configurables, versionados y acompañados de baseline; no se debe asignar causalidad sólo por correlación temporal.

## 5. Arquitectura objetivo recomendada

```text
Carpeta del caso
  -> Inventario determinista + hash + detección de formato
  -> Parsers únicos por fuente (salida canónica y diagnósticos por fila)
  -> Validación/normalización (UTC + zona original, unidades, duplicados)
  -> DuckDB por corridas: case_run/source_file/metric_sample/awr_* / quality_issue
  -> Motor analítico sobre datos persistidos (no volver a parsear archivos)
  -> API de consulta local o exportación compacta por rango/resolución
  -> UI: filtro temporal global, carga diferida, downsampling y drill-down
```

Principios:

1. **Una sola interpretación por archivo.** El parser produce tanto muestras normalizadas como estructuras específicas necesarias para diagnóstico.
2. **Datos antes que presentación.** Cada gráfico consulta una métrica del catálogo; no conoce detalles del formato fuente.
3. **Corridas inmutables.** Nunca borrar datos históricos implícitamente; crear `run_id`, estado (`RUNNING/SUCCEEDED/PARTIAL/FAILED`) y transacción/promoción al finalizar.
4. **Calidad visible.** Toda pérdida de datos genera un `quality_issue` con archivo, línea, código, severidad y conteo.
5. **Rendimiento medible.** Definir presupuestos y medir por etapa, tamaño y cardinalidad.

## 6. Plan de corrección priorizado

### Fase 0 — línea base y bloqueo de regresiones (1–2 días)

- Corregir el smoke test para consultar snapshots por claves naturales, garantizar limpieza en `finally` y comprobar todos los resultados sin abortar en el primer `None`.
- Añadir fixtures pequeños y deterministas para OCLUMON, AWR texto, AWR HTML y variantes reales de SAR.
- Medir por etapa: inventario, parsing por fuente, inserción, análisis, payload, render HTML; registrar filas/s, memoria máxima, tamaño de salida y errores.
- Ordenar el inventario y excluir salida, DB, dependencias y archivos no regulares.

**Salida:** CI verde y un benchmark reproducible; no continuar a cambios visuales sin esta base.

### Fase 1 — exactitud y observabilidad (3–5 días)

- Unificar los dos parsers OCLUMON y hacer que el motor de episodios consuma DuckDB/salida canónica.
- Añadir soporte AWR HTML o rechazarlo explícitamente con diagnóstico visible y guía para exportar texto.
- Persistir Time Model, wait classes/histogramas, IOStat, RAC y las tablas `SQL ordered by ...` con procedencia de sección.
- Calibrar SAR con muestras reales y cubrir CPU, `%iowait`, run queue, disco y red.
- Crear catálogo de métricas con nombre canónico, fuente, unidad, tipo y regla de agregación.
- Implementar manifiesto y panel de calidad por archivo; distinguir `PARTIAL` de `SUCCESS`.
- Normalizar zona horaria y calcular cobertura/solapamiento por fuente y nodo.

**Salida:** conteos conciliables desde archivo hasta gráfico, sin silencios.

### Fase 2 — rendimiento (3–5 días)

- Reducir `payload.eventos` a las filas realmente mostradas o paginarlo; no incrustar 50 000 filas invisibles.
- Inicializar ECharts al activar una pestaña/panel mediante `IntersectionObserver` o un registro lazy; hacer `dispose()` si se descarta un panel.
- Conectar sólo charts temporales visibles y compatibles.
- Aplicar downsampling por resolución, `progressive`/`large` cuando proceda y `ResizeObserver` con debounce cancelable.
- Evitar consultas repetidas sobre el gran `UNION ALL`; filtrar siempre por `run_id/caso_id` y rango.

**Presupuesto propuesto:** HTML < 10 MB, primera interacción < 2 s para 1 millón de muestras de entrada, cambio de pestaña < 200 ms y máximo aproximado de 2 000 puntos por serie visible. Debe validarse en el hardware objetivo.

### Fase 3 — rango temporal y comparación (3–4 días)

- Implementar el selector global inicio/fin y un `TimeRangeStore` único.
- Filtrar todas las vistas y recalcular agregados derivados, no sólo el eje X.
- Añadir selección desde un episodio y zoom sincronizado reversible.
- Incorporar modo A/B con ventanas que pueden tener distinta fecha pero duración comparable.

### Fase 4 — pulido del informe (2–4 días)

- Reorganizar en: Resumen ejecutivo, Cobertura/calidad, Correlación temporal, OCLUMON, AWR, SAR y Evidencia/drill-down.
- Sustituir paneles repetidos de AWR por tabla maestra de snapshots + detalle seleccionado.
- Mostrar fecha completa, zona horaria, fuente, archivo y unidad en toda evidencia.
- Completar teclado/ARIA, estados de foco, versión imprimible y resumen textual alternativo de gráficos.

## 7. Criterios de aceptación

El proyecto estará listo para una prueba operacional cuando cumpla, como mínimo:

1. Todas las pruebas automáticas pasan y cubren al menos un fixture real por formato soportado.
2. Cada archivo aparece en un manifiesto como aceptado, parcial, rechazado o fallido, con conteos conciliables.
3. Volver a ejecutar el mismo caso produce el mismo inventario, IDs lógicos y resultados, sin borrar otras corridas.
4. Una ventana sin solapamiento entre fuentes genera una advertencia visible y nunca una correlación engañosa.
5. El rango del calendario filtra coherentemente todos los gráficos, KPIs, episodios y tablas.
6. El navegador no crea gráficos de pestañas ocultas y ninguna serie visible supera el presupuesto de puntos.
7. Se soportan explícitamente AWR texto/HTML y las variantes SAR aprobadas, o se rechazan antes de analizar con un mensaje inequívoco.
8. Un caso parcial nunca se presenta como análisis completo o saludable.
9. Los totales de DB Time, SQL y waits se concilian con su reporte AWR dentro de una tolerancia documentada.
10. Ningún porcentaje de wait mezcla scopes/denominadores y cada valor conserva archivo, sección y snapshot de origen.
11. La selección de un SQL ID explica elapsed, CPU, gets, reads y executions por snapshot sin duplicarlo por aparecer en varios rankings.
12. La cabecera muestra identidad, ventana, zona horaria y estado de cobertura correctamente en escritorio, tableta y móvil.

## 8. Decisión recomendada

No conviene reescribir el producto desde cero. DuckDB, Jinja2, Pydantic, TypeScript y ECharts son adecuados para una herramienta local. Sí conviene **refactorizar el flujo de datos antes de añadir más paneles**: parser único por fuente, modelo de corrida, calidad auditable, consultas por rango y render diferido. Una vez estabilizada esa columna vertebral, el calendario y el pulido visual serán cambios controlados; implementarlos sobre el pipeline actual sólo ocultaría errores y mantendría la lentitud.
