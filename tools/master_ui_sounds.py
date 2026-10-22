"""Render Aura Quest's original, short 'checked and done' UI sounds.

Run from the repository root with Python (standard library only). Build 18
replaces the previous generated plucks with purpose-composed checkbox clicks
and resolved bell tones. No external samples, API keys or runtime network.
ElevenLabs replacement generation was attempted, but blocked by rate limiting.
"""

import array
import json
import math
from pathlib import Path
import random
import sys
import wave


RATE = 44100
TARGET_RMS_DBFS = -23
PEAK_CEILING_DBFS = -9
CUES = {
    "check_in": (0.58, [(0.065, 1046.50, 0.22, 1.0)]),
    "progress": (0.46, [(0.055, 1174.66, 0.15, 0.85)]),
    "milestone": (0.78, [(0.060, 880.00, 0.15, 0.65),
                          (0.205, 1174.66, 0.24, 1.0)]),
}


def db(value):
    return round(20 * math.log10(max(value, 1e-9)), 2)


def render(duration, notes):
    samples = [0.0] * round(duration * RATE)
    noise = random.Random(18022)
    previous_noise = 0.0
    for index in range(len(samples)):
        t = index / RATE
        # A short tactile checkbox snap: low wooden body and a filtered click.
        if t < 0.045:
            current_noise = noise.uniform(-1, 1)
            filtered_noise = (current_noise + previous_noise) * 0.5
            previous_noise = current_noise
            attack = min(1, t / 0.0015)
            samples[index] += attack * (
                0.32 * filtered_noise * math.exp(-t / 0.005)
                + 0.48 * math.sin(2 * math.pi * 340 * t) * math.exp(-t / 0.009)
                + 0.14 * math.sin(2 * math.pi * 1120 * t) * math.exp(-t / 0.006)
            )
        for start, frequency, decay, level in notes:
            nt = t - start
            if nt < 0:
                continue
            # Fast, rounded attack and predominantly harmonic partials give a
            # clear completion ding without a sharp notification-like spike.
            envelope = (1 - math.exp(-nt / 0.0035)) * math.exp(-nt / decay)
            tone = (math.sin(2 * math.pi * frequency * nt)
                    + 0.22 * math.sin(2 * math.pi * frequency * 2 * nt)
                    * math.exp(-nt / 0.10)
                    + 0.08 * math.sin(2 * math.pi * frequency * 3.01 * nt)
                    * math.exp(-nt / 0.055))
            samples[index] += 0.40 * level * envelope * tone
        # End at zero smoothly; do not add latency or a trailing silent pad.
        samples[index] *= min(1, max(0, (duration - t) / 0.055))
    rms = math.sqrt(sum(value * value for value in samples) / len(samples))
    peak = max(abs(value) for value in samples)
    gain = min(10 ** (TARGET_RMS_DBFS / 20) / rms,
               10 ** (PEAK_CEILING_DBFS / 20) / peak)
    pcm = array.array("h", (round(value * gain * 32767) for value in samples))
    if sys.byteorder != "little":
        pcm.byteswap()
    return pcm, db(peak * gain), db(rms * gain)


def main():
    destination = Path("assets/audio")
    destination.mkdir(parents=True, exist_ok=True)
    report = []
    for name, (duration, notes) in CUES.items():
        pcm, peak, rms = render(duration, notes)
        target = destination / f"{name}.wav"
        with wave.open(str(target), "wb") as output:
            output.setnchannels(1)
            output.setsampwidth(2)
            output.setframerate(RATE)
            output.writeframes(pcm.tobytes())
        report.append({
            "asset": str(target), "source": "original procedural composition",
            "duration_seconds": duration, "peak_dbfs": peak, "rms_dbfs": rms,
            "bytes": target.stat().st_size,
        })
    report_path = Path("build/audio-source18/mastering-report.json")
    report_path.parent.mkdir(parents=True, exist_ok=True)
    report_path.write_text(json.dumps(report, indent=2), encoding="utf-8")
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
