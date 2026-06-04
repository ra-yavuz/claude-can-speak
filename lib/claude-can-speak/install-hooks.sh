#!/usr/bin/env bash
# claude-can-speak: register (or remove) the Stop + UserPromptSubmit hooks in
# the user's Claude Code settings.json, merging into any existing hooks rather
# than overwriting them. Idempotent.
set -uo pipefail

SETTINGS_JSON="${CLAUDE_SETTINGS:-$HOME/.claude/settings.json}"

# Resolve where the installed hook scripts live (deb vs git checkout).
SELF="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "/usr/lib/claude-can-speak/tts-speak.sh" ]; then
  HOOKDIR="/usr/lib/claude-can-speak"
else
  HOOKDIR="$SELF"
fi
SPEAK_HOOK="$HOOKDIR/tts-speak.sh"
INTERRUPT_HOOK="$HOOKDIR/interrupt.sh"

action="${1:-install}"

[ -f "$SETTINGS_JSON" ] || { mkdir -p "$(dirname "$SETTINGS_JSON")"; echo '{}' >"$SETTINGS_JSON"; }

python3 - "$SETTINGS_JSON" "$action" "$SPEAK_HOOK" "$INTERRUPT_HOOK" <<'PY'
import json, sys, os, shutil

path, action, speak_hook, interrupt_hook = sys.argv[1:5]

with open(path) as f:
    cfg = json.load(f)

hooks = cfg.setdefault("hooks", {})

MARK = "tts-speak.sh"            # how we recognise our Stop hook
IMARK = "interrupt.sh"          # how we recognise our UserPromptSubmit hook

def groups(event):
    return hooks.setdefault(event, [])

def strip(event, needle):
    """Remove any hook entry whose command mentions needle."""
    kept = []
    for group in hooks.get(event, []):
        group_hooks = [h for h in group.get("hooks", [])
                       if needle not in str(h.get("command", ""))]
        if group_hooks:
            group = dict(group); group["hooks"] = group_hooks
            kept.append(group)
    if kept:
        hooks[event] = kept
    elif event in hooks:
        del hooks[event]

# Always strip our previous entries first so the operation is idempotent.
strip("Stop", MARK)
strip("UserPromptSubmit", IMARK)

if action == "install":
    groups("Stop").append({
        "hooks": [{"type": "command", "command": speak_hook, "timeout": 15}]
    })
    groups("UserPromptSubmit").append({
        "hooks": [{"type": "command", "command": interrupt_hook, "timeout": 5}]
    })
elif action == "remove":
    pass
else:
    sys.stderr.write("action must be install or remove\n")
    sys.exit(2)

# Back up once, then write atomically.
if not os.path.exists(path + ".ccs-bak"):
    shutil.copy2(path, path + ".ccs-bak")
tmp = path + ".tmp"
with open(tmp, "w") as f:
    json.dump(cfg, f, indent=2)
    f.write("\n")
os.replace(tmp, path)
print(f"{action}ed claude-can-speak hooks in {path}")
PY

if [ "$action" = install ]; then
  echo "Stop hook       -> $SPEAK_HOOK"
  echo "UserPromptSubmit -> $INTERRUPT_HOOK"
  echo "Note: Claude Code loads hooks at session start; restart your session to activate."
fi
