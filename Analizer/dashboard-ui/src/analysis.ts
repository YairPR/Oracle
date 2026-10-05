import type { Payload } from './types';
import { puntosADataset } from './charts';
import { summarize } from './statistics';
import { isoInput, type Range } from './temporal-state';
import { escapeHtml } from './util';

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
      html+=`<h4>${escapeHtml(label)}</h4><table class="odl-table"><thead><tr><th>Nombre</th><th>Máximo observado</th><th>Hora</th><th>Muestras válidas</th></tr></thead><tbody>${rows.map(r=>`<tr><td>${escapeHtml(r.name)}</td><td>${r.stats.max}</td><td>${isoInput(r.stats.maxTime!, payload.display_clock?.offset_minutes || 0)}</td><td>${r.stats.valid}</td></tr>`).join('')}</tbody></table>${rows.length?'':'<p>Sin datos en el periodo aplicado.</p>'}`;
    }
    el.innerHTML=html;
  };
  const observer=new IntersectionObserver(entries=>{for(const entry of entries) if(entry.isIntersecting) render(entry.target as HTMLElement);},{rootMargin:'500px'});
  for(const el of elements) observer.observe(el);
  document.addEventListener('odl:range-applied',()=>elements.forEach(render));
  document.addEventListener('odl:panel-visible',()=>elements.forEach(render));
}
