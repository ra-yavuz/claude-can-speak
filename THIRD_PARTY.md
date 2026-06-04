# Third-party components

claude-can-speak is MIT-licensed and ships only its own code: the CLI, the hook
and worker scripts, the `speak` skill, and the container recipe. It bundles **no
third-party model weights**. The TTS models are downloaded on first use, from
their official upstreams, into a local cache (`~/.cache/claude-can-speak/models`)
on your machine. Each model therefore reaches you directly from its own source
under its own licence; this project redistributes none of them.

This keeps the project cleanly MIT and avoids redistributing weights whose terms
differ from ours.

## Engines (installed into the container at build time)

| Component | Licence | Source |
|---|---|---|
| Piper (`piper-tts`) | MIT | https://github.com/OHF-Voice/piper1-gpl |
| Kokoro runtime (`kokoro-onnx`) | MIT | https://github.com/thewh1teagle/kokoro-onnx |
| onnxruntime | MIT | https://github.com/microsoft/onnxruntime |
| soundfile / libsndfile | BSD / LGPL-2.1 | https://github.com/bastibe/python-soundfile |
| espeak-ng | GPL-3.0 | https://github.com/espeak-ng/espeak-ng |

espeak-ng (GPL-3.0) is used inside the container as a grapheme-to-phoneme step.
It is invoked as a separate program at runtime and is not linked into, or
redistributed by, this project; it is installed from the distribution's package
repository when the image is built.

## Models (fetched on first use, not shipped)

| Model | Licence | Source |
|---|---|---|
| Kokoro-82M weights | Apache-2.0 | https://huggingface.co/hexgrad/Kokoro-82M |
| Kokoro ONNX + voices (v1.0) | Apache-2.0 (weights) | https://github.com/thewh1teagle/kokoro-onnx/releases |
| Piper voices (en_US, de_DE, tr_TR, ...) | per-voice (commonly MIT / CC BY 4.0) | https://huggingface.co/rhasspy/piper-voices |

Piper voice licences vary per voice; consult the voice's model card on
`rhasspy/piper-voices` for the exact terms and any attribution requirement. The
default voice (Kokoro `af_heart`) is covered by the Apache-2.0 Kokoro release.

## No warranty

This project, and your use of these third-party components and models, is
provided AS IS with NO WARRANTY. You are responsible for complying with each
component's and model's licence. See LICENSE for the full disclaimer.
