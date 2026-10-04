/** Filtro temporal global del informe offline. Mantiene una única ventana
 * para gráficos y filas de evidencia; no modifica el payload original. */

import { aplicarRangoTemporalCharts } from "./charts";
import type { Payload } from "./types";

function valorInput(iso: string | null | undefined): string {
  return iso ? iso.slice(0, 19) : "";
}

function epochMs(valor: string): number | null {
  if (!valor) return null;
  const partes = valor.match(/^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2})(?::(\d{2}))?/);
  if (!partes) return null;
  const ms = Date.UTC(+partes[1], +partes[2] - 1, +partes[3], +partes[4], +partes[5], +(partes[6] || 0));
  return Number.isFinite(ms) ? ms : null;
}

function filtrarFilas(desde: number, hasta: number): number {
  let visibles = 0;
  document.querySelectorAll<HTMLElement>("[data-ts]").forEach((fila) => {
    const ts = epochMs(fila.dataset.ts || "");
    const dentro = ts === null || (ts >= desde && ts <= hasta);
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
  const capturaInput = document.getElementById("odl-rango-captura") as HTMLSelectElement | null;
  const estado = document.getElementById("odl-rango-estado");
  const [minimo, maximo] = payload.resumen.rango_tiempo || [];
  if (!desdeInput || !hastaInput || !aplicar || !restaurar || !capturaInput || !minimo || !maximo) return;

  const reiniciarInputs = (): void => {
    desdeInput.value = valorInput(minimo);
    hastaInput.value = valorInput(maximo);
    desdeInput.min = valorInput(minimo);
    desdeInput.max = valorInput(maximo);
    hastaInput.min = valorInput(minimo);
    hastaInput.max = valorInput(maximo);
    capturaInput.value = "";
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
    aplicarRangoTemporalCharts(desde, hasta);
    const visibles = filtrarFilas(desde, hasta);
    if (estado) estado.textContent = `${visibles} evidencias visibles en la ventana seleccionada.`;
  };

  reiniciarInputs();
  aplicar.addEventListener("click", ejecutar);
  capturaInput.addEventListener("change", () => {
    if (capturaInput.value === "") {
      desdeInput.value = valorInput(minimo);
      hastaInput.value = valorInput(maximo);
      return;
    }
    const ventana = payload.motor_episodios.ventanas_captura[Number(capturaInput.value)];
    if (ventana) {
      desdeInput.value = valorInput(ventana.inicio);
      hastaInput.value = valorInput(ventana.fin);
    }
  });
  restaurar.addEventListener("click", () => {
    reiniciarInputs();
    ejecutar();
  });
  document.addEventListener("odl:panel-visible", () => window.setTimeout(ejecutar, 0));
  document.addEventListener("odl:chart-mounted", ejecutar);
  ejecutar();
}
