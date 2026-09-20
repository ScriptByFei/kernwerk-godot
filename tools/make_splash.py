"""Make the visible web load screen (`index.png`) cheap.

The browser shows the exported splash as `#status-splash` while the engine loads,
so its bytes sit on the critical path of every visit. Godot always writes it as an
RGB PNG, and the artwork is a soft gradient — exactly the input deflate cannot
compress: 1.579.102 B for a 810x1440 image (measured, Sep 2026).

**Operate on the EXPORTED file, not on the source asset.** Measured and rejected:
shrinking `assets/splash/boot_splash.png` first does NOT shrink the export — Godot
imports that PNG as a VRAM-compressed texture and re-encodes the splash from the
imported texture, so the exported `index.png` stayed at 1.579.102 B and even grew
when the quantization grain fed back into it. The export step is the only place
where the bytes can be touched.

Measured on the real export (810x1440, 256 colours, no dithering):
1.579.102 -> 566.743 B (-64,1 %), PSNR 35,69 dB, max |diff| 61/255. At real
display size (390 px wide) the mean difference is 1,43/255 and the difference is
not visible side by side; a WebP rewrite would be smaller still but is not offered
because the engine's HTML requests `index.png` by name — swapping the format means
editing generated HTML, which the next export overwrites.

    python3 tools/make_splash.py build/web/index.png
    python3 tools/make_splash.py --self-test       # known-value checks, no project needed
    python3 tools/make_splash.py build/web/index.png --report-only
"""

from __future__ import annotations

import argparse
import json
import math
import os
import sys
from typing import Any, Dict, Optional

DEFAULT_NAME = "index.png"
DEFAULT_COLORS = 256
# Below this the quantized screen is visibly mushy. Calibrated against the real
# export (35,7 dB) and a deliberately destroyed one (12,1 dB) — not guessed.
MIN_PSNR_DB = 30.0
# A palette PNG of a fine-grained gradient stays well under this ratio
# (measured 0,36 on the real export, 0,48-0,60 on synthetic stand-ins).
MAX_SIZE_RATIO = 0.65


def _pillow():
    """Return Pillow, or exit with a message that says what to do about it.

    The CI runner has no Pillow by default, so this path is a real one — a bare
    ImportError would leave the operator guessing which package is missing.
    """
    try:
        from PIL import Image, ImageChops  # noqa: F401
    except ImportError:  # pragma: no cover - environment dependent
        print("FAIL: Pillow is required (python3 -m pip install 'pillow>=11,<13')",
              file=sys.stderr)
        raise SystemExit(2)
    from PIL import Image, ImageChops

    return Image, ImageChops


def open_image(path: str):
    """Open a PNG, or exit with a plain message. A traceback tells the operator nothing."""
    Image, _chops = _pillow()
    try:
        return Image.open(path)
    except Exception as exc:
        print(f"FAIL: {path} is not a readable image ({exc})", file=sys.stderr)
        raise SystemExit(1)


def psnr(a, b) -> float:
    """Peak signal-to-noise ratio in dB between two same-size images."""
    _Image, ImageChops = _pillow()
    diff = ImageChops.difference(a.convert("RGB"), b.convert("RGB"))
    hist = diff.histogram()
    pixels = a.size[0] * a.size[1] * 3
    mse = 0.0
    for channel in range(3):
        for value in range(256):
            mse += (hist[channel * 256 + value] * value * value) / pixels
    if mse <= 0:
        return float("inf")
    return 10.0 * math.log10((255.0 * 255.0) / mse)


def max_abs_diff(a, b) -> int:
    _Image, ImageChops = _pillow()
    diff = ImageChops.difference(a.convert("RGB"), b.convert("RGB"))
    return max(diff.getextrema()[channel][1] for channel in range(3))


def optimize(path: str, colors: int = DEFAULT_COLORS,
             report_only: bool = False) -> Dict[str, Any]:
    Image, _chops = _pillow()
    before_bytes = os.path.getsize(path)
    original = open_image(path)
    report: Dict[str, Any] = {
        "file": os.path.abspath(path),
        "source_mode": original.mode,
        "size": list(original.size),
        "bytes_before": before_bytes,
        "colors": colors,
    }

    if original.mode in ("P", "1"):
        report.update({"skipped": "already palette/indexed", "bytes_after": before_bytes,
                       "saved_bytes": 0, "saved_percent": 0.0, "written": False})
        return report

    rgb = original.convert("RGB")
    # Dithering is deliberately absent: measured on the real export, Floyd-Steinberg
    # and NONE produce BYTE-IDENTICAL output (the palette has more room than the
    # gradient needs), so an option here would be a switch that does nothing.
    quantized = rgb.quantize(colors=colors, method=Image.Quantize.MEDIANCUT,
                             dither=Image.Dither.NONE)
    tmp = path + ".opt.tmp"
    quantized.save(tmp, format="PNG", optimize=True)
    after_bytes = os.path.getsize(tmp)

    report.update({
        "bytes_after": after_bytes,
        "saved_bytes": before_bytes - after_bytes,
        "saved_percent": round(100.0 * (before_bytes - after_bytes) / before_bytes, 2),
        "psnr_db": round(psnr(rgb, quantized), 2),
        "max_abs_diff": max_abs_diff(rgb, quantized),
        "unique_colors_before": rgb.getcolors(maxcolors=1 << 24).__len__(),
        "palette_entries": len(quantized.getcolors() or []),
    })

    if report_only:
        os.unlink(tmp)
        report["report_only"] = True
        report["written"] = False
        return report

    if after_bytes >= before_bytes:
        os.unlink(tmp)
        report.update({"skipped": "palette version is not smaller; kept the original",
                       "bytes_after": before_bytes, "written": False})
        return report

    os.replace(tmp, path)
    report["written"] = True
    return report


def _write_synthetic_png(path: str, size=(240, 360)) -> None:
    """A fine-grained gradient plus hard shapes — the gradient is the hard case.

    The noise matters: a mathematically smooth gradient quantizes to FEWER bytes
    than it occupies as RGB (measured ratio 1,07), so it would prove nothing about
    the real artwork, which carries fine grain and measured 0,35.
    """
    import random

    Image, _chops = _pillow()
    from PIL import ImageDraw

    random.seed(13)
    image = Image.new("RGB", size)
    pixels = image.load()
    for y in range(size[1]):
        for x in range(size[0]):
            base = 14 + 60 * (0.65 * (y / size[1]) + 0.35 * (x / size[0]))
            grain = lambda: random.randint(-8, 8)  # noqa: E731 - local helper
            pixels[x, y] = (max(0, min(255, int(base) + grain())),
                            max(0, min(255, int(base * 1.05) + grain())),
                            max(0, min(255, int(base * 1.30) + grain())))
    draw = ImageDraw.Draw(image)
    draw.rectangle([10, 10, 70, 70], fill=(240, 220, 190))
    draw.rectangle([120, 220, 230, 350], fill=(22, 26, 32))
    image.save(path, format="PNG")


def self_test() -> int:
    """Known-value checks: the measurement must separate good from bad input."""
    import tempfile

    Image, _chops = _pillow()
    failures = []

    def check(name: str, condition: bool, detail: str = "") -> None:
        print(f"{'ok  ' if condition else 'FAIL'} {name}{(' — ' + detail) if detail else ''}")
        if not condition:
            failures.append(name)

    with tempfile.TemporaryDirectory() as tmp:
        rgb_path = os.path.join(tmp, "gradient.png")
        _write_synthetic_png(rgb_path)
        original_bytes = os.path.getsize(rgb_path)
        before = open_image(rgb_path).convert("RGB")

        report = optimize(rgb_path, colors=256)
        after = open_image(rgb_path)
        check("rgb input is converted to palette", after.mode == "P", f"mode={after.mode}")
        check("file gets smaller", os.path.getsize(rgb_path) < original_bytes,
              f"{original_bytes} -> {os.path.getsize(rgb_path)}")
        check("size ratio inside the bound", os.path.getsize(rgb_path) / original_bytes <= MAX_SIZE_RATIO,
              f"ratio={os.path.getsize(rgb_path) / original_bytes:.3f}")
        check("dimensions unchanged", tuple(after.size) == tuple(before.size), str(after.size))
        measure = psnr(before, after.convert("RGB"))
        check("quality above the bound", measure >= MIN_PSNR_DB, f"PSNR={measure:.2f} dB")
        check("report carries the same PSNR", abs(report["psnr_db"] - measure) < 0.01,
              f"{report['psnr_db']} vs {measure:.2f}")

        # Second run must be a no-op, not a re-quantization.
        second = optimize(rgb_path, colors=256)
        check("palette input is skipped", second.get("skipped") == "already palette/indexed",
              str(second.get("skipped")))
        check("skip does not rewrite the file", second.get("written") is False)

        # report-only must leave the file byte-identical.
        rgb_path2 = os.path.join(tmp, "gradient2.png")
        _write_synthetic_png(rgb_path2)
        digest = open(rgb_path2, "rb").read()
        optimize(rgb_path2, report_only=True)
        check("report-only leaves the file untouched", open(rgb_path2, "rb").read() == digest)

        # The measurement itself must fail on a deliberately destroyed image.
        destroyed = Image.new("P", before.size, 0)
        destroyed.save(os.path.join(tmp, "flat.png"))
        flat = open_image(os.path.join(tmp, "flat.png")).convert("RGB")
        check("measurement detects a destroyed image", psnr(before, flat) < MIN_PSNR_DB,
              f"PSNR={psnr(before, flat):.2f} dB")

    print(f"SELFTEST: {'OK' if not failures else 'FAILED'} ({len(failures)} failures)")
    return 0 if not failures else 1


def main(argv: Optional[list[str]] = None) -> int:
    parser = argparse.ArgumentParser(description="Shrink the exported web load screen.")
    parser.add_argument("path", nargs="?",
                        help="PNG file, or the directory holding it (then --name applies)")
    parser.add_argument("--name", default=DEFAULT_NAME)
    parser.add_argument("--colors", type=int, default=DEFAULT_COLORS)
    parser.add_argument("--report-only", action="store_true")
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args(argv)

    if args.self_test:
        return self_test()
    if not args.path:
        parser.error("a path is required unless --self-test is used")

    target = args.path
    if os.path.isdir(target):
        target = os.path.join(target, args.name)
    if not os.path.isfile(target):
        print(f"FAIL: {target} not found", file=sys.stderr)
        return 1

    report = optimize(target, colors=args.colors, report_only=args.report_only)
    print(json.dumps(report, indent=2, ensure_ascii=False))

    if "psnr_db" in report:
        verdict = "OK" if (report["psnr_db"] >= MIN_PSNR_DB
                           and report.get("bytes_after", 0) < report["bytes_before"]) else "FAIL"
        print(f"{verdict}: {report['bytes_before']} -> {report['bytes_after']} bytes "
              f"({report.get('saved_percent', 0)}% saved, PSNR {report['psnr_db']} dB, "
              f"max |diff| {report['max_abs_diff']}/255)")
        if verdict == "FAIL":
            return 1
    elif report.get("skipped"):
        print(f"OK: nothing to do ({report['skipped']})")

    if not args.report_only:
        sidecar = os.path.join(os.path.dirname(os.path.abspath(target)), "splash_report.json")
        with open(sidecar, "w", encoding="utf-8") as handle:
            json.dump(report, handle, indent=2, ensure_ascii=False)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
