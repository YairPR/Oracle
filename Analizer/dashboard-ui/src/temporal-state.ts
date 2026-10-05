/** Source wall-clock time on a timezone-independent, neutral UTC axis. */
export interface Range { from: number; to: number }
export interface Capture { inicio: string; fin: string }
export function epochMs(value: string): number | null {
  if (/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:Z|[+-]\d{2}:?\d{2})$/.test(value)) {
    if(epochMs(value.slice(0,19))===null) return null;
    const n=Date.parse(value); return Number.isFinite(n) ? n : null;
  }
  const m = value.match(/^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2})(?::(\d{2}))?$/);
  if (!m) return null;
  const ms = Date.UTC(+m[1], +m[2]-1, +m[3], +m[4], +m[5], +(m[6] || 0));
  return new Date(ms).toISOString().slice(0,19) === (value.length === 16 ? value + ':00' : value) ? ms : null;
}
export function isoInput(ms: number): string { return new Date(ms).toISOString().slice(0,19); }
export function validRange(from: number | null, to: number | null): Range | null {
  return from !== null && to !== null && from <= to ? {from, to} : null;
}
export function sameRange(a: Range, b: Range): boolean { return a.from === b.from && a.to === b.to; }
export function lowerBound(values: number[], target: number): number {
  let lo=0, hi=values.length;
  while (lo<hi) { const mid=(lo+hi)>>>1; if (values[mid]<target) lo=mid+1; else hi=mid; }
  return lo;
}
export function fitWithin(values: number[], range: Range): Range | null {
  const start=lowerBound(values, range.from), end=lowerBound(values, range.to+1)-1;
  return start <= end ? {from:values[start], to:values[end]} : null;
}
export function axisRange(range: Range): Range {
  return range.from === range.to ? {from:range.from-1000, to:range.to+1000} : range;
}
