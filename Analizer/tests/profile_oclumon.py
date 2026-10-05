"""Profile adapters/series on exact source blocks, independently of DuckDB."""

import argparse
import cProfile
import gc
import hashlib
import json
from pathlib import Path
import pstats
import sys
import time

ap = argparse.ArgumentParser()
ap.add_argument("input")
ap.add_argument("out")
ap.add_argument("--blocks", type=int, default=180)
ap.add_argument("--source", default=str(Path(__file__).resolve().parents[1]))
args = ap.parse_args()
sys.path.insert(0, args.source)
from core.oclumon_model import parse
from core.episode_engine import analizar_caso

out = Path(args.out)
out.mkdir(parents=True, exist_ok=True)
fixture = out / "source-blocks.data"
with (
    Path(args.input).open(encoding="utf-8", errors="replace") as src,
    fixture.open("w", encoding="utf-8") as dst,
):
    blocks = 0
    for line in src:
        if line.startswith("Node:"):
            blocks += 1
            if blocks > args.blocks:
                break
        dst.write(line)


def run():
    start = time.perf_counter()
    samples, diagnostic, ranks = parse(fixture)
    parsed = time.perf_counter()
    result = analizar_caso(
        [str(fixture)],
        normalizados={str(fixture): (samples, diagnostic, ranks)},
        log_cb=lambda s: None,
    )
    end = time.perf_counter()
    return (
        samples,
        result,
        {"parse_seconds": parsed - start, "series_seconds": end - parsed},
    )


samples, result, timing = run()
values = {
    node: {
        key: [(p["t"], p["v"]) for p in points if p["v"] is not None]
        for key, points in series.items()
    }
    for node, series in result["series_por_nodo"].items()
}
timing.update(
    {
        "samples": len(samples),
        "series": sum(map(len, result["series_por_nodo"].values())),
        "source_sha256": hashlib.sha256(fixture.read_bytes()).hexdigest(),
        "valid_points_sha256": hashlib.sha256(
            json.dumps(values, sort_keys=True).encode()
        ).hexdigest(),
        "represented_points": sum(
            len(p)
            for series in result["series_por_nodo"].values()
            for p in series.values()
        ),
    }
)
(out / "metrics.json").write_text(json.dumps(timing, indent=2), encoding="utf-8")
del samples, result, values
gc.collect()
prof = cProfile.Profile()
prof.runcall(run)
prof.dump_stats(str(out / "profile.pstats"))
with (out / "profile.txt").open("w", encoding="utf-8") as f:
    pstats.Stats(prof, stream=f).sort_stats("cumulative").print_stats(25)
print(json.dumps(timing), flush=True)
