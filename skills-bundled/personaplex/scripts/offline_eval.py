#!/usr/bin/env python3
"""
offline_eval.py — Offline evaluation wrapper for PersonaPlex.

Processes WAV files through PersonaPlex without needing a running server.
Wraps `python -m moshi.offline` with convenience features like batch mode,
voice name resolution, and structured output.

Usage:
    # Single file
    python offline_eval.py --input audio.wav --voice NATF2 --output result.wav

    # With text prompt
    python offline_eval.py --input audio.wav --voice NATM1 \
        --prompt "You work for Acme Corp and your name is Alex."

    # Prompt from file
    python offline_eval.py --input audio.wav --voice NATM1 \
        --prompt-file prompts/customer_service.txt

    # Batch mode
    python offline_eval.py --batch-dir ./inputs/ --voice NATF2 --output-dir ./outputs/

    # With CPU offload
    python offline_eval.py --input audio.wav --voice NATF2 --cpu-offload
"""

import argparse
import json
import logging
import os
import subprocess
import sys
import time
from pathlib import Path

logger = logging.getLogger("personaplex.offline")

# ─── Voice Presets ───────────────────────────────────────────────────────────

VOICE_PRESETS = [
    "NATF0", "NATF1", "NATF2", "NATF3",
    "NATM0", "NATM1", "NATM2", "NATM3",
    "VARF0", "VARF1", "VARF2", "VARF3", "VARF4",
    "VARM0", "VARM1", "VARM2", "VARM3", "VARM4",
]

# ElevenLabs name → PersonaPlex preset mapping
VOICE_ALIASES = {
    "rachel": "NATF2",
    "alice": "NATF1",
    "adam": "NATM1",
    "george": "NATM0",
    "brian": "NATM2",
    "charlie": "NATM3",
    "daniel": "VARM0",
}


def resolve_voice(voice_name: str) -> str:
    """Resolve a voice name to a PersonaPlex preset."""
    upper = voice_name.upper()
    if upper in VOICE_PRESETS:
        return upper
    lower = voice_name.lower()
    if lower in VOICE_ALIASES:
        resolved = VOICE_ALIASES[lower]
        logger.info(f"Resolved voice alias '{voice_name}' → '{resolved}'")
        return resolved
    logger.warning(
        f"Unknown voice '{voice_name}'. Using as-is. "
        f"Known presets: {', '.join(VOICE_PRESETS)}"
    )
    return voice_name


def process_single(
    input_wav: Path,
    output_wav: Path,
    voice: str,
    text_prompt: str = "",
    seed: int = 42424242,
    cpu_offload: bool = False,
    output_text: Path | None = None,
) -> dict:
    """
    Process a single WAV file through PersonaPlex offline mode.

    Returns:
        dict with status, paths, duration, and any transcription data.
    """
    voice_preset = resolve_voice(voice)
    voice_file = f"{voice_preset}.pt"

    # Build command
    cmd = [
        sys.executable, "-m", "moshi.offline",
        "--voice-prompt", voice_file,
        "--input-wav", str(input_wav),
        "--seed", str(seed),
        "--output-wav", str(output_wav),
    ]

    if text_prompt:
        cmd.extend(["--text-prompt", text_prompt])

    if cpu_offload:
        cmd.append("--cpu-offload")

    text_output_path = output_text or output_wav.with_suffix(".json")
    cmd.extend(["--output-text", str(text_output_path)])

    # Ensure HF_TOKEN is set
    env = os.environ.copy()
    if "HF_TOKEN" not in env:
        logger.error("HF_TOKEN environment variable is required.")
        return {
            "status": "error",
            "error": "HF_TOKEN not set",
            "input": str(input_wav),
        }

    result = {
        "status": "pending",
        "input": str(input_wav),
        "output_wav": str(output_wav),
        "output_text": str(text_output_path),
        "voice": voice_preset,
        "text_prompt": text_prompt[:200] if text_prompt else "",
        "seed": seed,
    }

    logger.info(f"Processing: {input_wav.name} → {output_wav.name} (voice: {voice_preset})")
    logger.debug(f"Command: {' '.join(cmd)}")

    start_time = time.time()

    try:
        proc = subprocess.run(
            cmd,
            env=env,
            capture_output=True,
            text=True,
            timeout=600,  # 10 minute timeout
        )

        elapsed = time.time() - start_time
        result["duration_seconds"] = round(elapsed, 2)

        if proc.returncode == 0:
            result["status"] = "success"
            logger.info(f"✓ Completed in {elapsed:.1f}s: {output_wav.name}")

            # Load transcription if available
            if text_output_path.exists():
                try:
                    with open(text_output_path) as f:
                        result["transcription"] = json.load(f)
                except json.JSONDecodeError:
                    result["transcription_raw"] = text_output_path.read_text().strip()

            # Check output exists
            if not output_wav.exists():
                result["status"] = "error"
                result["error"] = "Output WAV not created"

        else:
            result["status"] = "error"
            result["error"] = proc.stderr.strip() or f"Exit code: {proc.returncode}"
            logger.error(f"✗ Failed: {proc.stderr.strip()[:200]}")

        if proc.stdout.strip():
            result["stdout"] = proc.stdout.strip()[-500:]

    except subprocess.TimeoutExpired:
        result["status"] = "timeout"
        result["error"] = "Processing exceeded 10 minute timeout"
        logger.error(f"✗ Timeout processing {input_wav.name}")
    except FileNotFoundError:
        result["status"] = "error"
        result["error"] = "moshi package not found. Install with: pip install moshi/."
        logger.error("moshi module not found")
    except Exception as e:
        result["status"] = "error"
        result["error"] = str(e)
        logger.error(f"✗ Exception: {e}")

    return result


def process_batch(
    input_dir: Path,
    output_dir: Path,
    voice: str,
    text_prompt: str = "",
    seed: int = 42424242,
    cpu_offload: bool = False,
) -> list[dict]:
    """Process all WAV files in a directory."""
    output_dir.mkdir(parents=True, exist_ok=True)

    wav_files = sorted(input_dir.glob("*.wav"))
    if not wav_files:
        logger.warning(f"No WAV files found in {input_dir}")
        return []

    logger.info(f"Batch processing {len(wav_files)} files from {input_dir}")
    results = []

    for i, wav_file in enumerate(wav_files, 1):
        logger.info(f"[{i}/{len(wav_files)}] {wav_file.name}")
        output_wav = output_dir / f"output_{wav_file.stem}.wav"
        output_text = output_dir / f"output_{wav_file.stem}.json"

        result = process_single(
            input_wav=wav_file,
            output_wav=output_wav,
            voice=voice,
            text_prompt=text_prompt,
            seed=seed,
            cpu_offload=cpu_offload,
            output_text=output_text,
        )
        results.append(result)

    # Summary
    successes = sum(1 for r in results if r["status"] == "success")
    failures = len(results) - successes
    logger.info(f"Batch complete: {successes} succeeded, {failures} failed")

    return results


def parse_args():
    parser = argparse.ArgumentParser(
        description="PersonaPlex Offline Evaluation — process WAV files through the model.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Single file with natural female voice
  python offline_eval.py --input question.wav --voice NATF2 --output answer.wav

  # Customer service scenario
  python offline_eval.py --input call.wav --voice NATM1 \\
      --prompt "You work for Acme Corp and your name is Alex."

  # Use ElevenLabs voice name (auto-mapped)
  python offline_eval.py --input audio.wav --voice rachel --output result.wav

  # Batch processing
  python offline_eval.py --batch-dir ./calls/ --voice NATM0 --output-dir ./results/

  # With CPU offload for limited GPU memory
  python offline_eval.py --input audio.wav --voice NATF2 --cpu-offload

Voice Presets:
  Natural (female): NATF0, NATF1, NATF2, NATF3
  Natural (male):   NATM0, NATM1, NATM2, NATM3
  Variety (female): VARF0, VARF1, VARF2, VARF3, VARF4
  Variety (male):   VARM0, VARM1, VARM2, VARM3, VARM4

Voice Aliases (ElevenLabs → PersonaPlex):
  rachel→NATF2, alice→NATF1, adam→NATM1, george→NATM0,
  brian→NATM2, charlie→NATM3, daniel→VARM0
        """,
    )

    # Input modes (mutually exclusive)
    input_group = parser.add_mutually_exclusive_group(required=True)
    input_group.add_argument(
        "--input", "-i",
        type=str,
        help="Input WAV file path",
    )
    input_group.add_argument(
        "--batch-dir",
        type=str,
        help="Directory of WAV files for batch processing",
    )

    # Output
    parser.add_argument(
        "--output", "-o",
        type=str,
        default=None,
        help="Output WAV file path (default: output_<input>.wav)",
    )
    parser.add_argument(
        "--output-dir",
        type=str,
        default="./output",
        help="Output directory for batch mode (default: ./output)",
    )
    parser.add_argument(
        "--output-text",
        type=str,
        default=None,
        help="Output transcription JSON path (default: <output>.json)",
    )

    # Voice and prompt
    parser.add_argument(
        "--voice", "-V",
        type=str,
        default="NATF2",
        help="Voice preset or alias (default: NATF2)",
    )
    parser.add_argument(
        "--prompt", "-p",
        type=str,
        default="",
        help="Text prompt for persona conditioning",
    )
    parser.add_argument(
        "--prompt-file",
        type=str,
        default=None,
        help="Read text prompt from file",
    )

    # Processing options
    parser.add_argument(
        "--seed",
        type=int,
        default=42424242,
        help="Random seed for reproducibility (default: 42424242)",
    )
    parser.add_argument(
        "--cpu-offload",
        action="store_true",
        help="Enable CPU offload for limited GPU memory",
    )

    # Output format
    parser.add_argument(
        "--json",
        action="store_true",
        help="Output results as JSON",
    )
    parser.add_argument(
        "--verbose", "-v",
        action="store_true",
        help="Enable verbose logging",
    )

    return parser.parse_args()


def main():
    args = parse_args()

    # Setup logging
    log_level = logging.DEBUG if args.verbose else logging.INFO
    logging.basicConfig(
        level=log_level,
        format="%(asctime)s [%(name)s] %(levelname)s: %(message)s",
        datefmt="%H:%M:%S",
    )

    # Load prompt from file if specified
    text_prompt = args.prompt
    if args.prompt_file:
        prompt_path = Path(args.prompt_file)
        if not prompt_path.exists():
            logger.error(f"Prompt file not found: {args.prompt_file}")
            sys.exit(1)
        text_prompt = prompt_path.read_text().strip()
        logger.info(f"Loaded prompt from {args.prompt_file} ({len(text_prompt)} chars)")

    # Process
    if args.batch_dir:
        # Batch mode
        input_dir = Path(args.batch_dir)
        if not input_dir.is_dir():
            logger.error(f"Batch directory not found: {args.batch_dir}")
            sys.exit(1)

        output_dir = Path(args.output_dir)
        results = process_batch(
            input_dir=input_dir,
            output_dir=output_dir,
            voice=args.voice,
            text_prompt=text_prompt,
            seed=args.seed,
            cpu_offload=args.cpu_offload,
        )

        if args.json:
            print(json.dumps(results, indent=2))
        else:
            print(f"\n{'='*60}")
            print(f"Batch Results: {len(results)} files processed")
            print(f"{'='*60}")
            for r in results:
                status_icon = "✓" if r["status"] == "success" else "✗"
                print(f"  {status_icon} {Path(r['input']).name} → {r.get('duration_seconds', '?')}s")
                if r["status"] != "success":
                    print(f"    Error: {r.get('error', 'unknown')}")

    else:
        # Single file mode
        input_path = Path(args.input)
        if not input_path.exists():
            logger.error(f"Input file not found: {args.input}")
            sys.exit(1)

        output_path = Path(args.output) if args.output else Path(f"output_{input_path.stem}.wav")
        output_text = Path(args.output_text) if args.output_text else None

        result = process_single(
            input_wav=input_path,
            output_wav=output_path,
            voice=args.voice,
            text_prompt=text_prompt,
            seed=args.seed,
            cpu_offload=args.cpu_offload,
            output_text=output_text,
        )

        if args.json:
            print(json.dumps(result, indent=2))
        else:
            print(f"\n{'='*60}")
            if result["status"] == "success":
                print(f"✓ Success!")
                print(f"  Output WAV:  {result['output_wav']}")
                print(f"  Output JSON: {result['output_text']}")
                print(f"  Voice:       {result['voice']}")
                print(f"  Duration:    {result.get('duration_seconds', '?')}s")
                if "transcription" in result:
                    print(f"  Transcription: {json.dumps(result['transcription'], indent=2)[:500]}")
            else:
                print(f"✗ Failed: {result.get('error', 'unknown error')}")
            print(f"{'='*60}")

        sys.exit(0 if result["status"] == "success" else 1)


if __name__ == "__main__":
    main()
