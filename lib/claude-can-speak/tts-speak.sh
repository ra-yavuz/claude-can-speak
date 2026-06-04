#!/usr/bin/env bash
# claude-can-speak: Claude Code Stop hook that speaks each finished reply.
#
# Gated on /voice mode: it reads the same voiceEnabled / voice.enabled flag
# that the built-in /voice (speech-in) toggles, so one switch controls both
# directions. Voice off -> this exits silently and Claude Code stays text-only.
#
# Design contract:
#   - Non-blocking: synthesis + playback run in a detached background job so
#     the hook returns immediately and never delays the next turn.
#   - Fails silent: any error (no docker, no audio, gate off) exits 0 quietly.
#   - Absolute paths only; no reliance on the caller's PATH or cwd.
#
# Provided AS IS, no warranty. See the project README for the full disclaimer.
set -uo pipefail

# --- Resolve config -------------------------------------------------------
CCS_HOME="${CCS_HOME:-$HOME/.config/claude-can-speak}"
CCS_CONFIG="$CCS_HOME/config.env"
CONTAINER="${CCS_CONTAINER:-ccs-tts}"
IMAGE="${CCS_IMAGE:-claude-can-speak:latest}"
MODELS_DIR="${CCS_MODELS_DIR:-$HOME/.cache/claude-can-speak/models}"
LOG="$CCS_HOME/claude-can-speak.log"
PIDFILE="$CCS_HOME/speaking.pid"

# Defaults (overridable via config.env). Chosen from a listening test:
# Kokoro af_heart, US female, is the most natural.
ENGINE="kokoro"
VOICE="af_heart"
LANG="en-us"
SPEED="1.0"
MAX_CHARS="700"

# shellcheck source=/dev/null
[ -f "$CCS_CONFIG" ] && . "$CCS_CONFIG"

mkdir -p "$CCS_HOME" 2>/dev/null || true

log() { printf '%s %s\n' "$(date -Is)" "$*" >>"$LOG" 2>/dev/null || true; }

# --- Tool availability ----------------------------------------------------
command -v docker >/dev/null 2>&1 || { log "no docker; silent"; exit 0; }

PLAYER=""
for p in pw-play paplay aplay; do
  if command -v "$p" >/dev/null 2>&1; then PLAYER="$p"; break; fi
done
[ -n "$PLAYER" ] || { log "no audio player; silent"; exit 0; }

# --- Read the Stop hook payload ------------------------------------------
PAYLOAD="$(cat)"

# --- Gate: only speak when the firehose is explicitly ON ------------------
# claude-can-speak owns its own on/off state, decoupled from Claude Code's
# /voice (which is speech-IN dictation and is not reliably readable here).
# Default is OFF: the state file exists only when the user ran
# `claude-can-speak on`. This guarantees a real, predictable off-switch.
ENABLED_FLAG="${CCS_ENABLED_FLAG:-$CCS_HOME/firehose.enabled}"
[ -f "$ENABLED_FLAG" ] || { log "firehose off; silent"; exit 0; }

# --- Extract the reply text ----------------------------------------------
extract_text() {
  if command -v jq >/dev/null 2>&1; then
    printf '%s' "$PAYLOAD" | jq -r '.last_assistant_message // empty' 2>/dev/null
  else
    # Minimal fallback: pull last_assistant_message with python if present.
    printf '%s' "$PAYLOAD" | python3 -c \
      'import sys,json; print(json.load(sys.stdin).get("last_assistant_message",""))' \
      2>/dev/null
  fi
}
TEXT="$(extract_text)"
[ -n "$TEXT" ] || { log "no last_assistant_message; silent"; exit 0; }

# --- Clean text for speech ------------------------------------------------
# Drop fenced code blocks (unlistenable), strip common markdown, collapse
# whitespace, cap length. Logic lives in clean.py beside this script.
SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLEAN_PY="${CCS_CLEAN_PY:-$SELF_DIR/clean.py}"
[ -f "$CLEAN_PY" ] || { log "clean.py not found at $CLEAN_PY; silent"; exit 0; }
CLEAN="$(printf '%s' "$TEXT" | python3 "$CLEAN_PY" "$MAX_CHARS" 2>>"$LOG")"
[ -n "$CLEAN" ] || { log "empty after cleaning; silent"; exit 0; }

# --- Interrupt any currently-playing reply --------------------------------
# A new reply supersedes the previous one: stop stale playback before we
# start. The same logic backs `claude-can-speak stop`.
stop_current() {
  [ -f "$PIDFILE" ] || return 0
  local pid
  pid="$(cat "$PIDFILE" 2>/dev/null)"
  if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
    # Kill the player and its group so the pipeline dies with it.
    kill -TERM "-$pid" 2>/dev/null || kill -TERM "$pid" 2>/dev/null
  fi
  rm -f "$PIDFILE" 2>/dev/null || true
}

# --- Speak (detached worker) ----------------------------------------------
# A fresh reply interrupts whatever was still being spoken.
stop_current

# Launch the worker in a new session (setsid) so the hook returns immediately
# and the worker is a process-group leader: an interrupt can signal its whole
# group (in-flight synth + player) by the single recorded pid. Config is passed
# through the environment; the cleaned text arrives on the worker's stdin.
SELF_DIR="${SELF_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
WORKER="${CCS_WORKER:-$SELF_DIR/speak-worker.sh}"
[ -f "$WORKER" ] || { log "speak-worker.sh not found at $WORKER; silent"; exit 0; }

printf '%s' "$CLEAN" | \
  CCS_HOME="$CCS_HOME" LOG="$LOG" PIDFILE="$PIDFILE" \
  CONTAINER="$CONTAINER" IMAGE="$IMAGE" MODELS_DIR="$MODELS_DIR" PLAYER="$PLAYER" \
  ENGINE="$ENGINE" VOICE="$VOICE" CCS_LANG="$LANG" SPEED="$SPEED" \
  setsid bash "$WORKER" >/dev/null 2>&1 &
exit 0
