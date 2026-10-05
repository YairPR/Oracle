/** Historical resource views, calculated from the original analytic series. */
import type { Payload } from './types';
import { puntosADataset, reflowCharts, syncVisibleCursors } from './charts';
import { colorDeNodo } from './colors';
import { summarize, type Summary } from './statistics';
import { epochMs, isoInput, type Range } from './temporal-state';
import { escapeHtml as esc } from './util';

const format = new Intl.NumberFormat('es-ES', {maximumFractionDigits: 3});
const fmt = (v: number | null | undefined): string => v == null ? 'No calculable' : format.format(v);
export function initializeResources(payload: Payload): void {
  const me = payload.motor_episodios as any;
  const range = (): Range => (window as any).__odlTemporalState;
  const date = (ms: number): string => isoInput(ms, payload.display_clock?.offset_minutes || 0).replace('T', ' ');
  let active = 'resumen', cacheRange = '';
  const cache = new Map<string, Summary>();
  const points = (node: string, key: string) => puntosADataset(me.series_por_nodo[node]?.[key]);
  const stats = (node: string, key: string): Summary => {
    const r = range(), signature = `${r.from}:${r.to}`;
    if (signature !== cacheRange) {cache.clear(); cacheRange = signature;}
    const id = `${node}\n${key}`;
    if (!cache.has(id)) cache.set(id, summarize(points(node,key), r.from, r.to,
      me.metric_contracts[key]?.kind || 'instantaneous', (me.coverage[node]?.cadence_seconds || 1)*1000));
    return cache.get(id)!;
  };
  for (const el of document.querySelectorAll<HTMLElement>('[data-host-color]')) {
    el.style.setProperty('--host-color', colorDeNodo(el.dataset.hostColor!));
  }
  const activate = (id: string): void => {
    active = id;
    document.querySelectorAll<HTMLElement>('[data-resource-panel]').forEach(el => el.classList.toggle('odl-resource-active',el.dataset.resourcePanel===id));
    document.querySelectorAll<HTMLButtonElement>('.odl-resource-nav [data-resource]').forEach(el => {
      el.classList.toggle('active',el.dataset.resource===id); el.setAttribute('aria-pressed',String(el.dataset.resource===id));
    });
    syncVisibleCursors();
    document.dispatchEvent(new Event('odl:panel-visible'));
    requestAnimationFrame(() => {reflowCharts(); refresh();});
  };
  document.querySelectorAll<HTMLButtonElement>('[data-resource]').forEach(el => el.addEventListener('click',()=>activate(el.dataset.resource!)));
  document.querySelectorAll<HTMLDetailsElement>('#sec-oclumon details').forEach(el => el.addEventListener('toggle',()=> {
    if(el.open) document.dispatchEvent(new Event('odl:panel-visible'));
  }));
  const summaries = (): void => {
    document.querySelectorAll<HTMLElement>('[data-metric-summary]').forEach(el => {
      if(el.offsetParent===null) return;
      const key=el.dataset.metricSummary!, meta=me.metric_contracts[key];
      el.innerHTML=me.node_list.map((node:string)=> {
        const s=stats(node,key);
        const name=`<span class="odl-stat-host" style="--host-color:${colorDeNodo(node)}">${esc(node)}</span>`;
        if(!s.valid) return `<span>${name}: sin muestras</span>`;
        const text=key.startsWith('mem') || key.startsWith('swapfree') ? `mín. ${fmt(s.min)} ${esc(meta.unit)} · ${date(s.minTime!)}`
          : meta.kind==='counter_increment' ? `${fmt(s.total)} incrementos en intervalos completos · máx. ${fmt(s.max)} por intervalo`
          : key.endsWith('wait_ms') ? `máx. ${fmt(s.max)} ms · ${date(s.maxTime!)} · P95 de medias por intervalo ${fmt(s.p95)} ms`
          : `media ${meta.kind==='rate'?'temporal':'de muestras'} ${fmt(s.mean)} · máx. ${fmt(s.max)} ${esc(meta.unit)} · ${date(s.maxTime!)}`;
        return `<span>${name}: ${text}${s.bounds?' · contiene límites <':''}</span>`;
      }).join('');
    });
  };
  const resourceFor=(cat:string):string=>cat==='cpu_queue'?'cpu':cat==='swap'?'memoria':cat.startsWith('device')?'discos':cat==='fs_full'?'filesystems':'red';
  const labels:Record<string,string>={cpu_queue:'Cola de CPU',tcp_retrans:'Retransmisiones TCP',nic_discards:'Descartes de interfaz',nic_link_errors:'Errores de interfaz',device_wait:'Espera media por I/O',fs_full:'Ocupación de filesystem',swap:'Tráfico de swap',ip_reasfail:'Fallos de reensamblado IP',udp_rcverr:'Errores de recepción UDP',nic_latency:'Latencia estimada de interfaz',nic_errors_hw:'Errores NIC del sistema'};
  let observations:any[]=[];
  const dialog=document.createElement('dialog'); dialog.className='odl-evidence-dialog'; dialog.id='odl-observation-detail'; document.body.appendChild(dialog);
  const renderObservations=():void=> {
    const r=range(), grouped=new Map<string,any>();
    for(const event of me.eventos_discretos || []) {
      const ms=epochMs(event.t); if(ms===null || ms<r.from || ms>r.to) continue;
      const id=`${event.node}:${event.cat}:${event.entity || ''}`, old=grouped.get(id);
      if(!old || event.value>old.value) grouped.set(id,{...event, ms, count:(old?.count||0)+1});
      else old.count++;
    }
    observations=[...grouped.values()].sort((a,b)=>(a.quality==='suspect'?-1:0)-(b.quality==='suspect'?-1:0) || a.ms-b.ms);
    const banner=document.getElementById('odl-observation-banner')!;
    banner.textContent=observations.length ? `${observations.length} señales por investigar en el periodo · no demuestran causa ni impacto por sí solas.` : 'Sin señales en las reglas evaluadas para este periodo. La cobertura no permite concluir salud de toda la infraestructura.';
    const rows=observations.slice(0,8).map((e,i)=>`<tr><td>${date(e.ms)}</td><td><span class="odl-stat-host" style="--host-color:${colorDeNodo(e.node)}">${esc(e.node)}</span>${e.entity?' · '+esc(e.entity):''}</td><td>${esc(labels[e.cat]||e.cat)}: ${fmt(e.value)} ${e.cat==='nic_discards'?'paquetes/s':e.cat==='nic_link_errors'||e.cat==='nic_errors_hw'?'errores/s':e.cat==='device_wait'||e.cat==='nic_latency'?'ms':e.cat==='tcp_retrans'?'segmentos/intervalo':e.cat==='cpu_queue'?'procesos':e.cat==='swap'?'KB/s':e.cat==='fs_full'?'%':'incrementos/intervalo'}${e.quality==='suspect'?' · extremo pendiente de validación':''}</td><td><button type="button" class="odl-filter-btn" data-observation="${i}">Ver evidencia</button></td></tr>`).join('');
    document.getElementById('odl-observations')!.innerHTML=rows?`<div class="odl-table-scroll"><table class="odl-table"><thead><tr><th>Hora del máximo</th><th>Host / recurso</th><th>Observación</th><th>Investigar</th></tr></thead><tbody>${rows}</tbody></table></div>${observations.length>8?'<p>Se muestran ocho señales. La cronología y las evidencias conservan el detalle restante.</p>':''}`:'<p>Sin observaciones dentro del intervalo aplicado.</p>';
  };
  document.getElementById('odl-observations')!.addEventListener('click',event=> {
    const button=(event.target as HTMLElement).closest<HTMLElement>('[data-observation]'); if(!button) return;
    const e=observations[Number(button.dataset.observation)];
    const uri=e.source && /^[A-Za-z]:[\\/]/.test(e.source)?'file:///'+e.source.replace(/\\/g,'/').split('/').map(encodeURIComponent).join('/').replace('%3A',':'):null;
    dialog.innerHTML=`<h2>${esc(labels[e.cat]||e.cat)}</h2><p>${esc(e.node)} · ${esc(e.entity||'host')} · ${date(e.ms)} · ${esc(payload.display_clock?.label||'zona no declarada')}</p><p><strong>Observado:</strong> ${esc(e.msg)}; ${e.count} muestras con señal en el periodo.</p><p><strong>Interpretación pendiente:</strong> correlacionar carga, colas y errores. La señal no confirma causa ni impacto${e.quality==='suspect'?'; extremo conservado, validez pendiente':''}.</p><p><strong>Regla:</strong> ${esc(e.threshold_origin||'heurística del proyecto')}</p><p class="odl-source-path"><strong>Fuente:</strong> ${esc(e.source||'no disponible')} · línea ${e.line??'no disponible'}</p>${uri?`<a href="${esc(uri)}" target="_blank" rel="noopener">Abrir archivo original</a>`:''}<div class="odl-dialog-actions"><button class="odl-filter-btn" data-open-resource>Ver recurso</button><button class="odl-filter-btn" data-close>Cerrar</button></div>`;
    dialog.querySelector('[data-close]')!.addEventListener('click',()=>dialog.close());
    dialog.querySelector('[data-open-resource]')!.addEventListener('click',()=> {
      const id=resourceFor(e.cat), selector=document.getElementById(id==='discos'?'odl-selector-device':id==='filesystems'?'odl-selector-fs':'odl-selector-nic') as HTMLSelectElement|null;
      if(selector && e.entity && [...selector.options].some(o=>o.value===e.entity)){selector.value=e.entity;selector.dispatchEvent(new Event('change'));}
      dialog.close();activate(id);
    });
    dialog.showModal();
  });
  const nicInventory=():void=> {
    const selector=document.getElementById('odl-selector-nic') as HTMLSelectElement, name=selector?.value, r=range();
    document.getElementById('odl-nic-inventory')!.innerHTML=me.node_list.map((node:string)=> {
      const records=(me.nic_inventory?.[node]?.[name]||[]).filter((v:any)=>v.to*1000>=r.from && v.from*1000<=r.to);
      if(!records.length)return `<p>${esc(node)} · sin observaciones de esta interfaz en el periodo.</p>`;
      const roles=[...new Set(records.map((v:any)=>v.type==='UNCLASSIFIED'?'Sin clasificación':v.type))], mtu=[...new Set(records.map((v:any)=>v.mtu==null?'no disponible':v.mtu))];
      return `<p><span class="odl-stat-host" style="--host-color:${colorDeNodo(node)}">${esc(node)}</span> · rol ${esc(roles.join(', '))} · MTU ${esc(mtu.join(', '))}</p>`;
    }).join('');
  };
  const deviceInventory=():void=> {
    const search=(document.getElementById('odl-device-search') as HTMLInputElement).value.trim().toLowerCase();
    const sort=(document.getElementById('odl-device-sort') as HTMLSelectElement).value;
    const devices=(me.device_names||[]).flatMap((name:string)=>me.node_list.map((node:string)=>({name,node,wait:stats(node,`dev::${name}::wait_ms`),iops:stats(node,`dev::${name}::ios`)})))
      .filter((d:any)=>!search || `${d.name} ${d.node}`.toLowerCase().includes(search));
    devices.sort((a:any,b:any)=>sort==='name'?a.name.localeCompare(b.name):(sort==='iops'?(b.iops.max??-1)-(a.iops.max??-1):(b.wait.max??-1)-(a.wait.max??-1)) || a.name.localeCompare(b.name));
    document.getElementById('odl-device-inventory')!.innerHTML=`<div class="odl-inventory-scroll"><table class="odl-table"><thead><tr><th>Dispositivo / host</th><th>Máx. wait (ms)</th><th>Hora</th><th>P95 de medias por intervalo (ms)</th><th>Máx. IOPS</th></tr></thead><tbody>${devices.map((d:any)=>`<tr><td><button class="odl-device-link" data-device="${esc(d.name)}">${esc(d.name)}</button> · <span class="odl-stat-host" style="--host-color:${colorDeNodo(d.node)}">${esc(d.node)}</span></td><td>${fmt(d.wait.max)}${d.wait.max>1000000?' · validar extremo':''}</td><td>${d.wait.maxTime===null?'—':date(d.wait.maxTime)}</td><td>${fmt(d.wait.p95)}</td><td>${fmt(d.iops.max)}</td></tr>`).join('')}</tbody></table>${devices.length?'':'<p>Sin dispositivos que coincidan.</p>'}</div>`;
  };
  document.getElementById('odl-device-inventory')!.addEventListener('click',event=> {
    const el=(event.target as HTMLElement).closest<HTMLElement>('[data-device]');if(!el)return;
    const selector=document.getElementById('odl-selector-device') as HTMLSelectElement;
    selector.value=el.dataset.device!;selector.dispatchEvent(new Event('change'));
  });
  const filesystemInventory=():void=> {
    const r=range(), rows:string[]=[];
    for(const node of me.node_list) for(const mount of me.filesystem_mounts||[]) {
      const used=points(node,`fs::${mount}::used_pct`).filter(p=>p[0]!==null && p[0]>=r.from && p[0]<=r.to), last=used[used.length-1];
      if(!last)continue;
      const at=(field:string)=>points(node,`fs::${mount}::${field}`).find(p=>p[0]===last[0])?.[1]??null;
      rows.push(`<tr><td><span class="odl-stat-host" style="--host-color:${colorDeNodo(node)}">${esc(node)}</span></td><td>${esc(mount)}</td><td>${fmt(at('total_mb'))}</td><td>${fmt(at('avail_mb'))}</td><td>${last[1]===null?'No disponible':`<meter min="0" max="100" value="${last[1]}"></meter> ${fmt(last[1])} %`}</td><td>${date(last[0]!)}</td></tr>`);
    }
    document.getElementById('odl-filesystem-inventory')!.innerHTML=rows.length?`<div class="odl-table-scroll"><table class="odl-table"><thead><tr><th>Host</th><th>Montaje</th><th>Total (MiB)</th><th>Disponible (MiB)</th><th>Uso</th><th>Hora</th></tr></thead><tbody>${rows.join('')}</tbody></table></div>`:'<p>Sin muestras de filesystems en el periodo.</p>';
  };
  function refresh():void {
    if(!range() || document.getElementById('sec-oclumon')!.offsetParent===null)return;
    summaries();
    if(active==='resumen')renderObservations();
    if(active==='red')nicInventory();
    if(active==='discos')deviceInventory();
    if(active==='filesystems')filesystemInventory();
  }
  for(const id of ['odl-device-search','odl-device-sort']) document.getElementById(id)?.addEventListener(id.endsWith('search')?'input':'change',deviceInventory);
  document.getElementById('odl-selector-nic')?.addEventListener('change',nicInventory);
  document.addEventListener('odl:range-applied',()=>{if(dialog.open)dialog.close();refresh();});
  document.addEventListener('odl:panel-visible',refresh);
  refresh();
}
