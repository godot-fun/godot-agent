#!/usr/bin/env python3
"""
Parse storyboard markdown into per-shot Chinese / English VO lines.

Run through default python from .dependency/manifest.json.
Never use host python/py.

Usage
-----
    .dependency/python/python .ai/storyboard-tts/parse_storyboard.py path/to/storyboard.md
    .dependency/python/python .ai/storyboard-tts/parse_storyboard.py storyboard.md -o shots.json
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path


SHOT_HEADER_RE = re.compile(
    r"^###\s+Shot\s+(\d+)\s*[—–\-]\s*(.+?)\s*$",
    re.IGNORECASE | re.MULTILINE,
)
FIELD_RE = re.compile(
    r"^\s*[-*]\s+\*\*(?P<key>[^*]+)\*\*\s*:?\s*(?P<value>.*)\s*$",
    re.MULTILINE,
)
TITLE_RE = re.compile(
    r"^#\s+Storyboard\s*(?:[—–\-]|:)\s*(.+?)\s*$",
    re.IGNORECASE | re.MULTILINE,
)
NO_VO_MARKERS = {
    "(no vo)",
    "(no vo.)",
    "no vo",
    "(no narration)",
    "(none)",
    "-",
    "—",
    "n/a",
    "none",
}


def is_no_vo(text: str) -> bool:
    t = text.strip().lower()
    if not t:
        return True
    return t in NO_VO_MARKERS


def normalize_field_key(key: str) -> str:
    return key.strip().lower().replace(" ", "").rstrip(":")


def extract_fields(block: str) -> dict[str, str]:
    fields: dict[str, str] = {}
    for match in FIELD_RE.finditer(block):
        key = normalize_field_key(match.group("key"))
        fields[key] = match.group("value").strip()
    return fields


def parse_storyboard(markdown: str) -> dict:
    title_match = TITLE_RE.search(markdown)
    title = title_match.group(1).strip() if title_match else "Untitled"

    headers = list(SHOT_HEADER_RE.finditer(markdown))
    shots: list[dict] = []

    for i, header in enumerate(headers):
        raw_id = header.group(1)
        shot_id = f"{int(raw_id):02d}" if raw_id.isdigit() else raw_id
        shot_title = header.group(2).strip()

        start = header.end()
        end = headers[i + 1].start() if i + 1 < len(headers) else len(markdown)
        next_section = re.search(r"^##\s+\S", markdown[start:end], re.MULTILINE)
        if next_section:
            end = start + next_section.start()

        fields = extract_fields(markdown[start:end])
        chinese = fields.get("chinese", "").strip()
        english = fields.get("english", "").strip()
        duration = fields.get("duration", "").strip()

        shots.append(
            {
                "id": shot_id,
                "title": shot_title,
                "duration_hint": duration,
                "chinese": chinese,
                "english": english,
                "chinese_skip": is_no_vo(chinese),
                "english_skip": is_no_vo(english),
            }
        )

    return {
        "title": title,
        "shot_count": len(shots),
        "shots": shots,
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Parse storyboard markdown into shot VO JSON.",
    )
    parser.add_argument("storyboard", help="Path to storyboard markdown")
    parser.add_argument(
        "-o",
        "--output",
        help="Write JSON to this path (default: stdout)",
    )
    args = parser.parse_args(argv)

    path = Path(args.storyboard).expanduser()
    if not path.is_file():
        print(f"Storyboard not found: {path}", file=sys.stderr)
        return 1

    data = parse_storyboard(path.read_text(encoding="utf-8-sig"))
    if data["shot_count"] == 0:
        print(
            f"No shots found in {path}. Expected headers like: ### Shot 01 — Title",
            file=sys.stderr,
        )
        return 1

    text = json.dumps(data, ensure_ascii=False, indent=2)
    if args.output:
        out = Path(args.output).expanduser()
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_text(text + "\n", encoding="utf-8")
        print(f"Wrote {out} ({data['shot_count']} shots)")
    else:
        print(text)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
