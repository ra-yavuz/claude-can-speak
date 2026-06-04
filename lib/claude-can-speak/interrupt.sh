#!/usr/bin/env bash
# claude-can-speak: UserPromptSubmit hook. When you send your next message,
# stop whatever the previous reply was still speaking. This makes "just start
# typing" the natural interrupt: the moment you move on, the voice goes quiet.
#
# Fails silent, returns immediately.
set -uo pipefail

CCS_HOME="${CCS_HOME:-$HOME/.config/claude-can-speak}"
PIDFILE="$CCS_HOME/speaking.pid"

# Drain stdin (the hook payload) so the caller's pipe never blocks.
cat >/dev/null 2>&1 || true

if [ -f "$PIDFILE" ]; then
  pid="$(cat "$PIDFILE" 2>/dev/null)"
  if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
    kill -TERM "-$pid" 2>/dev/null || kill -TERM "$pid" 2>/dev/null
  fi
  rm -f "$PIDFILE" 2>/dev/null || true
fi
exit 0
