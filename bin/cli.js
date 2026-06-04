#!/usr/bin/env node
// npm entry point for claude-can-speak. This is a thin cross-platform shim: it
// locates the bundled bash CLI shipped in the package and execs it, passing
// through all arguments. The real logic lives in bin/claude-can-speak (bash),
// shared by the npm install and a direct git checkout.
//
// Bash is required (the CLI drives Docker + audio via shell). On Linux/macOS it
// is present; on Windows use WSL or Git Bash. We fail with a clear message if
// bash cannot be found rather than half-running.
"use strict";

const { spawnSync } = require("node:child_process");
const path = require("node:path");
const fs = require("node:fs");

const cliPath = path.join(__dirname, "claude-can-speak");

if (!fs.existsSync(cliPath)) {
  console.error("claude-can-speak: bundled CLI not found at " + cliPath);
  process.exit(1);
}

// Resolve a bash interpreter. PATH lookup covers Linux/macOS and Git-Bash/WSL
// shims on Windows.
function findBash() {
  const candidates =
    process.platform === "win32"
      ? ["bash.exe", "bash"]
      : ["/bin/bash", "/usr/bin/bash", "bash"];
  for (const c of candidates) {
    const r = spawnSync(c, ["-c", "exit 0"], { stdio: "ignore" });
    if (r.status === 0) return c;
  }
  return null;
}

const bash = findBash();
if (!bash) {
  console.error(
    "claude-can-speak: bash is required but was not found.\n" +
      "Install bash (Linux/macOS have it; on Windows use WSL or Git Bash)."
  );
  process.exit(1);
}

const res = spawnSync(bash, [cliPath, ...process.argv.slice(2)], {
  stdio: "inherit",
});
process.exit(res.status === null ? 1 : res.status);
