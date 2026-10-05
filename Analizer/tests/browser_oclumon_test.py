"""Offline UI acceptance for any host count, CSV offsets and temporal analysis."""

import argparse
import json
from pathlib import Path
import time
from playwright.sync_api import sync_playwright

ap = argparse.ArgumentParser()
ap.add_argument("html")
ap.add_argument("out")
ap.add_argument("--hosts", type=int, required=True)
ap.add_argument("--baseline", action="store_true")
args = ap.parse_args()
out = Path(args.out)
out.mkdir(parents=True, exist_ok=True)
results = []
with sync_playwright() as pw:
    browser = pw.chromium.launch(headless=True)
    for zone in ["Europe/Madrid", "America/Los_Angeles", "Asia/Tokyo"]:
        print(f"Opening offline report: {zone}", flush=True)
        ctx = browser.new_context(
            viewport={"width": 1440, "height": 1000}, timezone_id=zone
        )
        page = ctx.new_page()
        errors = []
        requests = []
        page.on("pageerror", lambda e: errors.append(str(e)))
        page.on("request", lambda r: requests.append(r.url))
        start = time.perf_counter()
        page.goto(Path(args.html).resolve().as_uri(), wait_until="load")
        if not args.baseline:
            page.wait_for_selector("canvas")
        startup = (time.perf_counter() - start) * 1000
        print(f"Loaded in {startup:.0f} ms", flush=True)
        cdp = ctx.new_cdp_session(page)
        cdp.send("Performance.enable")
        heap = next(
            m["value"]
            for m in cdp.send("Performance.getMetrics")["metrics"]
            if m["name"] == "JSHeapUsedSize"
        )
        if args.baseline:
            results.append(
                {
                    "zone": zone,
                    "startup_ms": startup,
                    "heap_bytes": heap,
                    "errors": errors,
                }
            )
            ctx.close()
            continue
        assert page.locator(".odl-host-item").count() == args.hosts
        assert page.locator(".odl-title").text_content().find(f"{args.hosts} nodo") >= 0
        assert "standalone" not in page.locator(".odl-title").text_content().lower()
        assert not page.locator("#odl-rango-nodos").count()
        # Inspect metadata in the browser; transferring all full-resolution
        # process/device series through the automation pipe is unnecessary.
        me = page.evaluate("""() => {
          const m=window.__PAYLOAD__.motor_episodios;
          return {node_list:m.node_list, ventanas_captura:m.ventanas_captura,
                  coverage:m.coverage, time_domains:m.time_domains,
                  collectors:(m.oclumon_diagnostics||[]).map(d=>d.source_metadata?.collector_version),
                  memavl:!!m.metric_contracts?.memavl_gib};
        }""")
        assert len(me["node_list"]) == args.hosts
        assert page.evaluate(
            """expected=>[...document.querySelectorAll('[data-chart]')].some(e=>JSON.parse(e.dataset.chart).serie==='memavl_gib')===expected""",
            me["memavl"],
        )
        if me["collectors"] and all(me["collectors"]):
            # Collector provenance must not become the database title.
            if all(v == "19c" for v in me["collectors"]):
                assert "19c" not in page.locator(".odl-title").text_content()
                assert (
                    "recolector/Grid: 19c"
                    in page.locator("#sec-oclumon").text_content()
                )
        full = page.evaluate("window.__odlTemporalState")
        assert full["from"] < full["to"]
        cap = me["ventanas_captura"][0]
        page.locator("#odl-rango-captura").select_option("0")
        applied = page.evaluate("window.__odlTemporalState")
        date = lambda ms: page.evaluate(
            "ms=>new Date(ms).toISOString().slice(0,19)", ms
        )

        def draft(a, b):
            for which, value in [("desde", a), ("hasta", b)]:
                page.locator("#odl-rango-" + which).evaluate(
                    '(el,v)=>{el.value=v;el.dispatchEvent(new Event("input",{bubbles:true}));}',
                    value,
                )

        # Scope is explicit: a custom interval outside this capture remains unapplied.
        draft(date(applied["from"] - 1000), date(applied["to"]))
        page.locator("#odl-rango-aplicar").click()
        assert page.evaluate("window.__odlTemporalState") == applied
        page.locator("#odl-rango-captura").select_option("")
        step = int(me["coverage"][me["node_list"][0]]["cadence_seconds"] * 1000)
        lo, hi = full["from"] + step, full["to"]
        draft(date(lo), date(hi))
        start = time.perf_counter()
        page.locator("#odl-rango-aplicar").click()
        filtering = (time.perf_counter() - start) * 1000
        assert page.locator("#odl-rango-captura").input_value() == "custom"
        current = page.evaluate("window.__odlTemporalState")
        assert current["from"] == lo
        # A and B use original-resolution statistics, even when charts are not mounted.
        page.locator("#odl-analysis > summary").click()
        page.wait_for_function(
            "document.getElementById('odl-analysis-output').textContent.includes('muestras')"
        )
        assert "muestras" in page.locator("#odl-analysis-output").text_content()
        page.locator("#odl-analysis-save").click()
        assert (
            "referencia fijada" in page.locator("#odl-analysis-output").text_content()
        )
        # Pending input edits cannot alter the applied state during tab/lazy changes.
        draft(date(full["from"]), date(full["to"]))
        page.locator('[data-target="sec-timeline"]').click()
        assert page.evaluate("window.__odlTemporalState") == current
        page.locator('[data-target="sec-oclumon"]').click()
        page.locator("#odl-analysis > summary").click()
        canvas = page.locator("canvas").first
        canvas.scroll_into_view_if_needed()
        box = canvas.bounding_box()
        before_scroll = page.evaluate("scrollY")
        page.mouse.move(box["x"] + box["width"] / 2, box["y"] + box["height"] / 2)
        page.mouse.wheel(0, 600)
        page.wait_for_function("before=>window.scrollY>before", arg=before_scroll)
        page.evaluate("window.scrollTo(0,0)")
        page.locator("#odl-rango-restaurar").click()
        page.screenshot(path=str(out / f"header-{zone.replace('/', '-')}.png"))
        # A source offset is preserved; chosen display is UTC, invariant to browser zone.
        if me.get("time_domains") == ["+0200"]:
            assert "UTC" in page.locator(".odl-time-help").text_content()
            assert "pCPU 9" in page.locator(".odl-host-item").first.text_content()
            assert "cores 18" in page.locator(".odl-host-item").first.text_content()
            assert "vCPU 18" in page.locator(".odl-host-item").first.text_content()
        draft(date(full["to"] + 86400000), date(full["to"] + 86460000))
        page.locator("#odl-rango-aplicar").click()
        page.locator("#odl-rango-ajustar").click()
        assert "Sin muestras" in page.locator("#odl-rango-nota").text_content()
        assert page.evaluate(
            "window.__odlCharts[0].getOption().series.every(s=>s.data.length===0)"
        )
        page.screenshot(path=str(out / "empty.png"))
        page.locator("#odl-rango-restaurar").click()
        # Narrow displays must wrap cards/filters rather than overflow horizontally.
        page.set_viewport_size({"width": 390, "height": 844})
        page.wait_for_function(
            "document.documentElement.scrollWidth<=innerWidth+1", timeout=5000
        )
        page.screenshot(path=str(out / "mobile.png"))
        assert page.evaluate("document.documentElement.scrollWidth<=innerWidth+1")
        assert not errors, errors
        assert all(u.startswith(("file:", "data:")) for u in requests), requests
        results.append(
            {
                "zone": zone,
                "hosts": args.hosts,
                "startup_ms": startup,
                "filter_ms": filtering,
                "heap_bytes": heap,
                "errors": errors,
            }
        )
        ctx.close()
    browser.close()
(out / "metrics.json").write_text(json.dumps(results, indent=2), encoding="utf-8")
print(f"Offline OCLUMON checks OK: {args.hosts} hosts, three timezones")
