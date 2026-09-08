#!/usr/bin/env python3
"""
Zero-shot TTS with voice cloning via IndexTTS2.

Not default python. Run through the index-tts manifest bin
(Python 3.11 venv at .dependency/index-tts/.venv/).
Never use default python or host python/py.

Usage
-----
    .dependency/index-tts/.venv/Scripts/python.exe .ai/ai-text-to-speech/tts.py --voice audio/voice/ref.wav --text "你好"
    .dependency/index-tts/.venv/Scripts/python.exe .ai/ai-text-to-speech/tts.py --voice audio/voice/ref.wav --text-file script.txt --output audio/voice/ai-text-to-speech/line.wav
    .dependency/index-tts/.venv/Scripts/python.exe .ai/ai-text-to-speech/tts.py --voice audio/voice/ref.wav --text "Hello" --output audio/voice/ai-text-to-speech
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

AI_ROOT = Path(__file__).resolve().parents[1]
if str(AI_ROOT) not in sys.path:
    sys.path.insert(0, str(AI_ROOT))

from common.audio_utils import audio_output_name  # noqa: E402
from common.dependency_utils import find_repo_root, resolve_tool_bin  # noqa: E402
from common.output_utils import format_default_output_help, resolve_output_path  # noqa: E402


TOOL_NAME = "index-tts"
DEFAULT_OUTPUT_SUBDIR = "ai-text-to-speech"
EMO_VECTOR_SIZE = 8


def resolve_index_tts_root(repo_root: Path, python_bin: Path) -> Path:
    # .dependency/index-tts/.venv/Scripts/python.exe → .dependency/index-tts
    # .dependency/index-tts/.venv/bin/python → .dependency/index-tts
    for parent in python_bin.resolve().parents:
        if (parent / "checkpoints").is_dir() or (parent / "indextts").is_dir():
            return parent
        if parent.name == ".venv":
            return parent.parent
    fallback = repo_root / ".dependency" / "index-tts"
    if fallback.is_dir():
        return fallback
    print(
        f"Could not locate IndexTTS install from {python_bin}. "
        "Expected .dependency/index-tts with checkpoints/.",
        file=sys.stderr,
    )
    sys.exit(1)


def read_text_arg(args: argparse.Namespace) -> str:
    sources = [bool(args.text), bool(args.text_file)]
    if sum(sources) != 1:
        print("Provide exactly one of --text or --text-file.", file=sys.stderr)
        sys.exit(1)
    if args.text is not None:
        text = args.text.strip()
    else:
        path = Path(args.text_file)
        if not path.is_file():
            print(f"Text file not found: {path}", file=sys.stderr)
            sys.exit(1)
        text = path.read_text(encoding="utf-8").strip()
    if not text:
        print("ERROR: Text is empty.", file=sys.stderr)
        sys.exit(1)
    return text


def parse_emotion_vector(raw: str) -> list[float]:
    parts = [p.strip() for p in raw.split(",")]
    if len(parts) != EMO_VECTOR_SIZE:
        print(
            f"--emotion-vector needs {EMO_VECTOR_SIZE} comma-separated floats "
            f"(got {len(parts)}): happy,angry,sad,afraid,disgusted,melancholic,surprised,calm",
            file=sys.stderr,
        )
        sys.exit(1)
    try:
        return [float(p) for p in parts]
    except ValueError as exc:
        print(f"Invalid --emotion-vector value: {exc}", file=sys.stderr)
        sys.exit(1)


def build_infer_kwargs(args: argparse.Namespace, text: str, voice: Path, output: Path) -> dict:
    kwargs: dict = {
        "spk_audio_prompt": str(voice),
        "text": text,
        "output_path": str(output),
        "verbose": bool(args.verbose),
        "emo_alpha": float(args.emotion_weight),
        "use_random": bool(args.random),
    }

    emotion_modes = sum(
        [
            bool(args.emotion_audio),
            bool(args.emotion_vector),
            bool(args.emotion_text) or bool(args.emotion_from_text),
        ]
    )
    if emotion_modes > 1:
        print(
            "Pick one emotion source: --emotion-audio, --emotion-vector, "
            "or --emotion-text / --emotion-from-text.",
            file=sys.stderr,
        )
        sys.exit(1)

    if args.emotion_audio:
        emo_path = Path(args.emotion_audio)
        if not emo_path.is_file():
            print(f"Emotion audio not found: {emo_path}", file=sys.stderr)
            sys.exit(1)
        kwargs["emo_audio_prompt"] = str(emo_path)
    elif args.emotion_vector:
        kwargs["emo_vector"] = parse_emotion_vector(args.emotion_vector)
    elif args.emotion_text or args.emotion_from_text:
        kwargs["use_emo_text"] = True
        if args.emotion_text:
            kwargs["emo_text"] = args.emotion_text

    return kwargs


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Synthesize speech with IndexTTS2 voice cloning.",
    )
    parser.add_argument(
        "--voice",
        required=True,
        help="Speaker reference audio (timbre prompt)",
    )
    text_group = parser.add_mutually_exclusive_group(required=True)
    text_group.add_argument("--text", help="Text to synthesize")
    text_group.add_argument("--text-file", help="UTF-8 text file to synthesize")
    parser.add_argument(
        "-o",
        "--output",
        help="Output WAV file, or a directory (writes <voice-stem>.wav inside). "
        f"Default: {format_default_output_help(DEFAULT_OUTPUT_SUBDIR, source_dir_label='voice-dir', output_name_label='voice-stem.wav')}",
    )
    parser.add_argument(
        "--model-dir",
        default=None,
        help="IndexTTS-2 checkpoints dir (default: <index-tts>/checkpoints)",
    )
    parser.add_argument(
        "--fp16",
        action="store_true",
        help="Use FP16 inference (faster, less VRAM)",
    )
    parser.add_argument(
        "--device",
        default=None,
        help="Runtime device, e.g. cpu, cuda, cuda:0, mps",
    )
    parser.add_argument(
        "--emotion-audio",
        help="Emotion reference audio (separate from speaker timbre)",
    )
    parser.add_argument(
        "--emotion-text",
        help="Natural-language emotion description",
    )
    parser.add_argument(
        "--emotion-from-text",
        action="store_true",
        help="Infer emotion vectors from the synthesis text",
    )
    parser.add_argument(
        "--emotion-vector",
        help="Comma-separated 8-dim emotion vector",
    )
    parser.add_argument(
        "--emotion-weight",
        type=float,
        default=1.0,
        help="Emotion strength emo_alpha in [0, 1] (default: 1.0)",
    )
    parser.add_argument(
        "--random",
        action="store_true",
        help="Enable stochastic sampling (may reduce voice clone fidelity)",
    )
    parser.add_argument(
        "--force",
        action="store_true",
        help="Overwrite existing output file",
    )
    parser.add_argument(
        "--verbose",
        action="store_true",
        help="Verbose IndexTTS inference logs",
    )
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)

    if not (0.0 <= args.emotion_weight <= 1.0):
        print("--emotion-weight must be between 0.0 and 1.0", file=sys.stderr)
        return 1

    repo_root = find_repo_root(Path(__file__))
    if repo_root is None:
        print(
            "Could not find repo root (.dependency/manifest.json). "
            "Run from the project that owns this skill.",
            file=sys.stderr,
        )
        return 1

    # Validate install is registered even though we are already running under its venv.
    python_bin = resolve_tool_bin(repo_root, TOOL_NAME)
    index_tts_root = resolve_index_tts_root(repo_root, python_bin)

    voice = Path(args.voice).expanduser()
    if not voice.is_file():
        print(f"Voice reference not found: {voice}", file=sys.stderr)
        return 1

    text = read_text_arg(args)
    output = resolve_output_path(
        args.output,
        voice,
        DEFAULT_OUTPUT_SUBDIR,
        audio_output_name(voice, suffix=".wav"),
    )
    if output.resolve() == voice.resolve():
        print(
            "Refusing to overwrite the voice reference. "
            "Pass --output to a file or another directory.",
            file=sys.stderr,
        )
        return 1
    if output.exists() and not args.force:
        print(
            f"Output already exists: {output}. Pass --force to overwrite.",
            file=sys.stderr,
        )
        return 1

    model_dir = Path(args.model_dir).expanduser() if args.model_dir else (index_tts_root / "checkpoints")
    cfg_path = model_dir / "config.yaml"
    if not cfg_path.is_file():
        print(
            f"Missing model config: {cfg_path}. "
            "Download IndexTTS-2 checkpoints (see SKILL.md Setup).",
            file=sys.stderr,
        )
        return 1

    output.parent.mkdir(parents=True, exist_ok=True)

    # Prefer importing from the installed package; fall back to repo layout.
    if str(index_tts_root) not in sys.path:
        sys.path.insert(0, str(index_tts_root))

    try:
        from indextts.infer_v2 import IndexTTS2
    except ImportError as exc:
        print(
            f"Failed to import IndexTTS2 from {index_tts_root}: {exc}\n"
            "Run uv sync under .dependency/index-tts (see SKILL.md Setup).",
            file=sys.stderr,
        )
        return 1

    init_kwargs: dict = {
        "cfg_path": str(cfg_path),
        "model_dir": str(model_dir),
        "use_fp16": bool(args.fp16),
        "use_cuda_kernel": False,
        "use_deepspeed": False,
    }
    if args.device:
        init_kwargs["device"] = args.device

    print(f"Voice:  {voice}")
    print(f"Output: {output}")
    print(f"Model:  {model_dir}")
    print(f"Text:   {text[:80]}{'…' if len(text) > 80 else ''}")

    try:
        try:
            tts = IndexTTS2(**init_kwargs)
        except TypeError:
            # Some builds omit device= from __init__.
            init_kwargs.pop("device", None)
            tts = IndexTTS2(**init_kwargs)
        tts.infer(**build_infer_kwargs(args, text, voice, output))
    except Exception as exc:
        print(f"IndexTTS inference failed: {exc}", file=sys.stderr)
        return 1

    if not output.is_file():
        print(f"Inference finished but output missing: {output}", file=sys.stderr)
        return 1

    print(f"Wrote {output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
