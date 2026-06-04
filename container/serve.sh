#!/bin/sh
# Keep the container alive so the host can drive synthesis via `docker exec`.
# Paying Python + onnxruntime import cost once per container (not once per
# reply) is the whole point of the persistent-container design.
echo "[claude-can-speak] tts container ready; awaiting docker exec" >&2
exec tail -f /dev/null
