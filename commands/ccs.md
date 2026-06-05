---
description: Control claude-can-speak (status / on / off)
argument-hint: [status|on|off]
allowed-tools: Bash(claude-can-speak:*)
---

The user invoked the claude-can-speak control command with argument: "$ARGUMENTS"

Run the matching CLI command and report the result plainly. The argument is one
of `status` (default if empty), `on`, or `off`:

- empty or `status` -> show current state:
  !`claude-can-speak status`
- `on` -> turn the speak-every-reply firehose on:
  !`if [ "$ARGUMENTS" = "on" ]; then claude-can-speak on; fi`
- `off` -> turn the firehose off (replies go silent again):
  !`if [ "$ARGUMENTS" = "off" ]; then claude-can-speak off; fi`

Note for the user if relevant: `claude-can-speak` is a terminal command too; this
slash command is just a convenience wrapper so the firehose toggle is reachable
from inside Claude Code. The firehose hook hot-reloads, so `on`/`off` take effect
on the next reply without restarting the session.
