# claude-can-speak

**Now Claude Code talks back.** Speech-out for Claude Code: a companion to the
built-in `/voice` speech-in. Turn `/voice` on and Claude can read its replies
aloud through your speakers; turn it off and you are back to silent, text-only.
Two ways to use it, a local neural voice, nothing sent to the cloud.

- **Firehose mode** - a Stop hook speaks every finished reply while `/voice` is
  on. One switch (`/voice`) controls both directions: you talk to it, it talks
  back.
- **Deliberate mode** - a `speak` skill lets Claude choose what to voice: a
  spoken "the build is done", a heads-up while you are looking away, a shoutout.
  Selective, on purpose, not a firehose.

Speech is synthesised locally by [Kokoro](https://github.com/thewh1teagle/kokoro-onnx)
(natural English, the default) or [Piper](https://github.com/OHF-Voice/piper1-gpl)
(multilingual: English, German, Turkish, and more), running in a Docker
container so they never touch your host Python environment. No API keys, no
network at speak time, no telemetry.

## Requirements

- **Claude Code** (this is an extension for it).
- **Node.js >= 16 / npm** (to install the CLI).
- **Docker** (the TTS engines run in a container). The CLI checks for it and
  tells you how to install it if it is missing.
- **An audio player**: `pw-play` (PipeWire), `paplay` (PulseAudio), or `aplay`
  (ALSA) on Linux. (macOS/Windows playback support is on the roadmap.)

## Install

```sh
npm install -g claude-can-speak

# one-time: build the local TTS container image (needs Docker)
claude-can-speak build
```

> If `npm install -g` fails with `EACCES` (a system-owned npm prefix like
> `/usr`), either use a user-level prefix once:
> `npm config set prefix ~/.npm-global && export PATH="$HOME/.npm-global/bin:$PATH"`
> (add that `export` to your shell profile), or install with `sudo`.

Then pick the mode(s) you want:

```sh
claude-can-speak install-skill    # deliberate mode: the 'speak' skill
claude-can-speak install-hooks    # firehose mode: speak every reply on /voice
```

Models are downloaded on first use into `~/.cache/claude-can-speak/models`
(nothing model-shaped is bundled in the package; see
[THIRD_PARTY.md](THIRD_PARTY.md)).

Then in Claude Code, toggle `/voice` on. Check everything with:

```sh
claude-can-speak status
claude-can-speak test          # speak a sample line
```

## Usage

```sh
claude-can-speak status            # gate state, container, voice, model cache
claude-can-speak test [text]       # speak a sample (or your text)
claude-can-speak say <text>        # speak text now (ignores the /voice gate)
claude-can-speak stop              # interrupt whatever is being spoken
claude-can-speak voice <name>      # set the default voice (e.g. af_heart)
claude-can-speak engine kokoro|piper
claude-can-speak voices            # list voices for the current engine
claude-can-speak skill on|off      # enable/disable the 'speak' skill
claude-can-speak install-hooks | remove-hooks
claude-can-speak install-skill
claude-can-speak build             # (re)build the TTS container image
```

### Interrupting

You can stop playback three ways: run `claude-can-speak stop`, just send your
next message (a `UserPromptSubmit` hook stops the previous reply), or let a new
reply supersede the old one. Interrupts kill both in-flight synthesis and active
playback.

### Choosing a voice

The default is Kokoro `af_heart` (natural US English, female). List options with
`claude-can-speak voices`. For German or Turkish, switch to Piper:

```sh
claude-can-speak engine piper
claude-can-speak voice de_DE-thorsten-high   # German
claude-can-speak voice tr_TR-dfki-medium     # Turkish
```

## How it works

```
Claude Code reply ─▶ Stop hook (gated on /voice) ─▶ strip markdown & code
                                                   ─▶ docker exec synth (Kokoro/Piper)
                                                   ─▶ play WAV on the host
```

The container is persistent: it starts once and stays warm, so the Python and
ONNX import cost is paid once, not per reply. Only audio crosses back to the
host. The `speak` skill drives the same pipeline through `claude-can-speak say`,
but only when Claude (or you) chooses to speak.

## Configuration

Per-user config lives in `~/.config/claude-can-speak/config.env` (written by the
`voice` / `engine` commands). Environment overrides: `CCS_IMAGE`,
`CCS_CONTAINER`, `CCS_MODELS_DIR`, `CLAUDE_SETTINGS`.

The `/voice` gate is read from `~/.claude/settings.json` (`voiceEnabled` or
`voice.enabled`). The `speak` skill is toggled via `skillOverrides` there.

## Uninstall

```sh
claude-can-speak remove-hooks
claude-can-speak skill off
claude-can-speak stop-container
npm uninstall -g claude-can-speak
rm -rf ~/.config/claude-can-speak ~/.claude/skills/speak
# optional: reclaim the model cache and image
rm -rf ~/.cache/claude-can-speak
docker image rm claude-can-speak:latest
```

## Disclaimer

This software is provided **AS IS, with NO WARRANTY** of any kind, express or
implied. The author is not liable for any damage, data loss, or other harm
arising from its use. It runs background processes, plays audio, builds and runs
a Docker container, and downloads third-party models from the internet on your
behalf. **By installing and using it you accept all risk.** You are responsible
for complying with the licences of the bundled engines and the downloaded models
(see [THIRD_PARTY.md](THIRD_PARTY.md)).

## Licence

MIT - see [LICENSE](LICENSE). Author: Ramazan Yavuz. Part of the public,
open-source projects at [ra-yavuz.github.io](https://ra-yavuz.github.io/).
