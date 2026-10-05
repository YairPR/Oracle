"""Offline browser regression and measured startup/filter/scroll. Optional Playwright."""

import argparse
import json
from pathlib import Path
import time
from playwright.sync_api import sync_playwright

ap = argparse.ArgumentParser()
ap.add_argument("html")
ap.add_argument("out")
ap.add_argument("--baseline", action="store_true")
args = ap.parse_args()
out = Path(args.out)
out.mkdir(parents=True, exist_ok=True)
url = Path(args.html).resolve().as_uri()
results = []
with sync_playwright() as pw:
    browser = pw.chromium.launch(headless=True)
    for zone in ["Europe/Madrid", "America/Los_Angeles", "Asia/Tokyo"]:
        ctx = browser.new_context(
            viewport={"width": 1440, "height": 1000}, timezone_id=zone
        )
        page = ctx.new_page()
        errors = []
        requests = []
        page.on("pageerror", lambda e: errors.append(str(e)))
        page.on("request", lambda r: requests.append(r.url))
        page.add_init_script(
            "document.addEventListener('odl:chart-mounted',()=>{window.__firstChartMs ??= performance.now();});window.__longTasks=[];new PerformanceObserver(list=>window.__longTasks.push(...list.getEntries().map(e=>({start:e.startTime,duration:e.duration})))).observe({type:'longtask',buffered:true});"
        )
        start = time.perf_counter()
        page.goto(url, timeout=120000, wait_until="load")
        page.wait_for_selector("canvas", timeout=120000)
        page.wait_for_timeout(200)
        startup = (time.perf_counter() - start) * 1000
        cdp = ctx.new_cdp_session(page)
        cdp.send("Performance.enable")
        perf = cdp.send("Performance.getMetrics")
        heap = next(
            m["value"] for m in perf["metrics"] if m["name"] == "JSHeapUsedSize"
        )
        first = page.evaluate(
            "({firstChartMs:window.__firstChartMs,paints:performance.getEntriesByType('paint').map(e=>({name:e.name,ms:e.startTime})),charts:window.__odlCharts.length})"
        )
        page.screenshot(
            path=str(out / f"header-{zone.replace('/', '-')}.png"), full_page=False
        )

        def read_date(which):
            value = page.locator("#odl-rango-" + which).input_value()
            return value + ":00" if len(value) == 16 else value

        def draft(a, b):
            page.locator("#odl-rango-desde").evaluate(
                '(el,v)=>{el.value=v;el.dispatchEvent(new Event("input",{bubbles:true}));}',
                a,
            )
            page.locator("#odl-rango-hasta").evaluate(
                '(el,v)=>{el.value=v;el.dispatchEvent(new Event("input",{bubbles:true}));}',
                b,
            )

        def apply():
            start = time.perf_counter()
            page.locator("#odl-rango-aplicar").click()
            page.wait_for_timeout(50)
            return (time.perf_counter() - start) * 1000

        draft("2026-09-30T01:00:00", "2026-09-30T03:30:00")
        filter_wall = apply()
        measured_filter = None
        if not args.baseline:
            state = page.evaluate("window.__odlTemporalState")
            assert page.locator("#odl-rango-captura").input_value() == "custom"
            option = page.evaluate("window.__odlCharts[0].getOption()")
            assert (
                option["xAxis"][0]["min"] == state["from"]
                and option["xAxis"][0]["max"] == state["to"]
            )
            timestamps = [
                p[0] for s in option["series"] for p in s["data"] if p[1] is not None
            ]
            assert min(timestamps) >= state["from"] and max(timestamps) <= state["to"]
            page.locator("#odl-rango-ajustar").click()
            assert read_date("desde") == "2026-09-30T02:35:04"
            assert read_date("hasta") == "2026-09-30T02:49:59"
            page.locator("#odl-rango-captura").select_option("0")
            assert read_date("desde") == "2026-09-30T02:35:04"
            assert read_date("hasta") == "2026-09-30T02:49:59"
            page.screenshot(path=str(out / "capture-30-september.png"))
            # Legend belongs to the chart, never reset by shared dates.
            name = page.evaluate("window.__odlCharts[0].getOption().series[0].name")
            page.evaluate(
                '(name)=>window.__odlCharts[0].dispatchAction({type:"legendUnSelect",name})',
                name,
            )
            page.locator("#odl-rango-aplicar").click()
            assert (
                page.evaluate(
                    "(name)=>window.__odlCharts[0].getOption().legend[0].selected[name]",
                    name,
                )
                is False
            )
            # Mount additional charts with a pending draft; applied state must survive.
            applied = page.evaluate("window.__odlTemporalState")
            draft("2026-09-30T01:00:00", "2026-09-30T03:30:00")
            page.locator('[data-target="sec-timeline"]').click()
            page.wait_for_timeout(200)
            from datetime import datetime, timezone

            visible_times = page.locator("#sec-timeline tr[data-ts]").evaluate_all(
                "rows=>rows.filter(row=>!row.hidden).map(row=>row.dataset.ts)"
            )
            for value in visible_times:
                ms = (
                    datetime.fromisoformat(value)
                    .replace(tzinfo=timezone.utc)
                    .timestamp()
                    * 1000
                )
                assert applied["from"] <= ms <= applied["to"]
            page.locator('[data-target="sec-oclumon"]').click()
            page.wait_for_timeout(100)
            assert page.evaluate("window.__odlTemporalState") == applied
            assert read_date("desde") == "2026-09-30T01:00:00"
            page.evaluate("window.scrollTo(0,1200)")
            page.wait_for_timeout(300)
            assert page.evaluate("window.__odlTemporalState") == applied
            page.evaluate("window.scrollTo(0,0)")
            page.locator("#odl-rango-restaurar").click()
            captures = page.evaluate(
                "window.__PAYLOAD__.motor_episodios.ventanas_captura"
            )
            for i, c in enumerate(captures):
                page.locator("#odl-rango-captura").select_option(str(i))
                assert read_date("desde") == c["inicio"]
                assert read_date("hasta") == c["fin"]
            page.locator("#odl-rango-captura").select_option("")
            assert page.locator("#odl-rango-captura").input_value() == ""
            # Empty interval removes previous curves and fit never escapes its bounds.
            draft("2026-10-01T01:00:00", "2026-10-01T02:00:00")
            apply()
            page.locator("#odl-rango-ajustar").click()
            assert read_date("desde") == "2026-10-01T01:00:00"
            assert read_date("hasta") == "2026-10-01T02:00:00"
            assert page.evaluate(
                "window.__odlCharts[0].getOption().series.every(s=>s.data.length===0)"
            )
            page.screenshot(path=str(out / "empty-interval.png"))
            # One sample has a +/-1 second common-axis margin and a visible point.
            draft("2026-09-30T02:35:04", "2026-09-30T02:35:04")
            apply()
            opt = page.evaluate("window.__odlCharts[0].getOption()")
            st = page.evaluate("window.__odlTemporalState")
            assert (
                opt["xAxis"][0]["min"] == st["from"] - 1000
                and opt["xAxis"][0]["max"] == st["to"] + 1000
            )
            assert any(s["showSymbol"] and len(s["data"]) == 1 for s in opt["series"])
            page.locator("#odl-rango-captura").select_option("0")
            measured_filter = page.evaluate("window.__odlPerformance.filterMs")
            page.screenshot(path=str(out / "final-header.png"))
        page.mouse.move(450, 450)
        page.mouse.wheel(0, 700)
        page.wait_for_function("window.scrollY > 0", timeout=5000)
        assert page.evaluate("window.scrollY") > 0, (
            "wheel must scroll freely over a chart"
        )
        page.evaluate("window.scrollTo(0,0)")
        # Scroll frame times under real lazy mounting; browser's long tasks are recorded.
        page.locator("#odl-rango-restaurar").click()
        page.wait_for_timeout(100)
        scroll = page.evaluate(
            """async()=>{const frames=[];const start=performance.now();let prev=start;for(let y=0;y<6000;y+=180){window.scrollTo(0,y);await new Promise(requestAnimationFrame);const now=performance.now();frames.push(now-prev);prev=now;}return {frames,longTasks:window.__longTasks.filter(e=>e.start>=start)};}"""
        )
        metrics = cdp.send("Performance.getMetrics")
        heap_scroll = next(
            m["value"] for m in metrics["metrics"] if m["name"] == "JSHeapUsedSize"
        )
        assert not errors, errors
        assert all(u.startswith("file:") or u.startswith("data:") for u in requests), (
            requests
        )
        results.append(
            dict(
                zone=zone,
                startup_wall_ms=startup,
                initial_heap_bytes=heap,
                scroll_heap_bytes=heap_scroll,
                first=first,
                filter_wall_ms=filter_wall,
                filter_internal_ms=measured_filter,
                scroll=scroll,
                errors=errors,
            )
        )
        ctx.close()
    browser.close()
(out / "browser-metrics.json").write_text(
    json.dumps(results, indent=2), encoding="utf-8"
)
print("Offline browser checks OK: three timezones")
