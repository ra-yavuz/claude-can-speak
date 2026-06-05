# claude-can-speak

**Let Claude decide what to say out loud.** Most "speak Claude Code aloud" tools
read *every* reply at you. claude-can-speak leads with the opposite: a Claude
Code **skill** that gives the model a deliberate "say this" capability, so Claude
voices only what is worth hearing, a spoken "the build is done and tests passed"
when you have stepped away, a heads-up that a deploy needs confirmation, a short
shoutout you asked for, while everything else stays text-only. Selective, on
purpose, model-controlled.

If you *do* want the firehose, it is one switch away: a Stop hook that speaks
every finished reply, with its own explicit on/off (`claude-can-speak on` /
`off`, off by default). But the deliberate skill is the point.

- **Deliberate mode (the headline)** - the `speak` skill lets Claude choose what
  to voice. Active after `claude-can-speak setup`.
- **Firehose mode (optional)** - a Stop hook speaks every reply when you turn it
  on with `claude-can-speak on` (off by default), or `/ccs on` from inside
  Claude Code.

> **The toggle is a command, not a built-in slash setting.** claude-can-speak
> does not hook into Claude Code's `/voice`; if you type `/` in Claude Code
> before setup and find nothing, that is expected. Control the firehose from the
> terminal with `claude-can-speak on` / `off`, or from inside Claude Code with
> the `/ccs on` / `/ccs off` / `/ccs status` slash command that `setup`
> installs.

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
claude-can-speak setup     # Docker check, build image, install skill + hook
```

`setup` is the one command that does everything (it needs Docker). Then
**restart Claude Code once** so it loads the new skill and hook.

> If `npm install -g` fails with `EACCES` (a system-owned npm prefix like
> `/usr`), either use a user-level prefix once:
> `npm config set prefix ~/.npm-global && export PATH="$HOME/.npm-global/bin:$PATH"`
> (add that `export` to your shell profile), or install with `sudo`.

`setup` also installs a `/ccs` slash command into Claude Code, so the firehose
toggle is reachable from where you would instinctively look for it. **Restart
Claude Code once** after setup so it discovers the skill and the command.

After setup:

- **Deliberate mode** (the headline) is active: Claude can voice notifications
  through the `speak` skill whenever it judges something worth hearing.
- **Firehose mode** (speak every reply) is **off by default**. Turn it on when
  you want it, from the terminal or from inside Claude Code:

```sh
claude-can-speak on      # speak every reply
claude-can-speak off     # back to silent (default)
```

```text
/ccs on        # same, from inside Claude Code
/ccs off
/ccs status
```

Models are downloaded on first use into `~/.cache/claude-can-speak/models`
(nothing model-shaped is bundled in the package; see
[THIRD_PARTY.md](THIRD_PARTY.md)).

Check everything with:

```sh
claude-can-speak status
claude-can-speak test          # speak a sample line
```

If you prefer to do the steps by hand instead of `setup`: `claude-can-speak
build`, then `claude-can-speak install-skill` and/or `claude-can-speak
install-hooks`.

## Usage

```sh
claude-can-speak status            # gate state, container, voice, model cache
claude-can-speak test [text]       # speak a sample (or your text)
claude-can-speak on | off          # firehose: speak every reply, or not (default off)
claude-can-speak say <text>        # speak text now (always speaks; used by the skill)
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
Claude Code reply ─▶ Stop hook (when firehose on) ─▶ strip markdown & code
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

The firehose on/off state is a single file, `~/.config/claude-can-speak/firehose.enabled`
(present = on, absent = off), written by `claude-can-speak on` / `off`. It is
deliberately independent of Claude Code's `/voice`, which is speech-in dictation,
a separate concern. The `speak` skill is toggled via `skillOverrides` in
`~/.claude/settings.json`.

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

## Related projects

Speaking Claude Code's replies aloud is a well-trodden idea, and several tools do
the firehose well: `claude-voice` (Kokoro plus karaoke word highlighting),
`claude-code-tts` (OpenAI or Kokoro auto-speak), `claude-voice-mcp` and
`soliloquy-tts` (MCP-based auto-speak). If all you want is "read every reply
aloud", any of those is a fine choice and lighter than this one (no Docker).

claude-can-speak is built around a different default: the deliberate `speak`
skill, so Claude voices only what is worth hearing rather than everything. It
also adds multilingual output (Piper for German, Turkish, and more) and Docker
isolation so the engines never touch your host Python. The firehose mode is
included, with its own explicit on/off switch, but it is not the headline.

## Licence

MIT - see [LICENSE](LICENSE). Author: Ramazan Yavuz. Part of the public,
open-source projects at [ra-yavuz.github.io](https://ra-yavuz.github.io/).
