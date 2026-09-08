#!/usr/bin/env python3
"""Tests for write_subtitles.py."""

from __future__ import annotations

import subprocess
import sys
import tempfile
import unittest
import wave
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
if str(SCRIPT_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPT_DIR))
AI_ROOT = SCRIPT_DIR.parent
if str(AI_ROOT) not in sys.path:
    sys.path.insert(0, str(AI_ROOT))

import write_subtitles  # noqa: E402
from common.dependency_utils import find_repo_root, resolve_tool_bin  # noqa: E402

REPO_ROOT = find_repo_root(Path(__file__))
assert REPO_ROOT is not None
PYTHON_BIN = resolve_tool_bin(REPO_ROOT, "python")
SUBS_SCRIPT = SCRIPT_DIR / "write_subtitles.py"


def write_silent_wav(path: Path, seconds: float = 1.0, rate: int = 44100) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    frames = int(seconds * rate)
    with wave.open(str(path), "wb") as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(rate)
        wf.writeframes(b"\x00\x00" * frames)


class SubtitleLogicTest(unittest.TestCase):
    def test_split_sentences_cjk_punctuation(self) -> None:
        parts = write_subtitles.split_sentences("First sentence. Second sentence!")
        self.assertEqual(parts, ["First sentence.", "Second sentence!"])

    def test_split_sentences_english(self) -> None:
        parts = write_subtitles.split_sentences("Hello world. Next line!")
        self.assertEqual(parts, ["Hello world.", "Next line!"])

    def test_srt_timestamp(self) -> None:
        self.assertEqual(write_subtitles.srt_timestamp(0.0), "00:00:00,000")
        self.assertEqual(write_subtitles.srt_timestamp(3661.5), "01:01:01,500")

    def test_allocate_durations_preserves_total(self) -> None:
        durs = write_subtitles.allocate_durations([2, 3, 5], 10.0)
        self.assertAlmostEqual(sum(durs), 10.0, places=6)
        self.assertEqual(len(durs), 3)


class WriteSubtitlesCliTest(unittest.TestCase):
    def run_cli(self, *args: str) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            [str(PYTHON_BIN), str(SUBS_SCRIPT), *args],
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
            cwd=str(REPO_ROOT),
        )

    def test_writes_srt_from_shots(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "Chinese").mkdir()
            (root / "English").mkdir()
            write_silent_wav(root / "Chinese" / "01.wav", 2.0)
            write_silent_wav(root / "English" / "01.wav", 2.0)
            shots = {
                "title": "Demo",
                "shot_count": 1,
                "shots": [
                    {
                        "id": "01",
                        "title": "Hook",
                        "chinese": "Hello.",
                        "english": "Hi.",
                        "chinese_skip": False,
                        "english_skip": False,
                    }
                ],
            }
            shots_path = root / "shots.json"
            shots_path.write_text(
                __import__("json").dumps(shots, ensure_ascii=False, indent=2) + "\n",
                encoding="utf-8",
            )
            result = self.run_cli(
                "--audio-dir",
                str(root),
                "--shots",
                str(shots_path),
            )
            self.assertEqual(result.returncode, 0)
            self.assertTrue((root / "Chinese.srt").is_file())
            self.assertTrue((root / "English.srt").is_file())
            zh = (root / "Chinese.srt").read_text(encoding="utf-8")
            self.assertIn("Hello.", zh)
            self.assertIn("-->", zh)

    def test_missing_audio_dir(self) -> None:
        result = self.run_cli("--audio-dir", "missing-dir", "--shots", "missing.json")
        self.assertEqual(result.returncode, 1)


if __name__ == "__main__":
    unittest.main()
