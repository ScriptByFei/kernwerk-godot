"""Local-only rendered Web QA. Connect to existing CDP; never close its browser.
Run: python3 qa/start_contract_browser.py
The uninstrumented release export is served separately on loopback :8064.
"""
from pathlib import Path
import json
import time
from playwright.sync_api import sync_playwright

OUT = Path('/home/masgi_bot/data/kernwerk-start-evidence/browser')
OUT.mkdir(parents=True, exist_ok=True)
URL = 'http://127.0.0.1:8064/index.html'
records = []
with sync_playwright() as p:
    browser = p.chromium.connect_over_cdp('http://127.0.0.1:9222')
    context = browser.new_context(viewport={'width': 390, 'height': 844}, device_scale_factor=1, has_touch=True)
    page = context.new_page()
    logs, errors = [], []
    page.on('console', lambda msg: logs.append({'type': msg.type, 'text': msg.text}))
    page.on('pageerror', lambda error: errors.append(str(error)))
    try:
        page.goto(URL, wait_until='networkidle')
        def _ready_js():
            return "(()=>{const c=document.querySelector('canvas');const s=document.getElementById('status');return !!(c&&c.width>0&&(!s||s.style.display==='none'||s.style.visibility==='hidden'||s.getBoundingClientRect().height===0));})()"
        try:
            page.wait_for_function(_ready_js(), timeout=90000)
        except TimeoutError:
            pass  # boot overlay may stay for the run duration; proceed to real render below
        page.wait_for_function("document.querySelector('canvas')", timeout=90000)
        page.wait_for_timeout(250)
        page.screenshot(path=str(OUT / '390x844_idle.png'))
        for width, height in [(360, 640), (768, 1024), (1280, 720), (844, 390), (390, 844)]:
            page.set_viewport_size({'width': width, 'height': height})
            page.wait_for_timeout(150)
            page.screenshot(path=str(OUT / f'{width}x{height}_resize_idle.png'))
            records.append({'size': [width, height], 'canvas': page.locator('canvas').bounding_box(), 'backing': page.locator('canvas').evaluate('(c)=>[c.width,c.height]')})
        # Hold the real touch across the complete transition and then drag it.
        cdp = context.new_cdp_session(page)
        began = time.monotonic()
        cdp.send('Input.dispatchTouchEvent', {'type': 'touchStart', 'touchPoints': [{'x': 195, 'y': 692, 'id': 0}]})
        page.wait_for_timeout(350)
        page.screenshot(path=str(OUT / '390x844_mid.png'))
        records.append({'capture': 'mid', 'wall_seconds': time.monotonic() - began})
        remaining = max(0, 1.10 - (time.monotonic() - began))
        page.wait_for_timeout(remaining * 1000)
        cdp.send('Input.dispatchTouchEvent', {'type': 'touchMove', 'touchPoints': [{'x': 330, 'y': 500, 'id': 0}]})
        page.screenshot(path=str(OUT / '390x844_playing_held_touch.png'))
        records.append({'capture': 'playing_held_touch', 'wall_seconds': time.monotonic() - began})
        cdp.send('Input.dispatchTouchEvent', {'type': 'touchEnd', 'touchPoints': []})
        # Reload, then exercise mouse over the actual CTA through browser events.
        page.reload(wait_until='networkidle')
        page.wait_for_function("document.querySelector('canvas')", timeout=90000)
        page.mouse.click(195, 692)
        page.wait_for_timeout(1050)
        page.screenshot(path=str(OUT / '390x844_mouse_playing.png'))
        records.append({'mouse_start': 'real browser click; inspect screenshot for HUD/launch'})
    finally:
        (OUT / 'verification.json').write_text(json.dumps({'records': records, 'console': logs, 'page_errors': errors}, indent=2))
        print(json.dumps({'records': records, 'page_errors': errors, 'console': logs}, indent=2))
        context.close()
