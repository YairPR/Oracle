/**
 * main.ts -- punto de entrada del bundle. Lee window.__PAYLOAD__ (el JSON
 * que analizador.py embebe en el HTML final, ver generar_reporte_html())
 * y monta: la cronologia correlacionada, cada chart declarado via
 * [data-chart] en el HTML server-renderizado (Jinja2 decide CUALES
 * paneles existen -- ver core/dashboard_engine.py -- este bundle solo
 * sabe DIBUJAR lo que ya se decidio mostrar), la navegacion del sidebar y
 * los filtros.
 */

import { registrarNodos } from "./colors";
import {
  renderSerieChart, renderSerieMultiNodo, renderCronologia, renderSerieCruda,
  renderSerieCrudaMulti, renderBarraApiladaDbTime, reflowCharts, syncVisibleCursors,
} from "./charts";
import { inicializarNav } from "./nav";
import { inicializarSelectorPanel, inicializarExpandirEvidencia, inicializarFiltrosTimeline } from "./filters";
import type { Payload } from "./types";
import { initializeAnalysis, initializeProcessSummaries } from "./analysis";
import { inicializarRangoTemporal } from "./time-range";

interface ChartSpec {
  kind: "serie" | "multi-nodo" | "cronologia" | "serie-cruda" | "serie-cruda-multi" | "barra-apilada-dbtime";
  node?: string;
  nodos?: string[];
  series?: string[];
  nombres?: string[];
  area?: boolean;
  serie?: string;
  title?: string;
  unit?: string;
  yMin?: number;
  yMax?: number;
  fuente?: "series_cpu" | "series_aas";
  fuentes?: string[];
  clave?: string;
}

function montarChart(el: HTMLElement, payload: Payload): void {
    if (el.dataset.chartMounted === "true" || el.offsetParent === null) return;
    const raw = el.getAttribute("data-chart");
    if (!raw) return;
    let spec: ChartSpec;
    try {
      spec = JSON.parse(raw);
    } catch {
      el.innerHTML = '<div class="odl-empty-state">Especificacion de grafico invalida.</div>';
      return;
    }
    el.dataset.chartMounted = "true";
    if (spec.kind === "cronologia") {
      renderCronologia(el, payload);
    } else if (spec.kind === "multi-nodo" && spec.serie) {
      renderSerieMultiNodo(el, payload, {
        serie: spec.serie, nodos: spec.nodos || payload.motor_episodios.node_list,
        title: spec.title, unit: spec.unit, yMin: spec.yMin, yMax: spec.yMax,
      });
    } else if (spec.kind === "serie" && spec.node && spec.series) {
      renderSerieChart(el, payload, {
        node: spec.node, series: spec.series, nombres: spec.nombres,
        area: spec.area, title: spec.title, unit: spec.unit,
      });
    } else if (spec.kind === "serie-cruda" && spec.fuente) {
      renderSerieCruda(el, payload, { fuente: spec.fuente, clave: spec.clave, title: spec.title, unit: spec.unit });
    } else if (spec.kind === "serie-cruda-multi" && spec.fuentes) {
      renderSerieCrudaMulti(el, payload, { fuentes: spec.fuentes, nombres: spec.nombres, title: spec.title, unit: spec.unit });
    } else if (spec.kind === "barra-apilada-dbtime") {
      renderBarraApiladaDbTime(el, payload);
    }
}

/** Observa únicamente charts de paneles visibles. rootMargin prepara el
 * siguiente bloque antes de entrar al viewport sin montar toda la pestaña. */
function crearGestorCharts(payload: Payload): () => void {
  const observados = new WeakSet<HTMLElement>();
  let resizeFrame: number | undefined;
  const resizeObserver = new ResizeObserver(() => {
    if (resizeFrame !== undefined) window.cancelAnimationFrame(resizeFrame);
    resizeFrame = window.requestAnimationFrame(reflowCharts);
  });
  const observer = new IntersectionObserver((entradas) => {
    for (const entrada of entradas) {
      if (!entrada.isIntersecting) continue;
      const el = entrada.target as HTMLElement;
      montarChart(el, payload);
      if (el.dataset.chartMounted === "true") {
        resizeObserver.observe(el);
        document.dispatchEvent(new CustomEvent("odl:chart-mounted"));
      }
      observer.unobserve(el);
    }
  }, { rootMargin: "500px 0px", threshold: 0.01 });

  return (): void => {
    document.querySelectorAll<HTMLElement>("[data-chart]").forEach((el) => {
      if (el.dataset.chartMounted === "true" || el.offsetParent === null || observados.has(el)) return;
      observados.add(el);
      observer.observe(el);
    });
  };
}

function main(): void {
  const payload = window.__PAYLOAD__;
  if (!payload) {
    // eslint-disable-next-line no-console
    console.error("RAC Forensic Lab: window.__PAYLOAD__ no esta presente -- el informe no se puede renderizar.");
    return;
  }
  registrarNodos(payload.motor_episodios.node_list || []);
  const prepararChartsVisibles = crearGestorCharts(payload);
  prepararChartsVisibles();
  document.addEventListener("odl:panel-visible", () => {
    prepararChartsVisibles();
  });
  inicializarNav();
  // Selectores de la seccion OCLUMON (rediseno "meramente grafico",
  // 2026-10-02) -- cada uno controla su propio grupo de paneles
  // (data-panel-group), ver templates/dashboard.html::sec-oclumon.
  inicializarSelectorPanel("odl-selector-device", "device");
  inicializarSelectorPanel("odl-selector-fs", "fs");
  inicializarSelectorPanel("odl-selector-proc-nodo", "proc-nodo");
  inicializarExpandirEvidencia();
  inicializarFiltrosTimeline();
  inicializarRangoTemporal(payload);
  initializeAnalysis(payload);
  initializeProcessSummaries(payload);
  let cursorFrame: number | undefined;
  window.addEventListener('scroll',()=> {
    if(cursorFrame!==undefined) return;
    cursorFrame=window.requestAnimationFrame(()=>{syncVisibleCursors();cursorFrame=undefined;});
  },{passive:true});
  let resizeFrame: number | undefined;
  window.addEventListener("resize", () => {
    if (resizeFrame !== undefined) window.cancelAnimationFrame(resizeFrame);
    resizeFrame = window.requestAnimationFrame(reflowCharts);
  });
}

if (document.readyState === "loading") {
  document.addEventListener("DOMContentLoaded", main);
} else {
  main();
}
