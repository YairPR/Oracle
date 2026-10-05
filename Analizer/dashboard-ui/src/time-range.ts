/** One applied range shared by all tabs; input edits remain a separate draft. */
import { aplicarRangoTemporalCharts } from "./charts";
import { epochMs, isoInput, validRange, fitWithin, sameRange, type Range } from "./temporal-state";
import type { Payload, PuntoSerie } from "./types";

export function inicializarRangoTemporal(payload: Payload): void {
  const from = document.getElementById("odl-rango-desde") as HTMLInputElement;
  const to = document.getElementById("odl-rango-hasta") as HTMLInputElement;
  const capture = document.getElementById("odl-rango-captura") as HTMLSelectElement;
  const note = document.getElementById("odl-rango-nota")!;
  const selected = document.getElementById("odl-periodo-seleccionado")!;
  const available = payload.resumen.rango_tiempo;
  const full = validRange(epochMs(available[0] || ""), epochMs(available[1] || ""));
  if (!from || !to || !capture || !full) return;
  let applied: Range = {...full};
  let scope: Range | null = null;
  const evidence = Array.from(document.querySelectorAll<HTMLElement>("[data-ts]")).map(el => ({el, time:epochMs(el.dataset.ts || ""), end:epochMs(el.dataset.end || el.dataset.ts || "")}));
  // OCLUMON/SAR samples take precedence; AWR-only cases use snapshot start times.
  const clocks = new Set<number>();
  const add = (points: PuntoSerie[] | null | undefined): void => {
    for (const p of points || []) {
      const t=Array.isArray(p)?p[0]:p.t, v=Array.isArray(p)?p[1]:p.v;
      if (v !== null && Number.isFinite(t)) clocks.add(t*1000);
    }
  };
  for (const t of payload.motor_episodios.timestamps_muestras || []) clocks.add(t*1000);
  if (!clocks.size) for (const series of Object.values(payload.motor_episodios.series_por_nodo)) {
    for (const points of Object.values(series)) if (Array.isArray(points)) add(points);
  }
  if (!clocks.size) { add(payload.series_cpu); add(payload.series_aas); }
  const times = Array.from(clocks).sort((a,b)=>a-b);
  const captures = payload.motor_episodios.ventanas_captura.map(c => validRange(epochMs(c.inicio), epochMs(c.fin)));
  const write = (): void => { from.value=isoInput(applied.from); to.value=isoInput(applied.to); };
  const identify = (): void => {
    const index=captures.findIndex(c=>c && sameRange(c,applied));
    capture.value = scope && sameRange(scope,applied) && index>=0 ? String(index) : sameRange(applied, full) && !scope ? "" : "custom";
  };
  const refresh = (): void => {
    const t=performance.now();
    aplicarRangoTemporalCharts(applied.from, applied.to);
    for (const {el,time,end} of evidence) el.dataset.rangeHidden=String(time!==null && (time>applied.to || (end ?? time)<applied.from));
    for (const {el} of evidence) el.hidden=el.dataset.rangeHidden==='true' || el.dataset.localHidden==='true';
    (window as any).__odlTemporalState = {...applied};
    document.dispatchEvent(new Event('odl:range-applied'));
    (window as any).__odlPerformance = {...(window as any).__odlPerformance, filterMs:performance.now()-t};
  };
  const apply = (range: Range): void => {
    applied={...range}; write(); identify(); refresh();
    selected.textContent=`Seleccionado: ${isoInput(applied.from).replace('T',' ')} — ${isoInput(applied.to).replace('T',' ')}${scope?' · Dentro de captura seleccionada':''}`;
    from.removeAttribute("aria-invalid"); to.removeAttribute("aria-invalid");
    note.textContent=fitWithin(times,applied) ? (applied.from===applied.to ? "Una muestra: eje con margen de ±1 segundo." : "") : "Sin muestras en este intervalo.";
  };
  const draft = (): Range | null => validRange(epochMs(from.value),epochMs(to.value));
  for (const input of [from,to]) input.addEventListener("input", ()=> { note.textContent="Fechas editadas pendientes de Aplicar."; });
  document.getElementById("odl-rango-aplicar")!.addEventListener("click",()=> {
    const range=draft();
    if (range && (!scope || (range.from>=scope.from && range.to<=scope.to))) apply(range);
    else if(range) note.textContent='El intervalo sale de la captura seleccionada. Elija Todas para ampliar el ámbito.';
    else { note.textContent="Rango inválido: compruebe Desde y Hasta."; from.setAttribute("aria-invalid","true"); to.setAttribute("aria-invalid","true"); }
  });
  capture.addEventListener("change",()=> {
    const range=capture.value===""?full:captures[Number(capture.value)];
    scope=capture.value===""?null:range || null;
    if (range) apply(range);
  });
  document.getElementById("odl-rango-ajustar")!.addEventListener("click",()=> {
    const range=draft();
    if (!range) { note.textContent="Rango inválido: compruebe Desde y Hasta."; return; }
    if(scope && (range.from<scope.from || range.to>scope.to)) {note.textContent='El intervalo sale de la captura seleccionada.';return;}
    const fit=fitWithin(times,range);
    apply(fit || range); // Empty intervals keep the requested dates, never search outside.
  });
  document.getElementById("odl-rango-restaurar")!.addEventListener("click",()=>{scope=null;apply(full);});
  document.addEventListener("odl:panel-visible",()=>window.setTimeout(refresh,0));
  document.addEventListener("odl:chart-mounted",refresh);
  apply(full);
}
