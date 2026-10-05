"""
tests/smoke_test.py -- Red de seguridad contra regresiones del pipeline REAL
(no v2), sobre datos reales del incidente DEPT300.

Reemplaza a rac_lab_v2/tests/smoke_test.py (retirado junto con el resto de
rac_lab_v2 en el Hito de fusion de motores AWR, 2026-10-03) -- antes esta
era la UNICA red de regresion automatizada del proyecto, pero corria sobre
un esquema/pipeline paralelo que ya no existe. Esta version corre
analizador.ejecutar_caso_completo() -- la funcion real que usa el CLI --
contra la carpeta de caso real y verifica los valores en el
esquema dimensional real (fact_awr_snapshots/fact_awr_wait_events/
fact_telemetria_so/dim_infraestructura/dim_database), no un esquema v2.

Uso:  python tests/smoke_test.py <carpeta_con_los_archivos_del_caso>
Los valores esperados se verificaron a mano contra el .duckdb real generado
por una corrida de analizador.py (2026-10-03, tras fusionar parsers/awr.py
con el motor de rac_lab_v2). Si un cambio en un parser/esquema altera alguno,
el test falla y dice cual.

Nota de alcance (honesta): la carpeta de caso real trae 7 archivos AWR, pero
2 de ellos (awrrpt_1_98892_98893.txt, awrrpt_2_98890_98891.txt) son AWR en
formato HTML, no texto plano -- LogRouter los clasifica correctamente como
'unknown' porque el pipeline (como siempre) solo soporta AWR en texto. Esto
no es un bug de esta fusion, es una limitacion de formato ya existente que
se vuelve a confirmar aqui -- por eso el test espera 5 informes AWR, no 7.
"""
import shutil
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
import duckdb  # noqa: E402

from analizador import ejecutar_caso_completo  # noqa: E402
from core.episode_engine import _epoch_hora_origen, _insertar_huecos  # noqa: E402

carpeta = Path(sys.argv[1])
tmp = Path(tempfile.mkdtemp(prefix="raclab_test_"))
db = tmp / "t.duckdb"

resultado = ejecutar_caso_completo(str(carpeta), str(db), log_cb=lambda *a: None)

c = duckdb.connect(str(db), read_only=True)
q = lambda sql: c.execute(sql).fetchone()[0]
fallos = []


def check(nombre, real, esperado):
    ok = (abs(real - esperado) < 1e-6) if isinstance(esperado, float) else real == esperado
    print(("OK   " if ok else "FALLA"), nombre, real, "" if ok else f"(esperado {esperado})")
    if not ok:
        fallos.append(nombre)


check("snapshots AWR (texto, 2 HTML quedan unknown)", q("SELECT count(*) FROM fact_awr_snapshots"), 5)
check("wait events totales (10 por snapshot x 5)", q("SELECT count(*) FROM fact_awr_wait_events"), 50)
check("filas de telemetria oclumon", q("SELECT count(*) FROM fact_telemetria_so WHERE fuente='oclumon'"), 1620)
check("instancias RAC distintas en dim_database", q("SELECT count(DISTINCT instance_name) FROM dim_database"), 2)
check("release Oracle", q("SELECT DISTINCT release FROM dim_database").strip(), "11.2.0.4.0")

snap_302_88 = q(
    "SELECT snapshot_id FROM fact_awr_snapshots WHERE host='bov-racsalud-302' "
    "AND begin_snap_id='98889' AND end_snap_id='98890'"
)
check("snapshot_id bov-racsalud-302 98889-98890", snap_302_88, 3)
check(
    "AAS bov-racsalud-302 98889-98890 (DB Time/elapsed real)",
    q(f"SELECT aas FROM fact_awr_snapshots WHERE snapshot_id={snap_302_88}"),
    2.3,
)
check(
    "physical_reads_per_sec bov-racsalud-302 98889-98890",
    q(f"SELECT physical_reads_per_sec FROM fact_awr_snapshots WHERE snapshot_id={snap_302_88}"),
    1279.2,
)

snap_302_93 = q(
    "SELECT snapshot_id FROM fact_awr_snapshots WHERE host='bov-racsalud-302' "
    "AND begin_snap_id='98893' AND end_snap_id='98894'"
)
snap_302_93_dbcpu_pct = q(
    f"SELECT pct_dbtime FROM fact_awr_wait_events WHERE snapshot_id={snap_302_93} "
    "AND evento='DB CPU'"
)
check("DB CPU pct_dbtime bov-racsalud-302 98893-98894", snap_302_93_dbcpu_pct, 78.2)
check(
    "wait_class de 'db file sequential read' bov-racsalud-302 98893-98894",
    q(f"SELECT wait_class FROM fact_awr_wait_events WHERE snapshot_id={snap_302_93} "
      "AND evento='db file sequential read'"),
    "User I/O",
)
check(
    "wait_class de 'gc cr block 2-way' bov-racsalud-302 98893-98894",
    q(f"SELECT wait_class FROM fact_awr_wait_events WHERE snapshot_id={snap_302_93} "
      "AND evento='gc cr block 2-way'"),
    "Cluster",
)

check("cores infra (6 reales)", q("SELECT DISTINCT cores FROM dim_infraestructura"), 6.0)
estado_salud = (resultado["veredicto_ia"].get("estado_salud") or {}).get("estado", "N/D")
check("estado de salud calculado", estado_salud, "OK")
check("episodios detectados (motor de anomalias oclumon)", len(resultado["resultado_episodios"]["episodios"]), 11)
tiempos_archivo = resultado["resumen_ingesta"]["tiempos"]["por_archivo"]
check("archivos con tiempos parse/insert separados", all(
    {"bytes", "parse_seg", "insert_seg", "segundos", "filas"} <= set(fila)
    for fila in tiempos_archivo
), True)
check("hueco de captura inserta un punto null", _insertar_huecos([
    {"t": 0, "v": 1.0}, {"t": 5, "v": 2.0}, {"t": 3600, "v": 3.0},
]), [
    {"t": 0, "v": 1.0}, {"t": 5, "v": 2.0}, {"t": 10, "v": None},
    {"t": 3600, "v": 3.0},
])
check("ventanas de captura detectadas", len(
    resultado["resultado_episodios"]["ventanas_captura"]
), 1)
check("hora CHM estable en contenedor UTC", _epoch_hora_origen(
    "2026-09-30T02:35:04"
), 1790735704)
primera_serie = next(
    puntos for series in resultado["resultado_episodios"]["series_por_nodo"].values()
    for puntos in series.values() if puntos
)
check("series columnares para HTML y persistencia", isinstance(primera_serie, dict) and "clock" in primera_serie, True)

c.close()
shutil.rmtree(tmp, ignore_errors=True)
print("\n" + ("TODO OK" if not fallos else f"{len(fallos)} FALLOS: {fallos}"))
sys.exit(1 if fallos else 0)
