#!/usr/bin/env node
// Printed once after `npm install -g claude-can-speak`. Deliberately does NO
// heavy or side-effecting work (no docker build, no editing ~/.claude): it only
// tells the user the single next command. The real setup is explicit and
// user-chosen, which keeps `npm install` fast, quiet, and unsurprising.
"use strict";

// Skip the banner in CI / non-interactive installs to avoid log noise.
if (process.env.CI || process.env.npm_config_loglevel === "silent") process.exit(0);

const L = [
  "",
  "  claude-can-speak installed.",
  "",
  "  One more step (needs Docker):",
  "      claude-can-speak setup",
  "",
  "  That builds the local TTS container and installs the 'speak' skill",
  "  plus the optional firehose hook. Then restart Claude Code once.",
  "",
  "  Deliberate mode (Claude voices notifications) is on after setup.",
  "  Firehose mode (speak every reply) is off by default; turn it on with:",
  "      claude-can-speak on",
  "",
  "  Provided AS IS, no warranty. https://ra-yavuz.github.io/claude-can-speak/",
  "",
];
process.stdout.write(L.join("\n") + "\n");
