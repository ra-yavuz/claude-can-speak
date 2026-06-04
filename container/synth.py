#!/usr/bin/env python3
"""claude-can-speak synthesis entrypoint (runs inside the TTS container).

Reads text on stdin, writes a WAV stream on stdout. The engine and voice are
chosen by flags so the host-side hook stays a thin wrapper. Two engines are
supported:

  piper   VITS2, multilingual (English, German, Turkish, ...). The default.
  kokoro  Kokoro-82M, English-family only, higher naturalness.

Models are NOT bundled in the image. They are fetched on first use into
/models (a host-mounted cache) from their official upstreams, so the image
and the .deb redistribute no third-party model weights. See THIRD_PARTY.md
for the per-model licences.

This program prints nothing to stdout except the WAV bytes; all diagnostics
go to stderr so the audio stream stays clean.
"""

import argparse
import os
import sys
import urllib.request

MODELS_DIR = os.environ.get("CCS_MODELS_DIR", "/models")

# Piper voices we know about: slug -> (subpath on rhasspy/piper-voices, lang).
# Verified to resolve (HTTP 200) on huggingface.co/rhasspy/piper-voices.
PIPER_VOICES = {
    "en_US-amy-medium":        "en/en_US/amy/medium/en_US-amy-medium",
    "en_US-lessac-high":       "en/en_US/lessac/high/en_US-lessac-high",
    "en_US-libritts_r-medium": "en/en_US/libritts_r/medium/en_US-libritts_r-medium",
    "en_US-hfc_female-medium": "en/en_US/hfc_female/medium/en_US-hfc_female-medium",
    "en_US-kristin-medium":    "en/en_US/kristin/medium/en_US-kristin-medium",
    "en_GB-jenny_dioco-medium": "en/en_GB/jenny_dioco/medium/en_GB-jenny_dioco-medium",
    "de_DE-thorsten-medium":   "de/de_DE/thorsten/medium/de_DE-thorsten-medium",
    "de_DE-thorsten-high":     "de/de_DE/thorsten/high/de_DE-thorsten-high",
    "tr_TR-dfki-medium":       "tr/tr_TR/dfki/medium/tr_TR-dfki-medium",
}
PIPER_BASE = "https://huggingface.co/rhasspy/piper-voices/resolve/main"

# Kokoro model + voices pack (single combined ONNX + a voices.bin).
KOKORO_MODEL_URL = (
    "https://github.com/thewh1teagle/kokoro-onnx/releases/download/"
    "model-files-v1.0/kokoro-v1.0.onnx"
)
KOKORO_VOICES_URL = (
    "https://github.com/thewh1teagle/kokoro-onnx/releases/download/"
    "model-files-v1.0/voices-v1.0.bin"
)


def log(msg):
    print(f"[claude-can-speak/synth] {msg}", file=sys.stderr, flush=True)


def _download(url, dest):
    """Fetch url to dest atomically. Skips if dest already exists."""
    if os.path.exists(dest) and os.path.getsize(dest) > 0:
        return dest
    os.makedirs(os.path.dirname(dest), exist_ok=True)
    # Unique temp per process so concurrent synths never race on the same
    # .part file (os.replace is atomic, so the last writer wins cleanly).
    tmp = f"{dest}.part.{os.getpid()}"
    log(f"fetching {url}")
    req = urllib.request.Request(url, headers={"User-Agent": "claude-can-speak"})
    try:
        with urllib.request.urlopen(req) as r, open(tmp, "wb") as f:
            while True:
                chunk = r.read(1 << 16)
                if not chunk:
                    break
                f.write(chunk)
        os.replace(tmp, dest)
    finally:
        if os.path.exists(tmp):
            os.unlink(tmp)
    log(f"cached {dest} ({os.path.getsize(dest)} bytes)")
    return dest


def ensure_piper_voice(voice):
    if voice not in PIPER_VOICES:
        raise SystemExit(
            f"unknown piper voice {voice!r}; known: {', '.join(PIPER_VOICES)}"
        )
    subpath = PIPER_VOICES[voice]
    onnx = os.path.join(MODELS_DIR, "piper", voice + ".onnx")
    conf = onnx + ".json"
    _download(f"{PIPER_BASE}/{subpath}.onnx", onnx)
    _download(f"{PIPER_BASE}/{subpath}.onnx.json", conf)
    return onnx


def ensure_kokoro_model():
    model = os.path.join(MODELS_DIR, "kokoro", "kokoro-v1.0.onnx")
    voices = os.path.join(MODELS_DIR, "kokoro", "voices-v1.0.bin")
    _download(KOKORO_MODEL_URL, model)
    _download(KOKORO_VOICES_URL, voices)
    return model, voices


def synth_piper(text, voice, speed, wav_path):
    from piper import PiperVoice, SynthesisConfig  # piper-tts (piper1-gpl)
    import wave

    onnx = ensure_piper_voice(voice)
    v = PiperVoice.load(onnx)
    # length_scale < 1 speeds speech up; invert the user-facing speed factor.
    cfg = SynthesisConfig(length_scale=(1.0 / speed if speed else 1.0))
    with wave.open(wav_path, "wb") as wf:
        v.synthesize_wav(text, wf, syn_config=cfg)


def synth_kokoro(text, voice, lang, speed, wav_path):
    from kokoro_onnx import Kokoro
    import soundfile as sf

    model, voices = ensure_kokoro_model()
    k = Kokoro(model, voices)
    samples, sample_rate = k.create(text, voice=voice, speed=speed, lang=lang)
    sf.write(wav_path, samples, sample_rate, format="WAV", subtype="PCM_16")


def main():
    ap = argparse.ArgumentParser(description="claude-can-speak TTS synth")
    ap.add_argument("--engine", choices=["piper", "kokoro"], default="kokoro")
    ap.add_argument("--voice", default="af_heart")
    ap.add_argument("--lang", default="en-us",
                    help="kokoro language tag (e.g. en-us); ignored by piper")
    ap.add_argument("--speed", type=float, default=1.0)
    ap.add_argument("--text", default=None,
                    help="text to speak; if omitted, read from stdin")
    args = ap.parse_args()

    text = args.text if args.text is not None else sys.stdin.read()
    text = text.strip()
    if not text:
        log("empty text, nothing to synthesize")
        return 0

    # WAV encoders (wave, soundfile) seek back to patch the header size, so
    # they need a seekable target; a stdout pipe is not seekable. Synthesize
    # to a temp file, then stream the bytes to stdout.
    import tempfile

    tmp = tempfile.NamedTemporaryFile(suffix=".wav", delete=False)
    tmp.close()
    try:
        if args.engine == "piper":
            synth_piper(text, args.voice, args.speed, tmp.name)
        else:
            synth_kokoro(text, args.voice, args.lang, args.speed, tmp.name)
        with open(tmp.name, "rb") as f:
            sys.stdout.buffer.write(f.read())
        sys.stdout.buffer.flush()
    except Exception as e:  # fail loud on stderr, silent on stdout
        log(f"synthesis failed: {e}")
        return 1
    finally:
        try:
            os.unlink(tmp.name)
        except OSError:
            pass
    return 0


if __name__ == "__main__":
    sys.exit(main())
