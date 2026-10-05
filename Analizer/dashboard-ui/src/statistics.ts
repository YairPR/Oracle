/** Full-resolution statistics. Rates use complete valid source intervals (right endpoint). */
export interface Summary { valid: number; elapsed: number; covered: number; mean: number | null; p95: number | null; max: number | null; maxTime: number | null; integral: number | null; total: number | null; bounds: number }
export function summarize(points: (number | null)[][], from: number, to: number, kind: string, cadenceMs: number): Summary {
  const selected=points.filter(p=>p[0]!==null && p[0]>=from && p[0]<=to && p[1]!==null);
  const values=selected.map(p=>p[1]!).sort((a,b)=>a-b);
  let covered=0, integral=0, total=0;
  for(let i=1;i<points.length;i++) {
    const a=points[i-1], b=points[i];
    if(a[0]===null || b[0]===null || (a[1]===null && kind!=='counter_increment') || b[1]===null) continue;
    const dt=b[0]-a[0];
    if(a[0]<from || b[0]>to || dt<=0 || dt>cadenceMs*3) continue;
    covered+=dt/1000;
    integral+=b[1]*dt/1000;
    total+=b[1];
  }
  const h=(values.length-1)*.95, lo=Math.floor(h);
  const p95=values.length ? values[lo]+(values[Math.ceil(h)]-values[lo])*(h-lo) : null;
  const maxPoint=selected.reduce<(number|null)[]|null>((best,p)=>!best || p[1]!>best[1]! ? p:best,null);
  const weighted=kind==='rate' || kind==='counter_increment';
  return {valid:values.length, elapsed:(to-from)/1000, covered,
    mean:weighted ? covered ? (kind==='counter_increment'?total:integral)/covered : null : values.length?values.reduce((a,b)=>a+b,0)/values.length:null,
    p95,max:maxPoint?.[1]??null,maxTime:maxPoint?.[0]??null,
    integral:kind==='rate' && covered ? integral:null,total:kind==='counter_increment' && covered ? total:null,
    bounds:selected.filter(p=>p[2]).length};
}
