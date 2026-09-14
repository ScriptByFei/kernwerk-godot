#!/usr/bin/env python3
"""Erzeugt das atmosphaerische Klangbett fuer Kernwerk: Resonanzsprung.

Warum prozedural und nicht per KI-Generierung:
Das Spiel laeuft endlos, das Klangbett muss also nahtlos schleifen. Ein
KI-Clip hat an der Nahtstelle immer einen Sprung. Hier liegt JEDE
Teilfrequenz auf einem ganzzahligen Vielfachen von 1/T — das Signal ist damit
mathematisch exakt periodisch. Die Naht ist nicht kaschiert, sondern existiert
nicht. Nachgewiesen wird das in tools/verify_ambience_seam.py.

Zwei Schichten, beide gleich lang und damit sample-genau synchron:
  shaft_ambience  Grundklang: der Hallraum des Reaktorschachts.
  shaft_tension   Spannungsschicht: schimmert mit steigender Hoehe auf.

Geräusch wird im Frequenzbereich gebaut (Betrag gesetzt, Phase gewuerfelt,
ruecktransformiert). Das ist derselbe periodische Sinus-Ansatz wie bei den
Toenen, nur in einem Rechenschritt — tausende einzelne Sinus zu summieren
dauerte auf dem Pi ueber eine Stunde statt Sekunden.

Aufruf:  python3 tools/make_ambience.py
"""

import math
import subprocess
import wave
from pathlib import Path

import numpy as np

SAMPLE_RATE = 44100      # interne Rechnung
# Ausgaberate: gemessen liegt 0,000 % der Energie ueber 11 kHz, also halbiert
# 22,05 kHz die Dateigroesse ohne hoerbaren Verlust. Die Naht muss dann auf der
# AUSGABERATE geprueft werden, nicht auf der internen.
OUTPUT_RATE = 22050
DURATION = 40.0          # Sekunden; alle Raten sind Vielfache von 1/T
PEAK_DBFS = -6.0         # Spitze; im Spiel laeuft das Bett ohnehin gedaempft
# Vorbis-Qualitaet. q=3 erzeugt an der Dateigrenze ein hoerbares Artefakt
# (gemessen: Naht-Sprung 0,0205 gegenueber 0,0017 typisch), q>=5 nicht mehr.
VORBIS_QUALITY = 6
OUT_DIR = Path("assets/jump/audio")
SEED = 13071337


def grid(freq: float) -> float:
    """Naechste Frequenz, die in der Loopdauer eine ganze Zahl Perioden macht."""
    step = 1.0 / DURATION
    return max(step, round(freq / step) * step)


def tone(t: np.ndarray, freq: float, amp: float, phase: float = 0.0) -> np.ndarray:
    return amp * np.sin(2.0 * math.pi * grid(freq) * t + phase)


def swell(t: np.ndarray, rate: float, depth: float, offset: float = 0.0) -> np.ndarray:
    """Langsame Amplitudenmodulation, ebenfalls auf dem Raster."""
    return 1.0 + depth * np.sin(2.0 * math.pi * grid(rate) * t + offset)


def periodic_band(samples: int, low: float, high: float, amp: float,
                  rng: np.random.Generator, tilt: float = 0.0) -> np.ndarray:
    """Geraeuschband, exakt periodisch in der Loopdauer.

    Betragsspektrum im Band setzen (mit optionaler Neigung), Phase zufaellig,
    ruecktransformieren. Weil das Spektrum nur auf Rasterbins sitzt, ist das
    Ergebnis genauso periodisch wie ein einzelner Sinus.
    """
    bins = np.fft.rfftfreq(samples, 1.0 / SAMPLE_RATE)
    magnitude = np.zeros(bins.size)
    inside = (bins >= low) & (bins <= high)
    if not inside.any():
        return np.zeros(samples)
    freqs = bins[inside]
    profile = np.ones(freqs.size)
    if tilt != 0.0:
        # -tilt dB pro Oktave: nimmt dem Band die Schaerfe.
        profile = (freqs / max(low, 1.0)) ** (-tilt / 6.02)
    magnitude[inside] = profile
    phase = rng.uniform(0.0, 2.0 * math.pi, bins.size)
    phase[0] = 0.0
    spectrum = magnitude * np.exp(1j * phase)
    signal = np.fft.irfft(spectrum, samples)
    peak = float(np.max(np.abs(signal)))
    if peak <= 0.0:
        return np.zeros(samples)
    return signal / peak * amp


def verify_seam(signal: np.ndarray, label: str) -> float:
    """Prueft die Nahtstelle: der Sprung darf nicht groesser sein als ein
    normaler Sample-Schritt im Signal."""
    step_seam = abs(signal[0] - signal[-1])
    typical = float(np.median(np.abs(np.diff(signal))))
    ratio = step_seam / max(typical, 1e-9)
    print(f"  Naht {label}: Sprung {step_seam:.6f} bei typischem Schritt "
          f"{typical:.6f} (Faktor {ratio:.2f})")
    if ratio > 4.0:
        raise SystemExit(f"FEHLER: Naht in {label} nicht stetig (Faktor {ratio:.2f})")
    return ratio


def to_int16(signal: np.ndarray) -> bytes:
    peak = float(np.max(np.abs(signal)))
    if peak <= 0.0:
        raise SystemExit("FEHLER: leeres Signal")
    target = 10.0 ** (PEAK_DBFS / 20.0)
    return (signal / peak * target * 32767.0).astype(np.int16).tobytes()


def write_wav(path: Path, pcm: bytes) -> None:
    with wave.open(str(path), "wb") as handle:
        handle.setnchannels(1)
        handle.setsampwidth(2)
        handle.setframerate(SAMPLE_RATE)
        handle.writeframes(pcm)


def encode_ogg(wav_path: Path, ogg_path: Path, quality: int) -> int:
    subprocess.run(
        ["ffmpeg", "-y", "-loglevel", "error", "-i", str(wav_path),
         "-ar", str(OUTPUT_RATE), "-ac", "1",
         "-c:a", "libvorbis", "-q:a", str(quality), str(ogg_path)],
        check=True,
    )
    return ogg_path.stat().st_size


def base_layer(t: np.ndarray, samples: int, rng: np.random.Generator) -> np.ndarray:
    """Grundklang: der Hallraum eines grossen Reaktorschachts.

    Tiefes Fundament, leise Quinte darueber, dazu Luftrauschen wie eine weit
    entfernte Lueftung. Keine Melodie, kein Puls — es soll den Raum
    aufspannen, nicht Musik sein.
    """
    signal = np.zeros(samples)
    # Das erste Bett war zu tief: 86,7 % der Energie lagen unter 60 Hz, und
    # das gibt ein Telefonlautsprecher praktisch nicht wieder — auf dem Geraet
    # waere die Atmosphaere kaum vorhanden gewesen. Der Schwerpunkt liegt
    # deshalb jetzt bei 80-350 Hz, der Tiefbass bleibt nur als Koerper
    # daneben (fuer Kopfhoerer), deutlich leiser.
    #
    # Zwei leicht verstimmte Sinus erzeugen ein Schweben. Die Verstimmung ist
    # bewusst KLEIN (0,3 Hz): darueber entsteht ein Flattern, das unruhig
    # wirkt statt weit.
    # Der Tiefbass bleibt als Koerper fuer Kopfhoerer, aber LEISE: gemessen
    # lagen im zweiten Entwurf noch 11 % unter 60 Hz und 55 % bei 60-120 Hz,
    # und ein Telefonlautsprecher gibt davon fast nichts wieder.
    signal += tone(t, 41.2, 0.07)
    signal += tone(t, 41.2 * 1.008, 0.05, phase=1.1)
    signal += tone(t, 82.4, 0.14, phase=0.3)
    signal += tone(t, 82.4 * 1.004, 0.11, phase=1.7)
    # Ab hier liegt der Klang in dem Bereich, den kleine Lautsprecher
    # tatsaechlich abstrahlen. Das ist der eigentliche Traeger der Atmosphaere.
    signal += tone(t, 123.5, 0.20, phase=0.6) * swell(t, 0.05, 0.35)
    signal += tone(t, 164.8, 0.26, phase=2.2) * swell(t, 0.075, 0.40, 1.0)
    signal += tone(t, 220.0, 0.30, phase=0.9) * swell(t, 0.125, 0.40)
    signal += tone(t, 329.6, 0.26, phase=1.9) * swell(t, 0.175, 0.45, 2.0)
    signal += tone(t, 440.0, 0.16, phase=2.8) * swell(t, 0.1, 0.55, 0.5)
    signal += tone(t, 659.3, 0.09, phase=0.2) * swell(t, 0.137, 0.65, 1.6)
    # Rauschen traegt den Rest: Koerper, Luft, Glanz.
    signal += periodic_band(samples, 150.0, 700.0, 0.14, rng, tilt=1.0) * swell(t, 0.041, 0.30)
    signal += periodic_band(samples, 500.0, 2500.0, 0.11, rng, tilt=2.0) * swell(t, 0.062, 0.40, 0.9)
    signal += periodic_band(samples, 2000.0, 7000.0, 0.035, rng, tilt=4.0) * swell(t, 0.089, 0.50, 1.4)
    return signal


def tension_layer(t: np.ndarray, samples: int, rng: np.random.Generator) -> np.ndarray:
    """Spannungsschicht: schimmert mit der Hoehe auf.

    Hohe, langsam schwebende Toene ohne erkennbare Tonart, dazu ein leises
    Druckrauschen. Wird im Spiel ueber die Hoehenzone eingeblendet, damit der
    Aufstieg nicht nur die Farben aendert.
    """
    signal = np.zeros(samples)
    # Die Verstimmung war 4 Hz und erzeugte damit ein hoerbares Flattern
    # (gemessen: Spitzigkeit im Rhythmusband 688 gegen 66 beim Grundklang).
    # Jetzt 0,35 Hz — das ist langsames Ziehen, kein Zittern.
    signal += tone(t, 660.0, 0.11) * swell(t, 0.083, 0.55)
    signal += tone(t, 660.35, 0.11, phase=2.7) * swell(t, 0.067, 0.55, 1.5)
    signal += tone(t, 495.0, 0.075, phase=0.8) * swell(t, 0.11, 0.60, 0.4)
    signal += tone(t, 990.0, 0.045, phase=0.4) * swell(t, 0.137, 0.65, 1.1)
    # Sehr hoch und sehr leise: Spannung, ohne Aufmerksamkeit zu ziehen.
    signal += tone(t, 2640.0, 0.012, phase=1.3) * swell(t, 0.19, 0.80, 2.2)
    signal += periodic_band(samples, 500.0, 3000.0, 0.035, rng, tilt=4.0) * swell(t, 0.058, 0.55)
    return signal


def set_loop(path: Path) -> None:
    """Schaltet die vorhandene Godot-Importeinstellung auf Endlosschleife.

    Godot importiert neue OGG-Dateien mit `loop=false`. Fuer ein Klangbett ist
    das falsch — und es soll nicht davon abhaengen, dass jemand im Editor einen
    Haken setzt.

    Wichtig: Es wird AUSSCHLIESSLICH die `loop`-Zeile in der bereits von Godot
    erzeugten Datei umgestellt. Ein selbst geschriebenes .import mit erfundener
    uid und erdachtem Importpfad wuerde den Import zerstören. Fehlt die Datei,
    wird das gemeldet statt geraten — dann muss zuerst `godot4 --headless
    --import` laufen.
    """
    sidecar = path.with_suffix(path.suffix + ".import")
    if not sidecar.exists():
        print(f"  Import: {sidecar.name} fehlt — bitte 'godot4 --headless --import' laufen lassen")
        return
    text = sidecar.read_text(encoding="utf-8")
    if "loop=false" not in text and "loop=true" in text:
        print(f"  Import: {sidecar.name} steht bereits auf loop=true")
        return
    if "loop=false" not in text:
        print(f"  Import: {sidecar.name} hat keine loop-Zeile — nicht angeruehrt")
        return
    sidecar.write_text(text.replace("loop=false", "loop=true", 1), encoding="utf-8")
    print(f"  Import: {sidecar.name} auf loop=true gestellt")


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    samples = int(SAMPLE_RATE * DURATION)
    t = np.arange(samples) / SAMPLE_RATE
    rng = np.random.default_rng(SEED)
    print(f"Erzeuge {DURATION:.0f} s bei {SAMPLE_RATE} Hz, Frequenzraster {1.0 / DURATION:.4f} Hz")

    sizes = {}
    for name, builder in [
        ("shaft_ambience", base_layer),
        ("shaft_tension", tension_layer),
    ]:
        signal = builder(t, samples, rng)
        verify_seam(signal, name)
        # Das WAV wird NICHT in assets/ behalten, aber fuer die Nahtpruefung
        # nach /tmp geschrieben: nur so laesst sich trennen, was aus der
        # Synthese kommt und was der Vorbis-Encoder an der Dateigrenze macht.
        wav_path = Path("/tmp/kernwerk-ambience-wav") / f"{name}.wav"
        wav_path.parent.mkdir(parents=True, exist_ok=True)
        ogg_path = OUT_DIR / f"{name}.ogg"
        write_wav(wav_path, to_int16(signal))
        sizes[name] = encode_ogg(wav_path, ogg_path, VORBIS_QUALITY)
        print(f"  {ogg_path.name}: {sizes[name]} B ({sizes[name] / 1024.0:.0f} KiB)")
        set_loop(ogg_path)

    # Die Vorschau ist ein Abnahmewerkzeug, KEIN Spielasset. Im Asset-Ordner
    # wuerde sie mit exportiert (641 KiB, rund 15 % des Pakets) und im
    # Endlosspiel nie abgespielt.
    preview = Path("/tmp/kernwerk-ambience-preview.mp3")
    subprocess.run(
        ["ffmpeg", "-y", "-loglevel", "error",
         "-i", str(OUT_DIR / "shaft_ambience.ogg"),
         "-i", str(OUT_DIR / "shaft_tension.ogg"),
         "-filter_complex",
         # Ab Sekunde 24 kommt die Spannung dazu — so hoert man beide
         # Zustaende in einer Datei.
         "[0:a]volume=1.0[a];[1:a]volume='if(lt(t,24),0,min(1,(t-24)/6))':eval=frame[b];"
         "[a][b]amix=inputs=2:duration=longest:normalize=0[m];"
         "[m]afade=t=in:st=0:d=2,afade=t=out:st=38:d=4[out]",
         "-map", "[out]", "-t", "40", "-b:a", "128k", str(preview)],
        check=True,
    )
    print(f"  Vorschau: {preview.name}: {preview.stat().st_size} B")
    ogg_total = sum(sizes.values())
    print(f"Spielassets gesamt: {ogg_total} B ({ogg_total / 1024.0:.0f} KiB)")


if __name__ == "__main__":
    main()
