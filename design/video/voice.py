"""Speaks the film's narration and times the film to it.

Reads narration.json, speaks every line with Kokoro (an open text-to-speech
model, run on this machine), and from the length of each spoken line works
out when every scene starts and ends. Writes:

    design/video/timeline.js      scene and cue times, read by moment.html
    site/media/moment.vtt         captions
    build/film/soundtrack.wav     the narration over a quiet bed of chords

Run from the repository root, then render the pictures:

    python3 design/video/voice.py
    node design/video/render.cjs

Needs `pip install kokoro-onnx soundfile numpy` and ffmpeg. The voice model
(about 350 MB) is downloaded once to ~/.cache/moment-film/; it is not part
of the repository. The narration is a synthetic voice.
"""

import json
import subprocess
import urllib.request
from pathlib import Path

import numpy as np
import soundfile as sf
from kokoro_onnx import Kokoro

HERE = Path(__file__).parent
BUILD = Path("build/film")
CACHE = Path.home() / ".cache" / "moment-film"
MODEL_URL = "https://github.com/thewh1teagle/kokoro-onnx/releases/download/model-files-v1.0/"

LEAD = 0.7   # a scene is on screen this long before anyone speaks
GAP = 0.32   # between two lines of the same scene
TAIL = 0.8   # and this long after the last word
CUE_AHEAD = 0.12  # a cued line appears just before it is spoken

RATE = 48000


def model(name):
    CACHE.mkdir(parents=True, exist_ok=True)
    path = CACHE / name
    if not path.exists():
        print("downloading", name)
        urllib.request.urlretrieve(MODEL_URL + name, path)
    return str(path)


def trim(samples, rate, floor=0.004):
    """Drops the silence the model leaves before and after a line."""
    loud = np.flatnonzero(np.abs(samples) > floor)
    if loud.size == 0:
        return samples
    pad = int(0.03 * rate)
    return samples[max(loud[0] - pad, 0) : loud[-1] + pad]


def speak(script):
    """Speaks every line; returns the timeline and the voice track."""
    kokoro = Kokoro(model("kokoro-v1.0.onnx"), model("voices-v1.0.bin"))
    scenes, clips, captions = [], [], []
    clock = 0.0
    rate = None
    for scene in script["scenes"]:
        start = clock
        at = start + scene.get("lead", LEAD)
        cues = {}
        for i, line in enumerate(scene["lines"]):
            if i > 0:
                at += line.get("gap", GAP)
            samples, rate = kokoro.create(
                line["say"], voice=script["voice"], speed=script["speed"], lang="en-us"
            )
            samples = trim(samples, rate)
            length = len(samples) / rate
            clips.append((at, samples))
            captions.append((at, at + length, line["say"]))
            if "cue" in line:
                cues[line["cue"]] = round(at - start - CUE_AHEAD, 2)
            at += length
        end = max(start + scene["least"], at + scene.get("tail", TAIL))
        scenes.append({"id": scene["id"], "start": round(start, 2), "end": round(end, 2), "cues": cues})
        clock = end

    total = round(clock, 2)
    voice = np.zeros(int(total * rate) + rate, dtype=np.float32)
    for at, samples in clips:
        offset = int(at * rate)
        voice[offset : offset + len(samples)] += samples
    return {"total": total, "scenes": scenes}, voice, rate, captions


def bed(total):
    """A quiet bed of slow chords: soft sine tones, nothing that competes
    with a voice. Four chords, each held about seven seconds and melting
    into the next."""
    chords = [
        [174.61, 220.00, 261.63, 329.63],  # F major 7
        [110.00, 164.81, 196.00, 261.63],  # A minor 7
        [130.81, 196.00, 246.94, 329.63],  # C major 7
        [98.00, 146.83, 246.94, 293.66],   # G major
    ]
    hold, fade = 7.0, 2.4
    length = int((total + 2) * RATE)
    t = np.arange(length) / RATE
    left = np.zeros(length)
    right = np.zeros(length)
    for i in range(int(total / hold) + 2):
        begin = i * hold
        # Each chord swells in, holds, and fades as the next arrives.
        envelope = np.clip((t - begin + fade) / fade, 0, 1) * np.clip((begin + hold + fade - t) / fade, 0, 1)
        envelope = np.sin(envelope * np.pi / 2) ** 2
        for n, pitch in enumerate(chords[i % len(chords)]):
            weight = 1.0 / (1 + n * 0.35)
            # Two voices a breath apart in pitch, one each side, for width.
            left += envelope * weight * (np.sin(2 * np.pi * pitch * 0.9985 * t) + 0.18 * np.sin(2 * np.pi * pitch * 2 * t))
            right += envelope * weight * (np.sin(2 * np.pi * pitch * 1.0015 * t) + 0.18 * np.sin(2 * np.pi * pitch * 2 * t))
    stereo = np.stack([left, right], axis=1)
    stereo /= np.abs(stereo).max()
    # In gently at the start, out over the last two seconds of the film.
    swell = np.clip(t / 2.5, 0, 1) * np.clip((total - t) / 2.0, 0, 1)
    return (stereo * swell[:, None] * 0.5).astype(np.float32)


def stamp(seconds):
    minutes, rest = divmod(seconds, 60)
    return f"00:{int(minutes):02d}:{rest:06.3f}"


def main():
    script = json.loads((HERE / "narration.json").read_text())
    timeline, voice, rate, captions = speak(script)
    BUILD.mkdir(parents=True, exist_ok=True)

    (HERE / "timeline.js").write_text(
        "// Written by voice.py from the length of each spoken line. Do not edit.\n"
        f"window.MOMENT_TIMELINE = {json.dumps(timeline, indent=2)};\n"
    )
    vtt = ["WEBVTT", ""]
    for begin, end, text in captions:
        vtt += [f"{stamp(begin)} --> {stamp(end + 0.15)}", text, ""]
    Path("site/media").mkdir(parents=True, exist_ok=True)
    Path("site/media/moment.vtt").write_text("\n".join(vtt))

    sf.write(BUILD / "voice.wav", voice, rate)
    sf.write(BUILD / "bed.wav", bed(timeline["total"]), RATE)
    # The bed sits well under the voice and dips further while it speaks;
    # the whole is levelled to a normal loudness for online video.
    subprocess.run(
        [
            "ffmpeg", "-y", "-loglevel", "error",
            "-i", str(BUILD / "voice.wav"), "-i", str(BUILD / "bed.wav"),
            "-filter_complex",
            f"[0:a]aresample={RATE},pan=stereo|c0=c0|c1=c0,asplit=2[say][key];"
            "[1:a]volume=-19dB[low];"
            "[low][key]sidechaincompress=threshold=0.02:ratio=5:attack=120:release=900[under];"
            "[say][under]amix=inputs=2:normalize=0,"
            "loudnorm=I=-16:TP=-1.5:LRA=11,"
            f"atrim=0:{timeline['total']}[out]",
            "-map", "[out]", "-ar", str(RATE), str(BUILD / "soundtrack.wav"),
        ],
        check=True,
    )
    for scene in timeline["scenes"]:
        print(f"{scene['id']:9} {scene['start']:6.2f} to {scene['end']:6.2f}  {scene['cues'] or ''}")
    print("total", timeline["total"], "seconds")


if __name__ == "__main__":
    main()
