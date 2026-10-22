"""Master the selected ElevenLabs takes into tiny, quiet, offline UI assets.

Run from the repository root after placing the original MP3s in
build/audio-source/. Requires ffmpeg on PATH; uses only Python's standard library.
"""

import array
import json
import math
from pathlib import Path
import subprocess
import wave


TAKES = {
    "check_in": "dbt17pLbdLIQxLq1EG2Y",
    "progress": "a4lW8eQSzuR4Ha611AUq",
    "milestone": "Ne6qrOhCV3PX26Ks8Er6",
}
RATE = 44100


def db(value):
    return round(20 * math.log10(max(value, 1e-9)), 2)


def main():
    destination = Path("assets/audio")
    destination.mkdir(parents=True, exist_ok=True)
    report = []
    for name, generation in TAKES.items():
        source = Path("build/audio-source") / f"{name}-{generation}.mp3"
        decoded = subprocess.check_output([
            "ffmpeg", "-v", "error", "-i", str(source), "-af",
            "highpass=f=80,lowpass=f=6500,"
            "acompressor=threshold=0.05:ratio=3:attack=1:release=40",
            "-f", "f32le", "-ac", "1", "-ar", str(RATE), "-",
        ])
        samples = array.array("f", decoded)
        # Tiny fades remove start/end clicks, without adding silence or latency.
        for index in range(len(samples)):
            fade = min(1, index / (0.004 * RATE),
                       (len(samples) - 1 - index) / (0.04 * RATE))
            samples[index] *= max(0, fade)
        rms = math.sqrt(sum(value * value for value in samples) / len(samples))
        peak = max(abs(value) for value in samples)
        gain = min(10 ** (-27 / 20) / max(rms, 1e-9),
                   10 ** (-12 / 20) / max(peak, 1e-9))
        pcm = array.array("h", (round(value * gain * 32767) for value in samples))
        target = destination / f"{name}.wav"
        with wave.open(str(target), "wb") as output:
            output.setnchannels(1)
            output.setsampwidth(2)
            output.setframerate(RATE)
            output.writeframes(pcm.tobytes())
        report.append({
            "asset": str(target), "generation_id": generation,
            "duration_seconds": round(len(samples) / RATE, 3),
            "peak_dbfs": db(peak * gain), "rms_dbfs": db(rms * gain),
            "bytes": target.stat().st_size,
        })
    report_path = Path("build/audio-source/mastering-report.json")
    report_path.write_text(json.dumps(report, indent=2), encoding="utf-8")
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
