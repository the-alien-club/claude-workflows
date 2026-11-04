#!/usr/bin/env python3
"""Verify from the session transcript that the playbook review really ran.

Called by mr-review.sh once it has decided a review is required. Exit status:
  0  every governed changed file was covered by a clean playbook-reviewer run
  1  not verified; stdout holds the message for the model
Any other status (crash) is treated as "not verified" by the caller.

Transcript facts this relies on (checked against real Claude Code JSONL):
  * a reviewer call is an assistant `tool_use` named Agent/Task whose
    `input.subagent_type` is `playbook-reviewer` or `<plugin>:playbook-reviewer`;
  * foreground: the `tool_result` carries the report;
  * background: the `tool_result` is an "Async agent launched ... agentId: X"
    ack, and the report arrives later as `<agent-message from="X">` (newer
    harness) or inline in the `<task-notification>` `<result>` (older);
  * either way the report is the harness-indented block after
    "The report follows:", and a clean review is exactly "No violations found."
    (agents/playbook-reviewer.md).
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path
from typing import Iterator

REVIEWER_NAME = "playbook-reviewer"
AGENT_TOOL_NAMES = {"Agent", "Task"}
CLEAN_REPORT = "No violations found."

REPORT_MARKER = "The report follows:\n"
AGENT_MESSAGE_RE = re.compile(r'<agent-message from="([^"]+)">(.*?)</agent-message>', re.S)
TOOL_USE_ID_RE = re.compile(r'"tool_use_id"\s*:\s*"([^"]+)"')
AGENT_ID_RE = re.compile(r"^agentId:\s*(\w+)", re.M)
NOTIFICATION_RE = re.compile(r"<task-notification>(.*?)</task-notification>", re.S)
TASK_ID_RE = re.compile(r"<task-id>([^<]+)</task-id>")
TOOL_USE_REF_RE = re.compile(r"<tool-use-id>([^<]+)</tool-use-id>")
RESULT_RE = re.compile(r"<result>(.*?)</result>", re.S)
# Newer harnesses put a pointer here and deliver the report as an agent-message.
DELIVERED_ELSEWHERE = "This agent's report was delivered"
# Record types that can never carry a harness-delivered result.
IGNORED_RECORD_TYPES = {"assistant", "api-request-blob"}


class VerificationError(Exception):
    """The transcript cannot support a verdict; the gate must deny."""


@dataclass
class Reviewer:
    tool_use_id: str
    description: str
    prompt: str
    started: float
    agent_id: str | None = None
    report: str | None = None  # None until a result arrives
    errored: bool = False

    @property
    def pending(self) -> bool:
        return self.report is None and not self.errored

    @property
    def clean(self) -> bool:
        return self.report is not None and not self.errored and is_clean(self.report)

    @property
    def label(self) -> str:
        return self.description or self.tool_use_id


def is_clean(report: str) -> bool:
    lines = [ln.rstrip() for ln in report.strip().splitlines()]
    while lines and lines[0].startswith("```"):
        lines.pop(0)
    while lines and lines[-1].startswith("```"):
        lines.pop()
    return "\n".join(lines).strip() == CLEAN_REPORT


def extract_report(text: str) -> str:
    """Report body from a hand-back frame or a raw tool result."""
    start = text.find(REPORT_MARKER)
    if start >= 0:
        body: list[str] = []
        for line in text[start + len(REPORT_MARKER):].split("\n"):
            if line.startswith("  "):
                body.append(line[2:])
            elif not line.strip():
                body.append("")
            else:
                break  # agentId:/<usage>: trailer, or a forged unindented line
        return "\n".join(body).strip()
    body = []
    for line in text.split("\n"):
        if line.startswith(("agentId:", "<usage>")):
            break
        body.append(line)
    return "\n".join(body).strip()


def to_epoch(stamp: object) -> float | None:
    if not isinstance(stamp, str):
        return None
    try:
        return datetime.fromisoformat(stamp.replace("Z", "+00:00")).timestamp()
    except ValueError:
        return None


def is_reviewer_call(block: dict) -> bool:
    if block.get("type") != "tool_use" or block.get("name") not in AGENT_TOOL_NAMES:
        return False
    subagent = (block.get("input") or {}).get("subagent_type")
    return isinstance(subagent, str) and (
        subagent == REVIEWER_NAME or subagent.endswith(":" + REVIEWER_NAME)
    )


def block_text(block: dict) -> str:
    content = block.get("content")
    if isinstance(content, str):
        return content
    if isinstance(content, list):
        return "\n".join(
            part.get("text", "") for part in content if isinstance(part, dict)
        )
    return ""


def iter_strings(node: object) -> Iterator[str]:
    if isinstance(node, str):
        yield node
    elif isinstance(node, dict):
        for value in node.values():
            yield from iter_strings(value)
    elif isinstance(node, list):
        for value in node:
            yield from iter_strings(value)


def load_record(line: str) -> dict:
    try:
        record = json.loads(line)
    except json.JSONDecodeError as exc:
        raise VerificationError(f"unparseable transcript line: {exc}") from exc
    if not isinstance(record, dict):
        raise VerificationError("transcript line is not a JSON object")
    return record


def scan_transcript(path: Path) -> list[Reviewer]:
    reviewers: dict[str, Reviewer] = {}
    agent_to_tool: dict[str, str] = {}
    reports: dict[str, str] = {}  # agent id -> last hand-back report
    first_line_checked = False

    try:
        handle = path.open(encoding="utf-8", errors="replace")
    except OSError as exc:
        raise VerificationError(f"cannot read transcript {path}: {exc}") from exc

    with handle:
        for line in handle:
            if not line.strip():
                continue
            if not first_line_checked:
                load_record(line)  # a transcript whose first line is not JSON is not a transcript
                first_line_checked = True
            if line.startswith('{"type":"api-request-blob"'):
                continue  # multi-MB request dumps duplicate the real records

            wants_use = REVIEWER_NAME in line
            wants_result = "tool_use_id" in line or "agent-message from=" in line or "<task-id>" in line
            if not (wants_use or wants_result):
                continue

            record = load_record(line)
            rtype = record.get("type")
            if rtype in IGNORED_RECORD_TYPES and not (rtype == "assistant" and wants_use):
                continue

            if rtype == "assistant":
                message = record.get("message")
                content = message.get("content") if isinstance(message, dict) else None
                for block in content if isinstance(content, list) else []:
                    if not (isinstance(block, dict) and is_reviewer_call(block)):
                        continue
                    started = to_epoch(record.get("timestamp"))
                    if started is None:
                        continue  # cannot prove it came after the commit
                    tool_input = block.get("input") or {}
                    reviewers[block["id"]] = Reviewer(
                        tool_use_id=block["id"],
                        description=str(tool_input.get("description") or ""),
                        prompt=str(tool_input.get("prompt") or ""),
                        started=started,
                    )
                continue

            if not reviewers:
                continue

            # Foreground results and background launch acks.
            message = record.get("message")
            content = message.get("content") if isinstance(message, dict) else None
            for block in content if isinstance(content, list) else []:
                if not (isinstance(block, dict) and block.get("type") == "tool_result"):
                    continue
                reviewer = reviewers.get(block.get("tool_use_id"))
                if reviewer is None:
                    continue
                text = block_text(block)
                if text.lstrip().startswith("Async agent launched"):
                    match = AGENT_ID_RE.search(text)
                    if match:
                        agent_to_tool[match.group(1)] = reviewer.tool_use_id
                    continue
                reviewer.report = extract_report(text)
                reviewer.errored = bool(block.get("is_error"))

            # Background hand-backs and the notifications that name their agent.
            for text in iter_strings(record):
                for notification in NOTIFICATION_RE.findall(text):
                    task, ref = TASK_ID_RE.search(notification), TOOL_USE_REF_RE.search(notification)
                    if not (task and ref and ref.group(1) in reviewers):
                        continue
                    agent_to_tool.setdefault(task.group(1), ref.group(1))
                    result = RESULT_RE.search(notification)
                    if result and not result.group(1).lstrip().startswith(DELIVERED_ELSEWHERE):
                        reviewers[ref.group(1)].report = extract_report(result.group(1))
                for agent_id, body in AGENT_MESSAGE_RE.findall(text):
                    reports[agent_id] = extract_report(body)

    if not first_line_checked:
        raise VerificationError(f"transcript {path} is empty")

    for agent_id, report in reports.items():
        tool_id = agent_to_tool.get(agent_id)
        if tool_id in reviewers:
            reviewers[tool_id].report = report
            reviewers[tool_id].agent_id = agent_id
    return list(reviewers.values())


def covers(prompt: str, rel_path: str, repo_root: str) -> bool:
    """True when the prompt names the file: repo-relative, or under the repo root.

    A bare suffix match would let `index.ts` at the root be satisfied by a prompt
    that only names `packages/a/index.ts`, so the character before the path must
    be a separator or the repo root prefix, and the one after must end the path.
    """
    path = re.escape(rel_path)
    tail = r"(?![\w-])(?!\.\w)"
    relative = re.compile(r"(?<![\w./-])" + path + tail)
    absolute = re.compile(re.escape(repo_root.rstrip("/") + "/") + path + tail)
    return bool(relative.search(prompt) or absolute.search(prompt))


def verify(args: argparse.Namespace, files: list[str]) -> list[str]:
    """Return the list of problems; empty means the review is verified."""
    reviewers = [
        r for r in scan_transcript(Path(args.transcript)) if r.started >= args.head_time
    ]
    problems: list[str] = []

    violators = [r for r in reviewers if r.errored or (r.report is not None and not is_clean(r.report))]
    for r in violators:
        why = "errored" if r.errored else "reported violations"
        problems.append(f"reviewer {why}: {r.label}")

    unreviewed: list[str] = []
    for rel in files:
        covering = [r for r in reviewers if covers(r.prompt, rel, args.repo)]
        if any(r.clean for r in covering):
            continue
        if any(r.pending for r in covering):
            state = "no result yet"
        elif covering:
            state = "reviewed, not clean"
        else:
            state = "no reviewer call names it"
        unreviewed.append(f"{rel}  ({state})")
    if unreviewed:
        problems.append("files without a clean review:\n" + "\n".join(f"    - {u}" for u in unreviewed))
    return problems


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--transcript", required=True)
    parser.add_argument("--repo", required=True)
    parser.add_argument("--head", required=True, help="HEAD sha")
    parser.add_argument("--head-time", required=True, type=float, help="HEAD commit time (epoch seconds)")
    args = parser.parse_args()
    files = [ln for ln in sys.stdin.read().split("\n") if ln]

    try:
        problems = verify(args, files)
    except VerificationError as exc:
        print(f"Playbook review could not be verified: {exc}.\n" + FIX_HINT.format(head=args.head[:10]))
        return 1
    if not problems:
        return 0

    detail = "\n".join(f"  * {p}" for p in problems)
    print(
        f"Playbook review NOT verified for HEAD {args.head[:10]}.\n{detail}\n" + FIX_HINT.format(head=args.head[:10])
    )
    return 1


FIX_HINT = (
    "To fix: run the review_playbook skill (one playbook-reviewer agent per changed file, "
    "each prompt naming its file), fix every violation it reports, commit the fixes, "
    "then run glab mr create again. Only reviews started after HEAD ({head}) was committed "
    "count, so a commit made after a clean review needs a new review."
)


if __name__ == "__main__":
    sys.exit(main())
