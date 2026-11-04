#!/usr/bin/env python3
"""Decide which governed files a playbook review must cover.

Shared by hooks/mr-review.sh (the MR gate) and skills/review_playbook (which
spawns the reviewers), so both apply the same rule.

A changed file is governed by its nearest playbook directory. It needs a review
only when at least one rule file of that playbook covers it:
  * a rule with a `## Scope` section covers the files matching the backticked
    globs in that section, relative to the repo root;
  * a rule with NO `## Scope` section covers every file (older playbooks);
  * a `## Scope` section from which no glob can be parsed fails closed: it covers
    every file and a warning is emitted.
`README.md` and any file whose name starts with `_` are not rules.

Glob semantics: `**` matches any number of path segments (including none),
`*` and `?` match within one segment, a trailing `/` means everything below.

Input (stdin): one `<absolute playbook dir>\\t<repo-relative file>` per line.
Output (stdout): JSON {"required": [...], "skipped": N, "warnings": [...]}.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

SCOPE_HEADING_RE = re.compile(r"^##\s+Scope\s*$", re.I)
ANY_HEADING_RE = re.compile(r"^#{1,6}\s")
BACKTICKED_RE = re.compile(r"`([^`\n]+)`")
# A token is a glob only if it is path-shaped: this drops code quoted in the
# prose after the globs (`#[tool(`, `serde_json::Value`, `a b`).
GLOB_SHAPE_RE = re.compile(r"^[\w.*?/+@~-]+$")


def is_rule(path: Path) -> bool:
    return path.suffix == ".md" and path.name.lower() != "readme.md" and not path.name.startswith("_")


def parse_scope(text: str) -> list[str] | None:
    """Globs of the first `## Scope` section; None when there is no such section."""
    lines = text.splitlines()
    start = next((i for i, ln in enumerate(lines) if SCOPE_HEADING_RE.match(ln.strip())), None)
    if start is None:
        return None
    globs: list[str] = []
    for line in lines[start + 1 :]:
        if ANY_HEADING_RE.match(line):
            break
        globs += [t for t in BACKTICKED_RE.findall(line) if GLOB_SHAPE_RE.match(t)]
    return globs


def glob_to_regex(glob: str) -> re.Pattern[str]:
    glob = glob.removeprefix("./").lstrip("/")
    if glob.endswith("/"):
        glob += "**"
    out: list[str] = []
    i = 0
    while i < len(glob):
        if glob.startswith("**/", i):
            out.append("(?:.*/)?")
            i += 3
        elif glob.startswith("**", i):
            out.append(".*")
            i += 2
        elif glob[i] == "*":
            out.append("[^/]*")
            i += 1
        elif glob[i] == "?":
            out.append("[^/]")
            i += 1
        else:
            out.append(re.escape(glob[i]))
            i += 1
    return re.compile("".join(out) + r"\Z")


class Playbook:
    """Coverage of one playbook directory: match-everything, or a glob list."""

    def __init__(self, directory: Path, warnings: list[str]) -> None:
        self.covers_all = False
        self.patterns: list[re.Pattern[str]] = []
        for rule in sorted(p for p in directory.iterdir() if p.is_file() and is_rule(p)):
            globs = parse_scope(rule.read_text(encoding="utf-8", errors="replace"))
            if globs is None:
                self.covers_all = True
            elif not globs:
                self.covers_all = True
                warnings.append(
                    f"{rule}: `## Scope` has no parseable backticked glob; treated as covering every file"
                )
            else:
                self.patterns += [glob_to_regex(g) for g in globs]

    def covers(self, rel: str) -> bool:
        return self.covers_all or any(p.match(rel) for p in self.patterns)


def select(pairs: list[tuple[str, str]]) -> dict:
    warnings: list[str] = []
    playbooks: dict[str, Playbook] = {}
    required: list[str] = []
    skipped = 0
    for pb_dir, rel in pairs:
        if pb_dir not in playbooks:
            playbooks[pb_dir] = Playbook(Path(pb_dir), warnings)
        if playbooks[pb_dir].covers(rel):
            required.append(rel)
        else:
            skipped += 1
    return {"required": required, "skipped": skipped, "warnings": warnings}


def main() -> int:
    argparse.ArgumentParser(description=__doc__.splitlines()[0]).parse_args()
    pairs = []
    for line in sys.stdin.read().split("\n"):
        if line:
            pb_dir, _, rel = line.partition("\t")
            pairs.append((pb_dir, rel))
    json.dump(select(pairs), sys.stdout)
    return 0


if __name__ == "__main__":
    sys.exit(main())
