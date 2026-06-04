#!/usr/bin/env bash
# claude-can-speak speak worker. Launched detached (setsid) by tts-speak.sh as
# a new session leader, so $$ is this worker's process-group id. It records that
# pid IMMEDIATELY - before the multi-second synthesis - so an interrupt issued
# at any point (during synth or during playback) kills the whole group via
# `kill -TERM -$pid`. Cleaned text arrives on stdin; config via the environment.
set -uo pipefail

: "${CCS_HOME:=$HOME/.config/claude-can-speak}"
: "${LOG:=$CCS_HOME/claude-can-speak.log}"
: "${PIDFILE:=$CCS_HOME/speaking.pid}"
: "${CONTAINER:=ccs-tts}"
: "${IMAGE:=claude-can-speak:latest}"
: "${MODELS_DIR:=$HOME/.cache/claude-can-speak/models}"
: "${PLAYER:=pw-play}"
: "${ENGINE:=kokoro}"
: "${VOICE:=af_heart}"
: "${CCS_LANG:=en-us}"
: "${SPEED:=1.0}"

log() { printf '%s %s\n' "$(date -Is)" "$*" >>"$LOG" 2>/dev/null || true; }

# Record our group id up front so we are interruptible during synthesis.
printf '%s' "$$" >"$PIDFILE" 2>/dev/null || true
# If we are signalled, drop the pidfile on the way out.
trap 'rm -f "$PIDFILE" 2>/dev/null; exit 0' TERM INT

ensure_container() {
  if docker inspect -f '{{.State.Running}}' "$CONTAINER" 2>/dev/null | grep -q true; then
    return 0
  fi
  docker rm -f "$CONTAINER" >/dev/null 2>&1 || true
  docker image inspect "$IMAGE" >/dev/null 2>&1 || { log "image $IMAGE missing"; return 1; }
  mkdir -p "$MODELS_DIR" 2>/dev/null || true
  docker run -d --name "$CONTAINER" -v "$MODELS_DIR:/models" "$IMAGE" >/dev/null 2>&1 \
    || { log "container start failed"; return 1; }
  log "started container $CONTAINER"
}

CLEAN="$(cat)"
[ -n "$CLEAN" ] || { rm -f "$PIDFILE" 2>/dev/null; exit 0; }

ensure_container || { rm -f "$PIDFILE" 2>/dev/null; exit 0; }

wav="$(mktemp --suffix=.wav 2>/dev/null)" || { rm -f "$PIDFILE" 2>/dev/null; exit 0; }
if printf '%s' "$CLEAN" | docker exec -i "$CONTAINER" \
      python3 /app/synth.py \
        --engine "$ENGINE" --voice "$VOICE" --lang "$CCS_LANG" --speed "$SPEED" \
      >"$wav" 2>>"$LOG" && [ -s "$wav" ]; then
  "$PLAYER" "$wav" >/dev/null 2>&1
else
  log "synthesis produced no audio (engine=$ENGINE voice=$VOICE)"
fi
rm -f "$wav" 2>/dev/null || true

# Clear the pidfile only if it still points at us (a newer reply may have
# replaced it while we were speaking).
[ "$(cat "$PIDFILE" 2>/dev/null)" = "$$" ] && rm -f "$PIDFILE" 2>/dev/null
exit 0
