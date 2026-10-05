/**
 * charts.ts -- construccion de graficos ECharts. Reglas de diseno pedidas
 * explicitamente por el usuario, aplicadas en TODOS los graficos de este
 * modulo:
 *   - dataset/series separados (nunca se arma un option.series con los
 *     valores embebidos a mano -- siempre dataset.source + series.encode).
 *   - leyenda FUERA del area de trazado (legend arriba, grid con top
 *     reservado).
 *   - huecos de muestreo visibles, nunca interpolados (connectNulls:false
 *     en cada serie de linea).
 *   - unidades distintas en graficos separados (cada chart-box del HTML
 *     ya declara una sola unidad, ver Jinja2 -- este modulo no mezcla).
 *   - comparaciones entre nodos con el mismo color estable (ver colors.ts).
 */

import * as echarts from "echarts/core";
import { LineChart, ScatterChart, CustomChart, BarChart } from "echarts/charts";
import {
  GridComponent, LegendComponent, TooltipComponent, DataZoomComponent,
  DatasetComponent, MarkLineComponent, TitleComponent,
} from "echarts/components";
import { CanvasRenderer } from "echarts/renderers";
import type { Payload, DatosSerie } from "./types";
import { colorDeNodo, colorDeSeveridad, lineTypeDeNodo } from "./colors";
import { escapeHtml } from "./util";
import { epochMs, lowerBound, axisRange } from "./temporal-state";

echarts.use([
  LineChart, ScatterChart, CustomChart, BarChart,
  GridComponent, LegendComponent, TooltipComponent, DataZoomComponent,
  DatasetComponent, MarkLineComponent, TitleComponent, CanvasRenderer,
]);

// Mismos 8 tonos categoricos validados por la skill `dataviz` (orden fijo)
// que templates/static/theme.css / colors.ts usan para nodos -- aca se usa
// el set completo (una serie de metrica, no de nodo, puede necesitar hasta
// 5 colores en renderSerieChart) en el MISMO orden, nunca ciclado al azar.
const PALETA_METRICA = ["#3987e5", "#d95926", "#199e70", "#c98500", "#d55181"];

// Tinta/superficie del tema oscuro (espejo de templates/static/theme.css)
// -- ECharts no lee variables CSS del documento que lo embebe, asi que
// estos valores se repiten aca a proposito.
const INK_PRIMARY = "#ffffff";
const INK_SECONDARY = "#c3c2b7";
const INK_MUTED = "#898781";
const GRIDLINE = "#2c2c2a";
const SURFACE = "#1a1a19";
const BORDE = "rgba(255,255,255,0.12)";

// *** HITO "rediseno AWR + tabs + LogRouter acotado" (2026-10-02) ***
// Bug reportado en la auditoria externa (sec. 1/3): el tooltip y el eje X
// solo mostraban HH:MM:SS, sin fecha -- en un caso cuyo rango cruza
// medianoche (o cuyas fuentes AWR/oclumon caen en dias distintos) dos
// instantes de dias diferentes podian mostrar la MISMA hora, destruyendo
// la trazabilidad del incidente. Se agrega dia+mes siempre.
function aFechaLegible(epochSeg: number): string {
  const d = new Date(epochSeg * 1000 + (window.__PAYLOAD__.display_clock?.offset_minutes || 0) * 60000);
  return d.toLocaleString("es-ES", {
    day: "2-digit", month: "2-digit", hour: "2-digit", minute: "2-digit", second: "2-digit",
    timeZone: "UTC",
  });
}

function baseOption(titulo: string | null, metric?: string, node?: string) {
  const info=metric ? window.__PAYLOAD__.motor_episodios.metric_contracts?.[metric] : undefined;
  return {
    useUTC: true,
    animation: false,
    title: titulo ? { text: titulo, left: 0, top: 0, textStyle: { fontSize: 11, color: INK_SECONDARY, fontWeight: 400 } } : undefined,
    // bottom:38 (antes 28) -- el formatter de xAxis ahora puede emitir
    // etiquetas de 2 lineas ("DD/MM\nHH:mm", ver axisLabel.formatter mas
    // abajo), 28px alcanzaba para una sola linea y las recortaba.
    grid: { left: 42, right: 16, top: titulo ? 46 : 34, bottom: 38 },
    legend: {
      top: titulo ? 20 : 2, left: 0, icon: "roundRect", itemWidth: 10, itemHeight: 10,
      textStyle: { fontSize: 11, color: INK_SECONDARY },
      inactiveColor: INK_MUTED,
    },
    tooltip: {
      trigger: "axis",
      className: "odl-chart-tooltip",
      confine: true,
      backgroundColor: SURFACE,
      borderColor: BORDE,
      borderWidth: 1,
      extraCssText: "max-width:280px;white-space:normal;font-size:11px;box-shadow:0 6px 20px rgba(0,0,0,.5);",
      formatter: (params: any[]) => {
        if (!params || !params.length) return "";
        // params[0].value[0] ya viene en epoch-ms (puntosADataset multiplica
        // por 1000 al armar el dataset) -- aFechaLegible espera epoch-SEGUNDOS,
        // de ahi la division: sin ella la hora mostrada queda multiplicada por
        // 1000 una segunda vez (bug reportado en la auditoria externa, sec. 3.1).
        const t = aFechaLegible(params[0].value[0] / 1000);
        const zone=window.__PAYLOAD__.display_clock?.label || 'zona no declarada';
        let html = `<div style="font-weight:600;margin-bottom:4px">${escapeHtml(t)} · ${escapeHtml(zone)}</div>`;
        for (const p of params) {
          if (p.value == null || p.value[1] == null) continue;
          const valor = (p.value[2] ? '<' : '') + new Intl.NumberFormat('es-ES', {maximumFractionDigits:3}).format(p.value[1]);
          html += `<div><span style="color:${p.color}">●</span> ${escapeHtml(node || p.seriesName)}: <b>${escapeHtml(valor)} ${escapeHtml(info?.unit || '')}</b></div>`;
          if(metric?.endsWith('::wait_ms') && p.value[1]>1000000) html += '<div>Extremo observado; validez pendiente.</div>';
        }
        return html;
      },
    },
    // El rango temporal se controla exclusivamente desde la barra global.
    // No se muestra slider por grÃ¡fico y ningÃºn gesto de rueda/arrastre
    // modifica el dominio: la rueda queda siempre libre para la pÃ¡gina.
    dataZoom: [],
    // formatter por granularidad (nativo de ECharts, en vez de calcular
    // espaciado de ticks a mano): a nivel dia/mes muestra "DD/MM", a nivel
    // hora/minuto antepone "DD/MM\n" a la hora -- asi la fecha SIEMPRE es
    // explicita en el eje, no solo en el tooltip (misma correccion que
    // aFechaLegible, pedida en la auditoria externa sec. 1/3).
    xAxis: {
      type: "time",
      axisLabel: {
        fontSize: 10,
        color: INK_MUTED,
        formatter: (valor: number) => aFechaLegible(valor / 1000).replace(", ", "\n"),
      },
      axisLine: { lineStyle: { color: GRIDLINE } },
      splitLine: { show: false },
    },
    yAxis: { type: "value", axisLabel: { fontSize: 10, color: INK_MUTED }, splitLine: { lineStyle: { color: GRIDLINE } }, axisLine: { show: false } },
  };
}

// La unidad va PEGADA al titulo (en vez de como yAxis.name flotante) a
// proposito -- el nombre de eje de ECharts se posiciona por fuera del
// grid, en la misma franja vertical que el titulo/leyenda reservados por
// baseOption(), y con poco margen (franjas de ~45px) terminaba pisando la
// leyenda. Un titulo "TrÃ¡fico interconnect (KB/s)" es ademas mas legible
// de un vistazo que un eje con una etiqueta de 2 caracteres.
function tituloConUnidad(title: string | undefined, unit: string | undefined): string | null {
  if (!title) return null;
  return unit ? `${title} (${unit})` : title;
}

const datasetCache = new WeakMap<object, (number | null)[][]>();
export function puntosADataset(puntos: DatosSerie | null | undefined): (number | null)[][] {
  if (!puntos) return [];
  const cached=datasetCache.get(puntos);
  if (cached) return cached;
  let result: (number | null)[][];
  if (Array.isArray(puntos)) result=puntos.map(p=>Array.isArray(p)?[p[0]*1000,p[1],p[2]||0]:[p.t*1000,p.v,p.lt?1:0]);
  else {
    const times=window.__PAYLOAD__.motor_episodios.series_timestamps?.[puntos.clock] || [];
    const nulls=new Set(puntos.nulls), lt=new Set(puntos.lt);
    result=times.map((t,i)=>[t*1000, nulls.has(i)?null:(puntos.values?puntos.values[i]:puntos.constant ?? null),lt.has(i)?1:0]);
  }
  datasetCache.set(puntos,result);
  return result;
}

/** Un nodo, 1+ series de metrica superpuestas (p.ej. interconnect_latency_ms
 * + interconnect_kbps NO se mezclan nunca -- unidades distintas, ver
 * Jinja2 -- esto es para 2 series de la MISMA unidad, como cpu_pct+cpuq
 * no, esas tampoco se mezclan; en la practica casi siempre se llama con
 * una sola serie). Colores por METRICA (no por nodo, ya que el nodo es
 * fijo para este chart). */
export function renderSerieChart(
  el: HTMLElement, payload: Payload,
  spec: { node: string; series: string[]; title?: string; unit?: string; area?: boolean; nombres?: string[] },
): void {
  const chart = echarts.init(el, undefined, { renderer: "canvas" });
  const datosNodo = payload.motor_episodios.series_por_nodo?.[spec.node] || {};
  const series = spec.series.map((nombreSerie, i) => {
    const puntos = puntosADataset(datosNodo[nombreSerie] as DatosSerie | undefined);
    const color = PALETA_METRICA[i % PALETA_METRICA.length];
    return {
      name: spec.nombres?.[i] || nombreSerie,
      type: "line",
      showSymbol: puntos.length < 60,
      symbolSize: 4,
      connectNulls: false, // hueco de muestreo visible, nunca interpolado
      lineStyle: { width: 1.6, color, type: lineTypeDeNodo(spec.node) },
      itemStyle: { color },
      // Area sombreada opcional (pedido del audit externo 2026-10-02 para
      // el panel fusionado "Trafico total Rx/Tx") -- opacidad baja a
      // proposito, el area es un refuerzo visual del volumen, nunca debe
      // competir con la linea ni con el tooltip.
      areaStyle: spec.area ? { color, opacity: 0.12 } : undefined,
      data: puntos,
    };
  });
  const sinDatos = series.every((s) => s.data.length === 0);
  if (sinDatos) {
    el.innerHTML = `<div class="odl-empty-state">Sin datos para ${escapeHtml(spec.node)} en este caso.</div>`;
    return;
  }
  chart.setOption({
    ...baseOption(tituloConUnidad(spec.title, spec.unit),spec.series[0],spec.node),
    series,
  });
  registrarChart(chart);
}

/** Comparacion de la MISMA serie entre varios nodos -- color estable por
 * nodo (ver colors.ts), la vista "CPU y cola de ejecucion" / "Errores UDP"
 * / "Latencia de disco" de la maqueta del usuario. */
export function renderSerieMultiNodo(
  el: HTMLElement, payload: Payload,
  spec: { serie: string; nodos: string[]; title?: string; unit?: string; yMin?: number; yMax?: number },
): void {
  const chart = echarts.init(el, undefined, { renderer: "canvas" });
  const series = spec.nodos.map((nodo) => {
    const puntos = puntosADataset(payload.motor_episodios.series_por_nodo?.[nodo]?.[spec.serie] as DatosSerie | undefined);
    const color = colorDeNodo(nodo);
    return {
      name: nodo,
      type: "line",
      showSymbol: puntos.length < 60,
      symbolSize: 4,
      connectNulls: false,
      lineStyle: { width: 1.6, color, type: lineTypeDeNodo(nodo) },
      itemStyle: { color },
      data: puntos,
    };
  });
  const sinDatos = series.every((s) => s.data.length === 0);
  if (sinDatos) {
    el.innerHTML = `<div class="odl-empty-state">Sin datos de "${escapeHtml(spec.serie)}" en este caso.</div>`;
    return;
  }
  chart.setOption({
    ...baseOption(tituloConUnidad(spec.title, spec.unit),spec.serie),
    series,
  });
  if (spec.yMin !== undefined || spec.yMax !== undefined) {
    chart.setOption({ yAxis: { min: spec.yMin, max: spec.yMax } });
  }
  registrarChart(chart);
}

/**
 * Cronologia correlacionada -- el panel insignia de la maqueta del
 * usuario: una fila por nodo (linea de tiempo con marcadores de
 * episodio/evento) + una fila de "cobertura OCLUMON" (banda solida donde
 * hay telemetria real, trama rayada donde NO la hay -- "sin telemetria",
 * NUNCA se inventa continuidad donde no hay muestras).
 */
export function renderCronologia(el: HTMLElement, payload: Payload): void {
  const nodeList = payload.motor_episodios.node_list || [];
  if (nodeList.length === 0) {
    el.innerHTML = '<div class="odl-empty-state">Sin nodos con telemetria OCLUMON en este caso -- no hay cronologia que graficar.</div>';
    return;
  }

  // Fila aparte para episodios cuyo nodo NO matchea ningun nombre de
  // nodeList (p.ej. un evento de alert log, que usa nombre de INSTANCIA
  // -- "DEPT3001" -- mientras que node_list usa HOSTNAME de oclumon --
  // "bov-racsalud-301"; esquemas de nombre sin reconciliar, ver auditoria
  // tecnica) -- nunca se mezclan esos puntos con la fila de cobertura, que
  // es una banda de telemetria, no un cajon para eventos sin nodo.
  const filas = [...nodeList, "Otros / sin nodo OCLUMON", "Cobertura OCLUMON"];
  const FILA_OTROS = nodeList.length;
  const chart = echarts.init(el, undefined, { renderer: "canvas" });

  // Each capture is a separate band; nulls preserve the internal gaps.
  const episodios = payload.informe.diagnostico.episodios;
  const puntos: any[] = [];
  const lineasVerticales: any[] = [];
  for (const ep of episodios) {
    const tIni = (epochMs(ep.inicio) ?? NaN);
    const filaIdx = ep.nodo && nodeList.includes(ep.nodo) ? nodeList.indexOf(ep.nodo) : FILA_OTROS;
    puntos.push({
      value: [tIni, filas[filaIdx], ep.resumen, ep.severidad],
      itemStyle: { color: colorDeSeveridad(ep.severidad) },
    });
    if (ep.severidad === "critical") {
      lineasVerticales.push({ xAxis: tIni });
    }
  }

  const dataBanda = payload.motor_episodios.ventanas_captura.flatMap((c, i) => [
    ...(i ? [[(epochMs(c.inicio) || 0)-1, null]] : []),
    [epochMs(c.inicio), "Cobertura OCLUMON"], [epochMs(c.fin), "Cobertura OCLUMON"],
  ]);

  chart.setOption({
    useUTC: true, animation: false,
    grid: { left: 140, right: 20, top: 10, bottom: 30 },
    tooltip: {
      confine: true,
      backgroundColor: SURFACE,
      borderColor: BORDE,
      borderWidth: 1,
      extraCssText: "max-width:280px;white-space:normal;font-size:11px;box-shadow:0 6px 20px rgba(0,0,0,.5);",
      formatter: (p: any) => {
        if (!p || !p.value) return "";
        const [t, , resumen] = p.value;
        return `<div style="font-size:11px;max-width:260px;color:${INK_SECONDARY}">${escapeHtml(aFechaLegible(t / 1000))}<br/><b style="color:${INK_PRIMARY}">${escapeHtml(resumen || "")}</b></div>`;
      },
    },
    xAxis: { type: "time", axisLabel: { fontSize: 10, color: INK_MUTED, formatter: (ms: number) => aFechaLegible(ms/1000) }, axisLine: { lineStyle: { color: GRIDLINE } }, splitLine: { show: false } },
    yAxis: {
      type: "category",
      data: filas,
      axisLabel: {
        fontSize: 11,
        color: INK_SECONDARY,
        formatter: (v: string) => (v.length > 18 ? v.slice(0, 17) + "â€¦" : v),
      },
      axisLine: { lineStyle: { color: GRIDLINE } },
      splitLine: { lineStyle: { color: GRIDLINE } },
    },
    series: [
      {
        name: "Cobertura OCLUMON",
        type: "line",
        lineStyle: { width: 10, color: "#199e70", opacity: 0.55 },
        showSymbol: false,
        connectNulls: false,
        data: dataBanda,
        z: 1,
        markLine: lineasVerticales.length
          ? {
              silent: true, symbol: "none", label: { show: false },
              lineStyle: { color: colorDeSeveridad("critical"), type: "dashed", width: 1 },
              data: lineasVerticales,
            }
          : undefined,
      },
      {
        name: "Episodios",
        type: "scatter",
        symbolSize: 10,
        data: puntos,
        z: 2,
      },
    ],
  });
  registrarChart(chart);
}

/** Series globales que ya armaba analizador.py desde antes (AWR
 * db_cpu_per_sec/aas, un punto por snapshot AWR) -- no viven en
 * series_por_nodo (no estan particionadas por nodo+motor de episodios),
 * se leen directo de payload.series_cpu / payload.series_aas. (Hito
 * "rediseno AWR", 2026-10-02: se quito "series_gipcd" -- Clusterware/
 * gipcd es una fuente retirada del pipeline desde el Hito de
 * simplificacion, el panel que la usaba quedo siempre vacio.) */
export function renderSerieCruda(
  el: HTMLElement, payload: Payload, spec: { fuente: "series_cpu" | "series_aas"; clave?: string; title?: string; unit?: string },
): void {
  const chart = echarts.init(el, undefined, { renderer: "canvas" });
  const puntos = spec.fuente === "series_cpu" ? payload.series_cpu : payload.series_aas;
  const dataset = puntosADataset(puntos as DatosSerie | undefined);
  if (!dataset.length) {
    el.innerHTML = '<div class="odl-empty-state">Sin datos.</div>';
    return;
  }
  chart.setOption({
    ...baseOption(tituloConUnidad(spec.title, spec.unit)),
    series: [{
      name: spec.title || spec.fuente,
      type: "line",
      showSymbol: dataset.length < 60,
      symbolSize: 4,
      connectNulls: false,
      lineStyle: { width: 1.6, color: PALETA_METRICA[0] },
      itemStyle: { color: PALETA_METRICA[0] },
      data: dataset,
    }],
  });
  registrarChart(chart);
}

/** Variante de renderSerieCruda para 2+ series globales de la MISMA unidad
 * superpuestas en un solo chart -- caso de uso: Parses/sec vs Executes/sec
 * (panel Mike Dietrich, Grafico 3.1). Cada `fuente` debe ser una clave de
 * payload cuyo valor es PuntoSerie[] (mismo contrato que series_cpu/
 * series_aas, ver analizador.py::construir_payload). */
export function renderSerieCrudaMulti(
  el: HTMLElement, payload: Payload,
  spec: { fuentes: string[]; nombres?: string[]; title?: string; unit?: string },
): void {
  const chart = echarts.init(el, undefined, { renderer: "canvas" });
  const series = spec.fuentes.map((fuente, i) => {
    const dataset = puntosADataset((payload as any)[fuente] as DatosSerie | undefined);
    const color = PALETA_METRICA[i % PALETA_METRICA.length];
    return {
      name: spec.nombres?.[i] || fuente,
      type: "line",
      showSymbol: dataset.length < 60,
      symbolSize: 4,
      connectNulls: false,
      lineStyle: { width: 1.6, color },
      itemStyle: { color },
      data: dataset,
    };
  });
  const sinDatos = series.every((s) => s.data.length === 0);
  if (sinDatos) {
    el.innerHTML = '<div class="odl-empty-state">Sin datos.</div>';
    return;
  }
  chart.setOption({
    ...baseOption(tituloConUnidad(spec.title, spec.unit)),
    series,
  });
  registrarChart(chart);
}

/**
 * Panel Tom Kyte (Grafico 1.1, auditoria externa sec. "Metodologia Tom
 * Kyte"): el verdadero peso del DB Time, desglosado por categoria y
 * apilado por snapshot de AWR -- NUNCA una linea aislada de AAS, que no
 * explica el "por que" (critica textual del usuario: "DE AWR NADA MAS
 * GRAFICAS EL AAS?"). Eje X categorico (uno por snapshot AWR, con
 * host+fecha en la etiqueta -- no eje de tiempo continuo, ya que un
 * snapshot AWR es un INTERVALO de 1h, no un instante) en vez del eje de
 * tiempo que usan el resto de los charts de este modulo.
 *
 * `payload.awr_dbtime_breakdown` ya viene agregado por categoria desde
 * SQL (analizador.py, GROUP BY sobre fact_awr_wait_events) -- este
 * modulo solo pivota filas -> series apiladas, nunca suma a mano.
 */
export function renderBarraApiladaDbTime(
  el: HTMLElement, payload: Payload,
): void {
  const filas = (payload as any).awr_dbtime_breakdown as
    { etiqueta: string; categoria: string; segundos: number }[] | undefined;
  if (!filas || filas.length === 0) {
    el.innerHTML = '<div class="odl-empty-state">Sin snapshots de AWR en este caso.</div>';
    return;
  }

  // Mismos colores que la tabla de Top Wait Events (color_wait_class,
  // core/html_builder.py::_WAIT_CLASS_COLOR) -- consistencia visual entre
  // el chart apilado y la tabla detallada que esta debajo en el HTML.
  const COLOR_CATEGORIA: Record<string, string> = {
    "DB CPU": "#199e70",
    "User I/O": "#3987e5",
    "Cluster": "#d95926",
    "Concurrency + Application": "#d55181",
    "Otros": "#898781",
  };
  const ORDEN_CATEGORIA = ["DB CPU", "User I/O", "Cluster", "Concurrency + Application", "Otros"];

  const etiquetas: string[] = [];
  for (const f of filas) if (!etiquetas.includes(f.etiqueta)) etiquetas.push(f.etiqueta);

  const chart = echarts.init(el, undefined, { renderer: "canvas" });
  const series = ORDEN_CATEGORIA.map((cat) => {
    const porEtiqueta = new Map(filas.filter((f) => f.categoria === cat).map((f) => [f.etiqueta, f.segundos]));
    return {
      name: cat,
      type: "bar",
      stack: "dbtime",
      barMaxWidth: 46,
      itemStyle: { color: COLOR_CATEGORIA[cat] },
      data: etiquetas.map((e) => porEtiqueta.get(e) ?? 0),
    };
  }).filter((s) => s.data.some((v) => v > 0));

  chart.setOption({
    grid: { left: 48, right: 16, top: 34, bottom: 56 },
    legend: {
      top: 2, left: 0, icon: "roundRect", itemWidth: 10, itemHeight: 10,
      textStyle: { fontSize: 11, color: INK_SECONDARY }, inactiveColor: INK_MUTED,
    },
    tooltip: {
      trigger: "axis",
      className: "odl-chart-tooltip",
      confine: true,
      backgroundColor: SURFACE,
      borderColor: BORDE,
      borderWidth: 1,
      extraCssText: "max-width:280px;white-space:normal;font-size:11px;box-shadow:0 6px 20px rgba(0,0,0,.5);",
      formatter: (params: any[]) => {
        if (!params || !params.length) return "";
        let html = `<div style="font-size:11px;font-weight:600;margin-bottom:4px;color:${INK_PRIMARY}">${escapeHtml(params[0].axisValue)}</div>`;
        for (const p of params) {
          if (!p.value) continue;
          html += `<div style="font-size:11px;color:${INK_SECONDARY}"><span style="display:inline-block;width:8px;height:8px;border-radius:50%;background:${p.color};margin-right:5px"></span>${escapeHtml(p.seriesName)}: <b style="color:${INK_PRIMARY}">${escapeHtml(String(p.value))}s</b></div>`;
        }
        return html;
      },
    },
    xAxis: {
      type: "category",
      data: etiquetas,
      axisLabel: { fontSize: 10, color: INK_MUTED, interval: 0, rotate: etiquetas.length > 4 ? 20 : 0 },
      axisLine: { lineStyle: { color: GRIDLINE } },
      splitLine: { show: false },
    },
    // Sin yAxis.name a proposito: el nombre de eje de ECharts se
    // posiciona arriba del grid, en la misma franja que la leyenda
    // (top:2,left:0) y terminaba superpuesto con ella -- mismo motivo
    // documentado en tituloConUnidad() mas arriba. La unidad ya queda
    // clara en el panel-note de Jinja2 y en el sufijo "s" del tooltip.
    yAxis: {
      type: "value",
      axisLabel: { fontSize: 10, color: INK_MUTED },
      splitLine: { lineStyle: { color: GRIDLINE } },
      axisLine: { show: false },
    },
    series,
  });
  registrarChart(chart);
}

export function reflowCharts(): void {
  const charts = (window as any).__odlCharts as any[] | undefined;
  if (!charts) return;
  for (const c of charts) {
    try {
      const dom = c.getDom?.() as HTMLElement | undefined;
      if (dom?.offsetParent !== null) c.resize();
    } catch { /* panel desmontado -- se ignora */ }
  }
}

interface TemporalChart { chart: any; series: any[]; times: number[][]; symbols: boolean[]; names: string[]; applied?: string }
const temporalCharts: TemporalChart[] = [];
let cursorFrame: number | undefined;
export function syncVisibleCursors(): void {
  for (const {chart} of temporalCharts) chart.getDom().querySelector('.odl-shared-cursor')?.remove();
}
function synchronizeCursor(active: any, value: number): void {
  if (cursorFrame !== undefined) cancelAnimationFrame(cursorFrame);
  cursorFrame = requestAnimationFrame(() => {
    cursorFrame = undefined;
    syncVisibleCursors();
    for (const {chart} of temporalCharts) {
      const dom = chart.getDom() as HTMLElement, box = dom.getBoundingClientRect();
      if (chart === active || !box.height || box.bottom <= 0 || box.top >= innerHeight) continue;
      const x = chart.convertToPixel({xAxisIndex:0}, value);
      if (!Number.isFinite(x) || x < 42 || x > box.width - 16) continue;
      const line = document.createElement('div');
      line.className = 'odl-shared-cursor';
      line.style.left = `${x}px`;
      dom.appendChild(line);
    }
  });
}
function registrarChart(chart: any): void {
  (window as any).__odlCharts = (window as any).__odlCharts || [];
  (window as any).__odlCharts.push(chart);
  // Read options once at registration, never on each global filter.
  const option=chart.getOption();
  if (option.xAxis?.[0]?.type === "time") {
    const timeOf=(p:any)=>Number(Array.isArray(p)?p[0]:p.value?.[0]);
    const series=(option.series || []).map((s:any)=>[...(s.data || [])].sort((a,b)=>timeOf(a)-timeOf(b)));
    temporalCharts.push({chart,series,names:(option.series || []).map((s:any)=>s.name),symbols:(option.series || []).map((s:any)=>s.showSymbol),times:series.map((points:any[])=>points.map(p=>Number(Array.isArray(p)?p[0]:p.value?.[0])))});
    chart.on('updateAxisPointer', (event: any) => {
      const axis = event.axesInfo?.find((a: any) => a.axisDim === 'x');
      if (axis && Number.isFinite(axis.value)) synchronizeCursor(chart, axis.value);
    });
    chart.getZr().on('globalout', () => {
      if (cursorFrame !== undefined) cancelAnimationFrame(cursorFrame);
      cursorFrame = undefined;
      syncVisibleCursors();
    });
  }
}
export function aplicarRangoTemporalCharts(from: number, to: number): void {
  syncVisibleCursors();
  const axis=axisRange({from,to});
  const key=`${from}:${to}`;
  for (const entry of temporalCharts) {
    const {chart,series,times,symbols,names}=entry;
    if (chart.getDom().offsetParent === null || entry.applied === key) continue;
    let hasData=false;
    const filtered=series.map((points:any[],i:number)=> {
      const lo=lowerBound(times[i],from), hi=lowerBound(times[i],to+1);
      let data=points.slice(lo,hi);
      if (names[i] === "Cobertura OCLUMON") {
        // Clip each real capture band, never bridge the null-separated gaps.
        data=[];
        let start:number|undefined, end:number|undefined;
        const flush=():void=> {
          if (start===undefined || end===undefined) return;
          const a=Math.max(from,start), b=Math.min(to,end);
          if (a<=b) {
            if (data.length) data.push([a-1,null]);
            data.push([a,"Cobertura OCLUMON"],[b,"Cobertura OCLUMON"]);
          }
          start=end=undefined;
        };
        for (const point of points) {
          if (point[1]===null) flush();
          else { if (start===undefined) start=point[0]; end=point[0]; }
        }
        flush();
      }
      if (data.some(p=>(Array.isArray(p)?p[1]:p.value?.[1]) != null)) hasData=true;
      return {data,showSymbol:from===to && data.length>0 ? true : symbols[i]};
    });
    chart.setOption({xAxis:{min:axis.from,max:axis.to},series:filtered,
      graphic:[{id:"odl-sin-datos-rango",type:"text",left:"center",top:"middle",invisible:hasData,
                style:{text:"Sin datos en este intervalo",fill:INK_SECONDARY,fontSize:12}}]});
    entry.applied=key;
  }
}
