#!/usr/bin/env python3
"""Strip markdown and code from a Claude reply so it reads naturally aloud.

Reads text on stdin, writes cleaned text on stdout. argv[1] (optional) is the
maximum character count; longer text is truncated on a sentence boundary so a
long reply does not monologue forever. Fenced code blocks are removed entirely
(they are unlistenable); inline code keeps its contents.
"""
import re
import sys


def clean(text, maxc):
    # Remove fenced code blocks entirely.
    text = re.sub(r"```.*?```", " ", text, flags=re.DOTALL)
    text = re.sub(r"~~~.*?~~~", " ", text, flags=re.DOTALL)
    # Inline code: keep contents, drop backticks.
    text = re.sub(r"`([^`]*)`", r"\1", text)
    # Images / links: keep visible text, drop URL.
    text = re.sub(r"!\[[^\]]*\]\([^)]*\)", " ", text)
    text = re.sub(r"\[([^\]]+)\]\([^)]*\)", r"\1", text)
    # Headings, list bullets, blockquote markers.
    text = re.sub(r"^[ \t]*#{1,6}[ \t]*", "", text, flags=re.MULTILINE)
    text = re.sub(r"^[ \t]*[-*+][ \t]+", "", text, flags=re.MULTILINE)
    text = re.sub(r"^[ \t]*>[ \t]?", "", text, flags=re.MULTILINE)
    # Emphasis markers around a run of text.
    text = re.sub(r"[*_]{1,3}([^*_]+)[*_]{1,3}", r"\1", text)
    # Collapse whitespace.
    text = re.sub(r"\s+", " ", text).strip()
    if maxc and len(text) > maxc:
        cut = text[:maxc]
        m = max(cut.rfind(". "), cut.rfind("! "), cut.rfind("? "))
        text = cut[: m + 1] if m > maxc * 0.5 else cut
    return text


def main():
    maxc = int(sys.argv[1]) if len(sys.argv) > 1 else 700
    sys.stdout.write(clean(sys.stdin.read(), maxc))


if __name__ == "__main__":
    main()
