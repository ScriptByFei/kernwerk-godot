#!/usr/bin/env python3
"""Prueft, ob das Klangbett das ist, was es sein soll: atmosphaerisch.

"Atmosphaerisch" ist keine Geschmacksfrage, die man nur anhoeren kann — zwei
Eigenschaften davon sind messbar, und beide waren im ersten Entwurf verletzt:

1. HOERBAR AUF DEM GERAET. Ein Telefonlautsprecher gibt tiefen Bass praktisch
   nicht wieder. Der erste Entwurf hatte 86,7 % seiner Energie unter 60 Hz und
   waere auf dem iPhone kaum vorhanden gewesen. Geprueft wird deshalb der
   Anteil im Bereich 100-2500 Hz.

2. KEIN RHYTHMUS. Atmosphaere ist eine Flaeche, kein Puls. Der erste Entwurf
   der Spannungsschicht hatte zwei um 4 Hz verstimmte Toene und damit ein
   hoerbares Flattern. Gemessen wird die "Spitzigkeit" des Modulationsspektrums
   im Rhythmusband 0,5-4 Hz: ein echter Puls erzeugt dort einen spitzen Bin,
   eine ruhige Flaeche nur eine glatte Flanke.

Jede Messung hat eine Gegenprobe, die anschlagen MUSS:
  - Spektrum: ein absichtlich zu tief abgemischter Klang wird rot.
  - Rhythmus: ein aufgesetzter 2-Hz-Puls wird erkannt.
Ohne diese Gegenproben waere nicht belegt, dass die Metrik ueberhaupt trennt.

Aufruf:  python3 tools/verify_ambience_character.py
"""

import subprocess
from pathlib import Path

import numpy as np

SAMPLE_RATE = 22050
AUDIO_DIR = Path("assets/jump/audio")
SPEECH_BAND = (100.0, 2500.0)
MIN_SPEECH_SHARE = 60.0
PULSE_BAND = (0.5, 4.0)
MAX_PEAKINESS = 60.0


def decode(path: Path) -> np.ndarray:
    raw = subprocess.run(
        ["ffmpeg", "-v", "error", "-i", str(path), "-f", "s16le",
         "-acodec", "pcm_s16le", "-ac", "1", "-ar", str(SAMPLE_RATE), "-"],
        check=True, capture_output=True,
    ).stdout
    return np.frombuffer(raw, dtype="<i2").astype(np.float64) / 32768.0


def speech_share(signal: np.ndarray, sample_rate: float = SAMPLE_RATE) -> float:
    """Anteil der Energie im Bereich, den ein Telefonlautsprecher wiedergibt."""
    spectrum = np.abs(np.fft.rfft(signal * np.hanning(signal.size)))
    freqs = np.fft.rfftfreq(signal.size, 1.0 / sample_rate)
    inside = (freqs >= SPEECH_BAND[0]) & (freqs <= SPEECH_BAND[1])
    total = float(np.sum(spectrum ** 2))
    if total <= 0.0:
        return 0.0
    return 100.0 * float(np.sum(spectrum[inside] ** 2)) / total


def peakiness(signal: np.ndarray, smooth_ms: float = 60.0) -> float:
    """Spitzigkeit des Modulationsspektrums im Rhythmusband.

    Huellkurve bilden, Spektrum im Band 0,5-4 Hz, groesster Bin durch den
    Median des Bands. Ein Puls ist ein Ausreisser, eine Flaeche nicht.
    """
    window = int(smooth_ms / 1000.0 * SAMPLE_RATE)
    envelope = np.convolve(np.abs(signal), np.ones(window) / window, mode="same")
    envelope = envelope - envelope.mean()
    spectrum = np.abs(np.fft.rfft(envelope))
    freqs = np.fft.rfftfreq(envelope.size, 1.0 / SAMPLE_RATE)
    band = (freqs >= PULSE_BAND[0]) & (freqs <= PULSE_BAND[1])
    if not band.any():
        return 0.0
    values = spectrum[band]
    return float(values.max() / max(float(np.median(values)), 1e-12))


def analyse(path: Path) -> bool:
    signal = decode(path)
    share = speech_share(signal)
    peak = peakiness(signal)
    print(f"{path.name}")
    print(f"  Energie in {SPEECH_BAND[0]:.0f}-{SPEECH_BAND[1]:.0f} Hz: {share:.1f} % "
          f"(gefordert >= {MIN_SPEECH_SHARE:.0f} %)")
    print(f"  Spitzigkeit im Rhythmusband : {peak:.1f} (erlaubt <= {MAX_PEAKINESS:.0f})")

    # Gegenprobe 1: derselbe Klang, aber alles ueber 80 Hz entfernt — ein
    # reiner Bass. Der MUSS unter die Schwelle fallen, sonst misst die Metrik
    # nicht, was sie behauptet. Zwei Vorgaenger dieser Gegenprobe waren
    # wirkungslos: ein Spektrumbeschnitt ohne Laengenanpassung aenderte das
    # Signal gar nicht, und eine Oktave Verschiebung war fuer dieses Material
    # zu wenig (89,3 % vor wie nach der Verschiebung).
    spectrum = np.fft.rfft(signal)
    freqs = np.fft.rfftfreq(signal.size, 1.0 / SAMPLE_RATE)
    spectrum[freqs > 80.0] = 0.0
    bass_only = np.fft.irfft(spectrum, signal.size)
    low_share = speech_share(bass_only)
    print(f"  Gegenprobe (nur Bass <80 Hz)  : {low_share:.1f} % "
          f"-> {'erkannt' if low_share < MIN_SPEECH_SHARE else 'NICHT ERKANNT'}")

    # Gegenprobe 2: aufgesetzter 2-Hz-Puls -> muss ueber die Schwelle steigen.
    t = np.arange(signal.size) / SAMPLE_RATE
    pulsed = signal * (1.0 + 0.8 * np.sign(np.sin(2.0 * np.pi * 2.0 * t)))
    pulse_peak = peakiness(pulsed)
    print(f"  Gegenprobe (2-Hz-Puls)        : {pulse_peak:.1f} "
          f"-> {'erkannt' if pulse_peak > MAX_PEAKINESS else 'NICHT ERKANNT'}")

    ok = share >= MIN_SPEECH_SHARE and peak <= MAX_PEAKINESS
    print(f"  Urteil: {'OK' if ok else 'ROT'}")
    if low_share >= MIN_SPEECH_SHARE:
        raise SystemExit("FEHLER: Die Spektrumspruefung trennt nicht.")
    if pulse_peak <= MAX_PEAKINESS:
        raise SystemExit("FEHLER: Die Rhythmuspruefung trennt nicht.")
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
        raise SystemExit("FEHLER: mindestens eine Datei erfuellt die Charakterpruefung nicht.")
    print(f"Alle {len(results)} Dateien: Charakter OK.")


if __name__ == "__main__":
    main()
