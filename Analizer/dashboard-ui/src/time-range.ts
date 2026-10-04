/** Filtro temporal global del informe offline. Mantiene una única ventana
 * para gráficos y filas de evidencia; no modifica el payload original. */

import { aplicarRangoTemporalCharts } from "./charts";
import type { Payload } from "./types";

function valorInput(iso: string | null | undefined): string {
  return iso ? iso.slice(0, 19) : "";
}

function epochMs(valor: string): number | null {
  if (!valor) return null;
  const ms = new Date(valor).getTime();
  return Number.isFinite(ms) ? ms : null;
}

function filtrarFilas(desde: number, hasta: number, nodos: Set<string>): number {
  let visibles = 0;
  document.querySelectorAll<HTMLElement>("[data-ts]").forEach((fila) => {
    const ts = epochMs(fila.dataset.ts || "");
    const nodo = fila.dataset.node || "";
    const dentroNodo = !nodo || nodos.has(nodo);
    const dentro = dentroNodo && (ts === null || (ts >= desde && ts <= hasta));
    fila.hidden = !dentro;
    if (dentro) visibles += 1;
  });
  return visibles;
}

export function inicializarRangoTemporal(payload: Payload): void {
  const desdeInput = document.getElementById("odl-rango-desde") as HTMLInputElement | null;
  const hastaInput = document.getElementById("odl-rango-hasta") as HTMLInputElement | null;
  const aplicar = document.getElementById("odl-rango-aplicar") as HTMLButtonElement | null;
  const restaurar = document.getElementById("odl-rango-restaurar") as HTMLButtonElement | null;
  const nodosInput = document.getElementById("odl-rango-nodos") as HTMLSelectElement | null;
  const estado = document.getElementById("odl-rango-estado");
  const [minimo, maximo] = payload.resumen.rango_tiempo || [];
  if (!desdeInput || !hastaInput || !aplicar || !restaurar || !nodosInput || !minimo || !maximo) return;

  const nodosDisponibles = Array.from(nodosInput.options).map((opcion) => opcion.value);

  const reiniciarInputs = (): void => {
    desdeInput.value = valorInput(minimo);
    hastaInput.value = valorInput(maximo);
    desdeInput.min = valorInput(minimo);
    desdeInput.max = valorInput(maximo);
    hastaInput.min = valorInput(minimo);
    hastaInput.max = valorInput(maximo);
    for (const opcion of Array.from(nodosInput.options)) opcion.selected = true;
  };

  const ejecutar = (): void => {
    const desde = epochMs(desdeInput.value);
    const hasta = epochMs(hastaInput.value);
    if (desde === null || hasta === null || desde > hasta) {
      if (estado) estado.textContent = "Rango inválido: Desde debe ser anterior a Hasta.";
      desdeInput.setAttribute("aria-invalid", "true");
      hastaInput.setAttribute("aria-invalid", "true");
      return;
    }
    desdeInput.removeAttribute("aria-invalid");
    hastaInput.removeAttribute("aria-invalid");
    const nodos = new Set(Array.from(nodosInput.selectedOptions).map((opcion) => opcion.value));
    aplicarRangoTemporalCharts(desde, hasta, nodosDisponibles, nodos);
    const visibles = filtrarFilas(desde, hasta, nodos);
    if (estado) estado.textContent = `${visibles} evidencias visibles en la ventana seleccionada.`;
  };

  reiniciarInputs();
  aplicar.addEventListener("click", ejecutar);
  restaurar.addEventListener("click", () => {
    reiniciarInputs();
    ejecutar();
  });
  document.addEventListener("odl:panel-visible", () => window.setTimeout(ejecutar, 0));
  document.addEventListener("odl:chart-mounted", ejecutar);
  ejecutar();
}
