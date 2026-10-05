"""Paired offline render/filter measurements in the same Chromium process."""
import argparse
import json
from pathlib import Path
import statistics
import time
from playwright.sync_api import sync_playwright

parser = argparse.ArgumentParser()
parser.add_argument('before')
parser.add_argument('after')
parser.add_argument('output')
args = parser.parse_args()
results = {'before': [], 'after': []}
with sync_playwright() as pw:
    browser = pw.chromium.launch(headless=True)
    for run in range(3):
        for label in (['before', 'after'] if run % 2 == 0 else ['after', 'before']):
            context = browser.new_context(viewport={'width':1440,'height':1000},timezone_id='Europe/Madrid')
            page = context.new_page()
            start = time.perf_counter()
            page.goto(Path(getattr(args,label)).resolve().as_uri(),wait_until='load')
            page.wait_for_function('window.__odlCharts?.length>=4 && window.__odlTemporalState')
            load_ms = (time.perf_counter()-start)*1000
            cdp = context.new_cdp_session(page)
            cdp.send('Performance.enable')
            heap = next(v['value'] for v in cdp.send('Performance.getMetrics')['metrics'] if v['name']=='JSHeapUsedSize')
            header = page.locator('.odl-universal-header').bounding_box()['height']
            page.locator('#odl-rango-desde').evaluate("el=>{const ms=window.__odlTemporalState.from+5000+(window.__PAYLOAD__.display_clock?.offset_minutes||0)*60000;el.value=new Date(ms).toISOString().slice(0,19);el.dispatchEvent(new Event('input'));}")
            start = time.perf_counter()
            page.locator('#odl-rango-aplicar').click()
            filter_ms = (time.perf_counter()-start)*1000
            results[label].append({'run':run,'load_ms':load_ms,'filter_ms':filter_ms,'heap_bytes':heap,'header_px':header,'canvas':page.locator('canvas').count()})
            print(label,run,round(load_ms),round(filter_ms),flush=True)
            context.close()
    browser.close()
summary = {label:{key:statistics.median(r[key] for r in rows) for key in ['load_ms','filter_ms','heap_bytes','header_px','canvas']} for label,rows in results.items()}
Path(args.output).write_text(json.dumps({'samples':results,'medians':summary},indent=2),encoding='utf-8')
print(summary)
