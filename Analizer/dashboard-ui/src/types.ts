/**
 * types.ts -- espejo liviano (no generado, mantenido a mano a proposito
 * para no sumar un paso de codegen) de los modelos Pydantic de
 * core/component_catalog.py y de las claves que ya arma analizador.py en
 * construir_payload(). Solo los campos que el frontend realmente lee.
 */

export type Severidad = "critical" | "warning" | "info";

export interface PuntoSerieObjeto {
  t: number; // epoch segundos
  v: number | null; // null separa ventanas sin muestras
  lt?: boolean;
}
export type PuntoSerie = PuntoSerieObjeto | [number, number | null, number?];

export interface SerieCompacta { clock: string; values?: (number | null)[]; constant?: number; nulls?: number[]; lt?: number[] }
export type DatosSerie = PuntoSerie[] | SerieCompacta;

export interface SeriesPorNodo {
  [nodo: string]: {
    [serie: string]: DatosSerie | null;
  };
}

export interface EventoHecho {
  timestamp: string; // ISO
  nodo: string | null;
  fuente: string;
  codigo: string | null;
  etiqueta: string;
  detalle: string | null;
  severidad: Severidad;
}

export interface Hipotesis {
  titulo: string;
  detalle: string;
  estado: "confirmada" | "en_estudio" | "sin_evidencia";
}

export interface Limitacion {
  descripcion: string;
}

export interface EpisodioDiagnostico {
  id: string;
  finding_type: string;
  nodo: string | null;
  inicio: string;
  fin: string;
  severidad: Severidad;
  resumen: string;
  interpretacion: string;
  hipotesis: Hipotesis[];
  limitaciones: Limitacion[];
  evidencia_ids: number[];
}

export interface ComponenteDefinicion {
  id: string;
  label: string;
  icon: string;
  panels: string[];
  optional_panels: string[];
}

export interface ComponenteActivado {
  episodio_id: string;
  definicion: ComponenteDefinicion;
  optional_panels_activos: string[];
  notas_cobertura: string[];
}

export interface InformeCompleto {
  hechos: { eventos: EventoHecho[]; entidades: { tipo: string; nombre: string }[] };
  diagnostico: {
    episodios: EpisodioDiagnostico[];
    estado_global: "OK" | "WARNING" | "CRITICAL";
    motivos_estado_global: string[];
  };
  presentacion: {
    componentes: ComponenteActivado[];
    series_relevantes: Record<string, boolean>;
  };
}

export interface ProcRankEntry {
  name: string;
  pid: number | null;
  n: number;
  max_cpuusage: number;
  max_privmem_kb: number;
  max_shm_kb: number;
  max_fd: number;
  max_threads: number;
  last_t: string | null;
}

export interface ProcRankingsNodo {
  by_cpu: ProcRankEntry[];
  by_privmem: ProcRankEntry[];
  by_fd: ProcRankEntry[];
  by_threads: ProcRankEntry[];
  total_unique: number;
}

export interface Payload {
  display_clock?: { offset_minutes: number; label: string };
  caso: string;
  generado_en: string;
  motor_episodios: {
    metric_contracts?: Record<string, {section: string; unit: string; kind: string; scope: string; transformation: string; missing: string}>;
    coverage?: Record<string, {cadence_seconds: number; samples: number}>;
    time_domains?: string[];
    source_files?: string[];
    trace_blocks?: Record<string, number[][]>;
    node_list: string[];
    nic_types: string[];
    nic_names_by_type: Record<string, string[]>;
    series_por_nodo: SeriesPorNodo;
    series_timestamps?: Record<string, number[]>;
    timestamps_muestras?: number[];
    series_max: Record<string, number>;
    device_names: string[];
    device_names_vistos_total: number;
    filesystem_mounts: string[];
    ventanas_captura: { inicio: string; fin: string; muestras: number }[];
    nodos_sar: string[];
    proc_rankings: Record<string, ProcRankingsNodo>;
    alert_events: { t: string; node: string | null; sev: Severidad; label: string }[];
    oclumon_diagnostics: { node_names: string[]; first_clock: string | null; last_clock: string | null }[];
  };
  analisis_reglas: {
    modo_analisis: {
      alcance_correlacion: string;
      profundidad_estudio: string;
      motivo_alcance: string;
      motivo_profundidad: string;
    };
  };
  informe: InformeCompleto;
  veredicto: { texto: string | null; estado_salud: { estado: string; motivos: string[] } | null };
  resumen: {
    total_eventos: number;
    fuentes: Record<string, number>;
    rango_tiempo: (string | null)[];
    tabla_truncada: boolean;
    limite_tabla: number;
  };
  series_cpu: PuntoSerie[];
  series_aas: PuntoSerie[];
  // *** HITO "rediseno AWR + tabs + LogRouter acotado" (2026-10-02) ***
  // Parses/sec vs Executes/sec (panel Mike Dietrich, Grafico 3.1) -- mismo
  // contrato que series_cpu/series_aas, un punto por snapshot AWR.
  series_parses: PuntoSerie[];
  series_executes: PuntoSerie[];
  // DB Time desglosado por categoria y snapshot AWR (panel Tom Kyte,
  // Grafico 1.1) -- ya agregado por SQL en analizador.py, el frontend
  // solo pivota filas -> series apiladas (ver charts.ts::renderBarraApiladaDbTime).
  awr_dbtime_breakdown: { etiqueta: string; categoria: string; segundos: number }[];
}

declare global {
  interface Window {
    __PAYLOAD__: Payload;
  }
}
