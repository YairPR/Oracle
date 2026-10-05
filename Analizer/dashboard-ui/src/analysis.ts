import type { Payload } from './types';
import { puntosADataset } from './charts';
import { summarize } from './statistics';
import { isoInput, type Range } from './temporal-state';
import { escapeHtml } from './util';

export function initializeAnalysis(payload: Payload): void {
  const root=document.getElementById('odl-analysis');
  if(!root) return;
  const host=root.querySelector<HTMLSelectElement>('#odl-analysis-host')!;
  const metric=root.querySelector<HTMLSelectElement>('#odl-analysis-metric')!;
  const output=root.querySelector<HTMLElement>('#odl-analysis-output')!;
  const me=payload.motor_episodios;
  let windowA:Range|null=null;
  const contracts=me.metric_contracts || {};
  for(const n of me.node_list) host.add(new Option(n,n));
  const refreshMetrics=():void=> {
    const prior=metric.value; metric.replaceChildren();
    for(const key of Object.keys(me.series_por_nodo[host.value]||{})) {
      const c=contracts[key]; if(!c) continue;
      metric.add(new Option(`${c.section} · ${key} (${c.unit})`,key));
    }
    if([...metric.options].some(o=>o.value===prior)) metric.value=prior;
  };
  const fmt=(v:number|null):string=>v===null?'No calculable':v.toLocaleString('es-ES',{maximumSignificantDigits:5});
  const render=():void=> {
    const range=(window as any).__odlTemporalState as Range|undefined;
    if(!range) return;
    if((me.time_domains||[]).includes('unknown') && (me.time_domains||[]).length>1) {
      output.textContent='Fuentes con zona desconocida y offset explícito: comparación desactivada para evitar suponer alineación temporal.';return;
    }
    const key=metric.value,c=contracts[key];
    if(!c) {output.textContent='Sin métricas representables.';return;}
    const points=puntosADataset(me.series_por_nodo[host.value]?.[key]);
    const cadence=(me.coverage?.[host.value]?.cadence_seconds||1)*1000;
    const stats=(r:Range)=>summarize(points,r.from,r.to,c.kind,cadence);
    const load=(r:Range):string=>['cpu_pct','ios','netr','netw'].map(k=> {
      const meta=contracts[k]; if(!meta) return '';
      const s=summarize(puntosADataset(me.series_por_nodo[host.value]?.[k]),r.from,r.to,meta.kind,cadence);
      return `${k}: ${fmt(s.mean)} ${escapeHtml(meta.unit)}`;
    }).filter(Boolean).join(' · ');
    const b=stats(range),a=windowA?stats(windowA):null;
    const rows=(r:Range,s:ReturnType<typeof stats>)=>`<td>${escapeHtml(isoInput(r.from))} — ${escapeHtml(isoInput(r.to))}<br>${fmt(s.elapsed)} s; ${s.valid} muestras válidas; ${fmt(s.covered)} s cubiertos (${s.elapsed?fmt(s.covered/s.elapsed*100):'—'} %)<br>Media ${c.kind==='rate'?'ponderada por tiempo':c.kind==='counter_increment'?'de incrementos por segundo':'de muestras'}: ${fmt(s.mean)} ${escapeHtml(c.kind==='counter_increment'?'incrementos/s':c.unit)}<br>P95 ${c.kind==='interval_mean'?'de las medias por intervalo':'de muestras'} (interpolación lineal): ${fmt(s.p95)}<br>Máximo observado: ${fmt(s.max)} ${escapeHtml(c.unit)} · ${s.maxTime===null?'—':isoInput(s.maxTime)}<br>${s.total!==null?'Incrementos en intervalos completos: '+fmt(s.total):s.integral!==null?'Integral (unidad × s): '+fmt(s.integral):''}<br>Carga del host: ${load(r)}${s.bounds?'<br>Hay límites &lt;: estos resúmenes no representan valores exactos.':''}</td>`;
    const delta=a&&a.mean!==null&&b.mean!==null?b.mean-a.mean:null;
    output.innerHTML=`<p>${escapeHtml(c.scope)} · ${escapeHtml(c.transformation)}. ${escapeHtml(c.missing)}</p><table class="odl-table"><thead><tr>${a?'<th>A — referencia fijada</th>':''}<th>B — periodo aplicado</th></tr></thead><tbody><tr>${a&&windowA?rows(windowA,a):''}${rows(range,b)}</tr></tbody></table>${a?`<p>Cambio absoluto de la media: ${fmt(delta)}; relativo: ${a.mean===0||delta===null||a.mean===null?'No calculable':fmt(delta/a.mean*100)+' %'}. Asociación temporal; no demuestra causa ni resolución de evictions.</p>`:''}<p>Intervalos completos sin huecos; sin prolongar valores. Analítica sobre resolución original. Contextualice carga con CPU, IOPS y tráfico del mismo host y periodo.</p>`;
  };
  host.addEventListener('change',()=>{refreshMetrics();render();});
  metric.addEventListener('change',render);
  root.querySelector('#odl-analysis-save')!.addEventListener('click',()=> {
    const range=(window as any).__odlTemporalState;
    windowA=range?{...range}:null;render();
  });
  root.querySelector('#odl-analysis-clear')!.addEventListener('click',()=>{windowA=null;render();});
  // Collapsed analysis does no decoding/filtering work until the user opens it.
  const details=root as HTMLDetailsElement;
  root.addEventListener('toggle',()=>{if(details.open) render();});
  document.addEventListener('odl:range-applied',()=>{if(details.open) render();});
  refreshMetrics();
}

export function initializeProcessSummaries(payload: Payload): void {
  const elements=[...document.querySelectorAll<HTMLElement>('[data-proc-summary-node]')];
  const render=(el:HTMLElement):void=> {
    if(el.offsetParent===null) return;
    const box=el.getBoundingClientRect();if(box.top>innerHeight+500 || box.bottom<0) return;
    const range=(window as any).__odlTemporalState as Range|undefined;if(!range) return;
    const node=el.dataset.procSummaryNode!,series=payload.motor_episodios.series_por_nodo[node]||{};
    const cadence=(payload.motor_episodios.coverage?.[node]?.cadence_seconds||1)*1000;
    const fields=[['max_cpuusage','CPU (%)'],['max_privmem_kb','Memoria privada (KB)'],['max_fd','Descriptores'],['max_threads','Threads']];
    let html='<p>Periodo aplicado · máximos individuales entre los PIDs listados de cada nombre; no CPU agregada ni memoria atribuida íntegramente a Oracle.</p>';
    for(const [field,label] of fields) {
      const rows=Object.keys(series).filter(k=>k.startsWith('proc::') && k.endsWith('::'+field)).map(k=> {
        const stats=summarize(puntosADataset(series[k]),range.from,range.to,'instantaneous',cadence);
        return {name:k.slice(6,-field.length-2),stats};
      }).filter(r=>r.stats.max!==null).sort((a,b)=>b.stats.max!-a.stats.max!).slice(0,10);
      html+=`<h4>${escapeHtml(label)}</h4><table class="odl-table"><thead><tr><th>Nombre</th><th>Máximo observado</th><th>Hora</th><th>Muestras válidas</th></tr></thead><tbody>${rows.map(r=>`<tr><td>${escapeHtml(r.name)}</td><td>${r.stats.max}</td><td>${isoInput(r.stats.maxTime!)}</td><td>${r.stats.valid}</td></tr>`).join('')}</tbody></table>${rows.length?'':'<p>Sin datos en el periodo aplicado.</p>'}`;
    }
    el.innerHTML=html;
  };
  const observer=new IntersectionObserver(entries=>{for(const entry of entries) if(entry.isIntersecting) render(entry.target as HTMLElement);},{rootMargin:'500px'});
  for(const el of elements) observer.observe(el);
  document.addEventListener('odl:range-applied',()=>elements.forEach(render));
  document.addEventListener('odl:panel-visible',()=>elements.forEach(render));
}
