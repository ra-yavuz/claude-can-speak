---
name: speak
description: >-
  Speak a short message aloud through the user's speakers using claude-can-speak
  (text-to-speech). Use this for deliberate, selective audio: a spoken
  notification when a long task finishes, a heads-up that needs attention while
  the user is looking away, a brief shoutout or status callout, or when the user
  asks you to say something out loud. This is NOT for reading every reply aloud
  (that is the separate Stop-hook mode); use it only for things genuinely worth
  hearing. Keep spoken text to one or two short sentences.
argument-hint: "[message to speak]"
allowed-tools: Bash(claude-can-speak say *)
---

# Speak aloud

You can send a short message to the user's speakers with the `claude-can-speak`
text-to-speech tool. Use it deliberately, not for everything.

## When to speak

Good uses:
- A finished long-running task the user stepped away from: "The build is done and all tests passed."
- A notification that wants attention now: "Heads up, the deploy needs your confirmation."
- A short status callout or shoutout the user asked for out loud.
- The user explicitly says "tell me out loud", "say this", "read that back", etc.

Do NOT use it to narrate routine replies, read long passages, or speak code,
file paths, commands, or anything awkward to hear. If it is not worth
interrupting the user's ears for, keep it text-only.

## How to speak

Run the CLI with the exact text to say (one or two short sentences, plain
words, no markdown or code):

```
claude-can-speak say "Your short message here."
```

If a message was passed to this skill, speak that:

```
claude-can-speak say "$ARGUMENTS"
```

Notes:
- The user can interrupt playback at any time with `claude-can-speak stop`, or
  simply by sending their next message.
- `say` speaks regardless of /voice mode (it is a deliberate, explicit call),
  whereas the firehose Stop-hook mode only speaks while /voice is on.
- If the command reports the image or container is missing, tell the user to run
  `claude-can-speak build` once, then retry; do not keep retrying silently.
