# claude-can-speak TTS container.
#
# Bundles the two synthesis engines (Piper + Kokoro) and their Python deps,
# but NO model weights: models are fetched on first use into /models, which
# is a host-mounted cache. The image therefore redistributes no third-party
# model files. See ../THIRD_PARTY.md for per-model licences.
FROM python:3.12-slim

# espeak-ng is required by Kokoro's grapheme-to-phoneme stage; harmless for
# Piper (which carries its own phonemization). libsndfile backs soundfile.
RUN apt-get update \
    && apt-get install -y --no-install-recommends espeak-ng libsndfile1 \
    && rm -rf /var/lib/apt/lists/*

# Pinned to keep synthesis reproducible. onnxruntime is the CPU build.
RUN pip install --no-cache-dir \
        piper-tts==1.4.2 \
        kokoro-onnx==0.5.0 \
        soundfile==0.13.1 \
        onnxruntime==1.26.0

ENV CCS_MODELS_DIR=/models
RUN mkdir -p /models
VOLUME ["/models"]

COPY synth.py /app/synth.py
COPY serve.sh /app/serve.sh
RUN chmod +x /app/serve.sh

# The container stays alive doing nothing; the host drives synthesis via
# `docker exec ... python3 /app/synth.py`. This keeps the Python import cost
# (onnxruntime, piper, kokoro) paid once per container, not once per reply.
ENTRYPOINT ["/app/serve.sh"]
