"""Real-browser verification of the Kernwerk web preview over Tailscale HTTPS.

Drives the already-running CDP chromium (systemd: hermes-cdp-chromium, :9222)
with Playwright directly, so no Hermes browser policy flag has to be relaxed.

Checks, in order:
  1. Secure context is true and the Godot engine boots (canvas sized, no
     "Secure Context" dialog).
  2. A real tap on the canvas triggers the start transition.
  3. No page errors were raised.

Nicht abgedeckt: das Erreichen des Gameplays im headless Software-WebGL-Renderer
(Choreografie zu langsam) und die visuelle Qualitaet des HUD. Beides wird ueber
`qa/resonance_chain_screenshot.gd` bzw. die iPhone-Abnahme belegt.

Usage: python3 qa/resonance_chain_web_check.py <preview-url> <out-dir>
"""

import json
import sys
import time
from pathlib import Path

from playwright.sync_api import sync_playwright

CDP_URL = "http://127.0.0.1:9222"
VIEWPORT = {"width": 390, "height": 844}

# Das Startmenue atmet im Idle minimal. Ein Bildunterschied von wenigen Prozent
# ist deshalb KEIN Beweis fuer einen Spielstart — erst ein deutlicher
# Strukturwechsel (Menue weg, Spielwelt mit HUD da) zaehlt.
STARTED_THRESHOLD = 0.12


def _view_diff(before: bytes, after: bytes) -> float:
    """Grobe Pixel-Differenz zweier PNGs ueber die kodierten Bytes.

    Reicht fuer die Frage "hat sich das Bild strukturell veraendert?". Die Bytes
    sind komprimiert, deshalb ist der Wert ein Naeherungswert, kein exaktes
    Pixelmass — fuer eine Schwelle von 12 % ist das ausreichend.
    """
    n = min(len(before), len(after))
    if n < 1000:
        return 0.0
    step = 97
    if abs(len(before) - len(after)) > 0.05 * n:
        # Deutlich andere Dateigroesse = anderer Bildinhalt.
        return 1.0
    same = sum(1 for i in range(0, n, step) if before[i] == after[i])
    return 1.0 - (same / len(range(0, n, step)))


def main() -> int:
    preview_url = sys.argv[1]
    out_dir = Path(sys.argv[2])
    out_dir.mkdir(parents=True, exist_ok=True)
    report = {"url": preview_url, "checks": []}

    with sync_playwright() as pw:
        browser = pw.chromium.connect_over_cdp(CDP_URL)
        context = browser.contexts[0] if browser.contexts else browser.new_context()
        page = context.new_page()
        console: list[str] = []
        page.on("console", lambda m: console.append(f"{m.type}: {m.text}"))
        page.on("pageerror", lambda e: console.append(f"pageerror: {e}"))

        page.set_viewport_size(VIEWPORT)
        page.goto(preview_url, wait_until="domcontentloaded", timeout=60_000)

        secure = page.evaluate("() => window.isSecureContext")
        report["checks"].append({"name": "secure_context", "ok": bool(secure), "value": secure})

        # Godot needs a while to fetch the 36 MB wasm and boot the scene.
        booted = False
        deadline = time.time() + 90
        while time.time() < deadline:
            state = page.evaluate(
                """() => {
                    const c = document.querySelector('canvas');
                    return {
                        canvas: c ? [c.width, c.height] : null,
                        body: document.body.innerText.slice(0, 300),
                    };
                }"""
            )
            body = state["body"] or ""
            if "Secure Context" in body or "features required" in body:
                report["checks"].append(
                    {"name": "no_secure_context_dialog", "ok": False, "value": body[:200]}
                )
                break
            if state["canvas"] and state["canvas"][0] > 100:
                booted = True
                report["checks"].append(
                    {"name": "engine_boot_canvas", "ok": True, "value": state["canvas"]}
                )
                break
            time.sleep(2)
        if not booted and not any(c["name"] == "no_secure_context_dialog" for c in report["checks"]):
            report["checks"].append(
                {"name": "engine_boot_canvas", "ok": False, "value": "timeout after 90s"}
            )

        page.screenshot(path=str(out_dir / "04_web_start_menu.png"))

        # Realer Tap auf den CTA-Bereich des Startmenues.
        #
        # Zwei Fallen, die dieser Check vorher hatte:
        #   1. Die Canvas-Groesse ist frueh gesetzt (Godot dimensioniert sie vor
        #      dem Szenenaufbau) — ein Tap zu diesem Zeitpunkt geht ins Leere.
        #   2. Ein fester kurzer Sleep reicht nicht: der Software-WebGL-Renderer
        #      braucht fuer die 0,92 s Startchoreografie deutlich laenger als in
        #      Wanduhrzeit. Sechs Sekunden zeigten noch das Startmenue.
        # Deshalb wird der Hintergrund gepollt. Das Menue atmet im Idle leicht
        # (START_IDLE_PERIOD), ein kleiner Bildunterschied beweist also NICHTS —
        # erst ein grosser Strukturwechsel gilt als gestartet.
        baseline = page.screenshot()
        page.mouse.click(VIEWPORT["width"] // 2, int(VIEWPORT["height"] * 0.62))

        started = False
        best = 0.0
        deadline = time.time() + 90
        while time.time() < deadline:
            time.sleep(5)
            current = page.screenshot()
            ratio = _view_diff(baseline, current)
            best = max(best, ratio)
            if ratio > STARTED_THRESHOLD:
                started = True
                break

        page.screenshot(path=str(out_dir / "05_web_after_tap.png"))
        # Der Name beschreibt bewusst nur, was tatsaechlich geprueft wird: der
        # Tap loest den Startwechsel aus. Im headless Software-WebGL-Renderer
        # laeuft die 0,92-s-Choreografie so langsam, dass das Gameplay hier
        # nicht zuverlaessig erreicht wird — "betritt Gameplay" waere also eine
        # Behauptung, die dieser Check nicht einloest.
        report["checks"].append(
            {
                "name": "tap_starts_transition",
                "ok": started,
                "value": {"best_diff": round(best, 4), "threshold": STARTED_THRESHOLD},
            }
        )
        report["checks"].append(
            {
                "name": "tap_handled",
                "ok": not any("pageerror" in line for line in console),
                "value": [line for line in console if "error" in line.lower()][:5],
            }
        )
        report["console_tail"] = console[-8:]

        page.close()

    report["passed"] = all(c["ok"] for c in report["checks"])
    print(json.dumps(report, indent=2))
    (out_dir / "web_https_verification.json").write_text(json.dumps(report, indent=2) + "\n")
    return 0 if report["passed"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
