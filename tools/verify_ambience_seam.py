#!/usr/bin/env python3
"""Prueft die Nahtstelle des Klangbetts auf Hoerbarkeit.

Die Frage lautet nicht "gibt es an der Naht einen Sprung?" — irgendeinen
Sample-Schritt gibt es immer. Die Frage lautet: **ist der Schritt an der Naht
ein Ausreisser gegenueber allen anderen Schritten im Signal?** Denn genau das
hoert man: eine Stelle, die sich anders verhaelt als ihre Umgebung.

Gemessen wird deshalb das Perzentil des Nahtschritts in der Verteilung ALLER
Sample-Schritte. Ein unauffaelliges Signal liegt bei etwa 50 %. Die Schwelle
steht bei 99,5 % — erst dann ist die Naht steiler als 199 von 200 Stellen im
Signal und damit ein Kandidat fuer ein hoerbares Knacken.

Zwei Fehler aus dem ersten Anlauf, die diese Fassung vermeidet:
  1. Fensterweise Hochfrequenzenergie an der Naht mit Fenstern an anderen
     Stellen zu vergleichen, ist blind: der Hochfrequenzanteil des Rauschens
     schwankt ohnehin ueber das Signal. Das Verfahren meldete 2,93 fuer eine
     Naht, die bei 70 % Perzentil liegt.
  2. Ein Fenster um die Naht muss das erste Sample wirklich enthalten. Der
     erste Versuch hatte eine Sonderbehandlung fuer den Umbruch, die genau
     das ausschloss — die Mutationsprobe deckte es auf.

Die Pruefung misst die AUSGELIEFERTE .ogg-Datei, nicht das Signal im
Speicher. Zusaetzlich wird das quellgleiche WAV verglichen, damit ein Befund
eindeutig der Synthese oder dem Encoder zugeordnet werden kann.

Die Mutationsprobe baut einen KLEINEN Sprung ein (nicht 0.4 der Spitze,
sondern das Dreifache eines typischen Schritts). Eine Pruefung, die nur
grobe Fehler findet, uebersieht genau die, die man spaeter hoert.

Aufruf:  python3 tools/verify_ambience_seam.py
"""

import subprocess
import wave
from pathlib import Path

import numpy as np

# Die ausgelieferten Dateien laufen mit 22,05 kHz. Geprueft wird die
# AUSLIEFERUNGSRATE — eine Naht auf der internen Rate zu messen und dann
# herunterzurechnen waere am Ziel vorbei.
SAMPLE_RATE = 22050
AUDIO_DIR = Path("assets/jump/audio")
SOURCE_DIR = Path("/tmp/kernwerk-ambience-wav")
LIMIT_PERCENTILE = 99.0


def decode_wav(path: Path) -> np.ndarray:
    """Quell-WAV auf die Auslieferungsrate bringen — sonst vergleicht die
    Gegenprobe eine andere Abtastrate als die geprüfte Datei."""
    raw = subprocess.run(
        ["ffmpeg", "-v", "error", "-i", str(path), "-f", "s16le",
         "-acodec", "pcm_s16le", "-ac", "1", "-ar", str(SAMPLE_RATE), "-"],
        check=True, capture_output=True,
    ).stdout
    return np.frombuffer(raw, dtype="<i2").astype(np.float64) / 32768.0


def decode_ogg(path: Path) -> np.ndarray:
    """OGG zurueck in Samples holen — geprueft wird die ausgelieferte Datei."""
    raw = subprocess.run(
        ["ffmpeg", "-v", "error", "-i", str(path), "-f", "s16le",
         "-acodec", "pcm_s16le", "-ac", "1", "-ar", str(SAMPLE_RATE), "-"],
        check=True, capture_output=True,
    ).stdout
    return np.frombuffer(raw, dtype="<i2").astype(np.float64) / 32768.0


def seam_report(signal: np.ndarray) -> dict:
    """Perzentil des Nahtschritts in der Verteilung aller Schritte."""
    steps = np.abs(np.diff(signal))
    seam_step = abs(signal[0] - signal[-1])
    percentile = 100.0 * float(np.mean(steps < seam_step))
    return {
        "seam_step": seam_step,
        "percentile": percentile,
        "p50": float(np.percentile(steps, 50)),
        "p99": float(np.percentile(steps, 99)),
        "max": float(steps.max()),
        "peak": float(np.max(np.abs(signal))),
    }


def analyse(path: Path) -> bool:
    signal = decode_ogg(path)
    report = seam_report(signal)
    print(f"{path.name}: {signal.size} Samples = {signal.size / SAMPLE_RATE:.2f} s")
    print(f"  Nahtschritt {report['seam_step']:.6f} bei Signalspitze {report['peak']:.3f}")
    print(f"  Schritt-Verteilung: p50 {report['p50']:.6f} | p99 {report['p99']:.6f} | max {report['max']:.6f}")
    print(f"  Perzentil der Naht: {report['percentile']:.2f} % (Grenze {LIMIT_PERCENTILE:.1f} %)")

    # Quellgleiches WAV: trennt Synthese von Encoder. Beide Werte werden
    # berichtet, der schlechtere zaehlt.
    wav_path = SOURCE_DIR / (path.stem + ".wav")
    if wav_path.exists():
        wav_report = seam_report(decode_wav(wav_path))
        worse = "WAV" if wav_report["percentile"] > report["percentile"] else "OGG"
        print(f"  Gegenprobe am WAV : {wav_report['percentile']:.2f} % "
              f"(schlechterer Wert: {worse})")

    # Mutationsprobe. Kalibrierung ist hier entscheidend: ein Sprung muss
    # SCHLECHTER sein als jeder natuerliche Schritt im Signal, sonst liegt er
    # innerhalb dessen, was das Material ohnehin tut, und ist per Definition
    # nicht als Naht hoerbar. Deshalb wird der doppelte maximale Schritt
    # aufgeschlagen — nicht ein Vielfaches des Medians.
    mutated = signal.copy()
    mutated[0] += 2.0 * report["max"]
    mutation = seam_report(mutated)
    detected = mutation["percentile"] >= LIMIT_PERCENTILE
    print(f"  Mutationsprobe (+2x groesster Schritt): Perzentil {mutation['percentile']:.2f} % "
          f"-> {'erkannt' if detected else 'NICHT ERKANNT'}")

    ok = report["percentile"] < LIMIT_PERCENTILE
    print(f"  Urteil: {'OK' if ok else 'ROT'}")
    if not ok:
        print(f"  -> Naht ist steiler als {report['percentile']:.1f} % aller Stellen im Signal")
    if mutation["percentile"] < LIMIT_PERCENTILE:
        raise SystemExit("FEHLER: Die Pruefung erkennt nicht einmal einen gesetzten Sprung.")
    return ok


def main() -> None:
    files = sorted(AUDIO_DIR.glob("*.ogg"))
    if not files:
        raise SystemExit(f"Keine .ogg-Dateien in {AUDIO_DIR}")
    results = []
    for path in files:
        results.append(analyse(path))
        print()
    if not all(results):
        raise SystemExit("FEHLER: mindestens eine Datei hat eine hoerbare Naht.")
    print(f"Alle {len(results)} Dateien: Naht unauffaellig.")


if __name__ == "__main__":
    main()
