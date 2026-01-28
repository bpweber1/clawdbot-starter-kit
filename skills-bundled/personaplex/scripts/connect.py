#!/usr/bin/env python3
"""
connect.py — WebSocket client for PersonaPlex server.

Connects to a running PersonaPlex server, streams audio from an input device,
and plays received audio in real-time. Supports voice preset selection and
text prompt injection.

Usage:
    python connect.py --server-url wss://host:8998/ws --voice NATF2
    python connect.py --server-url wss://host:8998/ws --text-prompt "You are a helpful assistant."
    python connect.py --server-url wss://host:8998/ws --voice NATM1 --input-device 1
"""

import argparse
import asyncio
import json
import logging
import signal
import ssl
import struct
import sys
import time
from pathlib import Path

logger = logging.getLogger("personaplex.connect")

# ─── Voice Presets ───────────────────────────────────────────────────────────

VOICE_PRESETS = {
    # Natural voices
    "NATF0", "NATF1", "NATF2", "NATF3",
    "NATM0", "NATM1", "NATM2", "NATM3",
    # Variety voices
    "VARF0", "VARF1", "VARF2", "VARF3", "VARF4",
    "VARM0", "VARM1", "VARM2", "VARM3", "VARM4",
}

# ─── Audio Constants ─────────────────────────────────────────────────────────

SAMPLE_RATE = 24000
CHANNELS = 1
CHUNK_DURATION_MS = 80  # 80ms chunks
CHUNK_SIZE = int(SAMPLE_RATE * CHUNK_DURATION_MS / 1000)  # 1920 samples per chunk


class PersonaPlexClient:
    """WebSocket client for PersonaPlex full-duplex speech conversation."""

    def __init__(
        self,
        server_url: str,
        voice: str = "NATF2",
        text_prompt: str = "",
        input_device: int | None = None,
        output_device: int | None = None,
    ):
        self.server_url = server_url
        self.voice = voice.upper()
        self.text_prompt = text_prompt
        self.input_device = input_device
        self.output_device = output_device
        self.running = False
        self._ws = None
        self._audio_in_stream = None
        self._audio_out_stream = None

        if self.voice not in VOICE_PRESETS:
            logger.warning(
                f"Voice '{self.voice}' not in known presets. "
                f"Known: {sorted(VOICE_PRESETS)}"
            )

    async def connect(self):
        """Establish WebSocket connection to PersonaPlex server."""
        try:
            import websockets
        except ImportError:
            logger.error(
                "websockets package required. Install with: pip install websockets"
            )
            sys.exit(1)

        # Allow self-signed certs (PersonaPlex uses temp SSL)
        ssl_context = ssl.create_default_context()
        ssl_context.check_hostname = False
        ssl_context.verify_mode = ssl.CERT_NONE

        logger.info(f"Connecting to {self.server_url}...")
        self._ws = await websockets.connect(
            self.server_url,
            ssl=ssl_context,
            ping_interval=20,
            ping_timeout=60,
            max_size=2**20,  # 1MB max message
        )
        self.running = True
        logger.info("Connected to PersonaPlex server.")

        # Send initial configuration
        config = {
            "voice_prompt": f"{self.voice}.pt",
        }
        if self.text_prompt:
            config["text_prompt"] = self.text_prompt
        await self._ws.send(json.dumps(config))
        logger.info(f"Sent config: voice={self.voice}, prompt={'set' if self.text_prompt else 'default'}")

    async def send_audio(self):
        """Capture audio from microphone and send to server."""
        try:
            import sounddevice as sd
        except ImportError:
            logger.error(
                "sounddevice package required. Install with: pip install sounddevice"
            )
            return

        logger.info(f"Starting audio capture (device: {self.input_device or 'default'})...")

        loop = asyncio.get_event_loop()
        audio_queue = asyncio.Queue()

        def audio_callback(indata, frames, time_info, status):
            if status:
                logger.warning(f"Audio input status: {status}")
            loop.call_soon_threadsafe(audio_queue.put_nowait, bytes(indata))

        try:
            self._audio_in_stream = sd.RawInputStream(
                samplerate=SAMPLE_RATE,
                channels=CHANNELS,
                dtype="int16",
                blocksize=CHUNK_SIZE,
                device=self.input_device,
                callback=audio_callback,
            )
            self._audio_in_stream.start()
            logger.info("Audio capture started.")

            while self.running:
                try:
                    audio_data = await asyncio.wait_for(audio_queue.get(), timeout=1.0)
                    if self._ws and self.running:
                        await self._ws.send(audio_data)
                except asyncio.TimeoutError:
                    continue
                except Exception as e:
                    if self.running:
                        logger.error(f"Error sending audio: {e}")
                    break

        finally:
            if self._audio_in_stream:
                self._audio_in_stream.stop()
                self._audio_in_stream.close()
                logger.info("Audio capture stopped.")

    async def receive_audio(self):
        """Receive audio from server and play through speakers."""
        try:
            import sounddevice as sd
        except ImportError:
            logger.error(
                "sounddevice package required. Install with: pip install sounddevice"
            )
            return

        logger.info(f"Starting audio playback (device: {self.output_device or 'default'})...")

        try:
            self._audio_out_stream = sd.RawOutputStream(
                samplerate=SAMPLE_RATE,
                channels=CHANNELS,
                dtype="int16",
                blocksize=CHUNK_SIZE,
                device=self.output_device,
            )
            self._audio_out_stream.start()
            logger.info("Audio playback started.")

            while self.running:
                try:
                    message = await asyncio.wait_for(self._ws.recv(), timeout=1.0)

                    if isinstance(message, bytes):
                        # Audio data
                        self._audio_out_stream.write(message)
                    elif isinstance(message, str):
                        # Text/control message
                        try:
                            data = json.loads(message)
                            if "text" in data:
                                logger.info(f"[Agent]: {data['text']}")
                            elif "error" in data:
                                logger.error(f"Server error: {data['error']}")
                            else:
                                logger.debug(f"Server message: {data}")
                        except json.JSONDecodeError:
                            logger.info(f"[Agent]: {message}")

                except asyncio.TimeoutError:
                    continue
                except Exception as e:
                    if self.running:
                        logger.error(f"Error receiving audio: {e}")
                    break

        finally:
            if self._audio_out_stream:
                self._audio_out_stream.stop()
                self._audio_out_stream.close()
                logger.info("Audio playback stopped.")

    async def run(self):
        """Main run loop — connect and stream bidirectionally."""
        await self.connect()

        # Handle graceful shutdown
        loop = asyncio.get_event_loop()
        for sig in (signal.SIGINT, signal.SIGTERM):
            loop.add_signal_handler(sig, lambda: asyncio.create_task(self.stop()))

        try:
            # Run send and receive concurrently
            await asyncio.gather(
                self.send_audio(),
                self.receive_audio(),
            )
        except Exception as e:
            logger.error(f"Connection error: {e}")
        finally:
            await self.stop()

    async def stop(self):
        """Gracefully stop the client."""
        if not self.running:
            return
        self.running = False
        logger.info("Shutting down...")

        if self._ws:
            await self._ws.close()
            self._ws = None


# ─── Clawdbot Integration Hook ──────────────────────────────────────────────

async def clawdbot_connect(
    server_url: str,
    voice: str = "NATF2",
    text_prompt: str = "",
    duration_seconds: float | None = None,
) -> dict:
    """
    Integration hook for Clawdbot skill system.

    Args:
        server_url: WebSocket URL of PersonaPlex server
        voice: Voice preset name (e.g., NATF2, NATM1)
        text_prompt: Text prompt for persona conditioning
        duration_seconds: Optional max duration in seconds

    Returns:
        dict with status and session info
    """
    client = PersonaPlexClient(
        server_url=server_url,
        voice=voice,
        text_prompt=text_prompt,
    )

    result = {
        "status": "connected",
        "server": server_url,
        "voice": voice,
        "text_prompt": text_prompt[:100] + "..." if len(text_prompt) > 100 else text_prompt,
    }

    try:
        if duration_seconds:
            await asyncio.wait_for(client.run(), timeout=duration_seconds)
            result["status"] = "completed"
        else:
            await client.run()
            result["status"] = "disconnected"
    except asyncio.TimeoutError:
        result["status"] = "timeout"
        await client.stop()
    except Exception as e:
        result["status"] = "error"
        result["error"] = str(e)

    return result


# ─── CLI ─────────────────────────────────────────────────────────────────────

def list_audio_devices():
    """List available audio devices."""
    try:
        import sounddevice as sd
        print("\nAvailable Audio Devices:")
        print("=" * 60)
        devices = sd.query_devices()
        for i, dev in enumerate(devices):
            direction = []
            if dev["max_input_channels"] > 0:
                direction.append("IN")
            if dev["max_output_channels"] > 0:
                direction.append("OUT")
            marker = " *" if i == sd.default.device[0] or i == sd.default.device[1] else ""
            print(f"  [{i}] {dev['name']} ({'/'.join(direction)}){marker}")
        print(f"\nDefault input:  [{sd.default.device[0]}]")
        print(f"Default output: [{sd.default.device[1]}]")
    except ImportError:
        print("Install sounddevice to list audio devices: pip install sounddevice")


def parse_args():
    parser = argparse.ArgumentParser(
        description="PersonaPlex WebSocket Client — connect to a running server for full-duplex conversation.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Connect with default voice
  python connect.py --server-url wss://myserver:8998/ws

  # Connect with specific voice and prompt
  python connect.py --server-url wss://myserver:8998/ws --voice NATM1 \\
      --text-prompt "You work for Acme Corp and your name is Alex."

  # List audio devices
  python connect.py --list-devices

  # Use specific audio device
  python connect.py --server-url wss://myserver:8998/ws --input-device 2

Voice Presets:
  Natural (female): NATF0, NATF1, NATF2, NATF3
  Natural (male):   NATM0, NATM1, NATM2, NATM3
  Variety (female): VARF0, VARF1, VARF2, VARF3, VARF4
  Variety (male):   VARM0, VARM1, VARM2, VARM3, VARM4
        """,
    )
    parser.add_argument(
        "--server-url",
        type=str,
        default="wss://localhost:8998/ws",
        help="PersonaPlex server WebSocket URL (default: wss://localhost:8998/ws)",
    )
    parser.add_argument(
        "--voice",
        type=str,
        default="NATF2",
        help="Voice preset name (default: NATF2)",
    )
    parser.add_argument(
        "--text-prompt",
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
    parser.add_argument(
        "--input-device",
        type=int,
        default=None,
        help="Audio input device index",
    )
    parser.add_argument(
        "--output-device",
        type=int,
        default=None,
        help="Audio output device index",
    )
    parser.add_argument(
        "--list-devices",
        action="store_true",
        help="List available audio devices and exit",
    )
    parser.add_argument(
        "--duration",
        type=float,
        default=None,
        help="Max session duration in seconds (unlimited if not set)",
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

    if args.list_devices:
        list_audio_devices()
        return

    # Load prompt from file if specified
    text_prompt = args.text_prompt
    if args.prompt_file:
        prompt_path = Path(args.prompt_file)
        if not prompt_path.exists():
            logger.error(f"Prompt file not found: {args.prompt_file}")
            sys.exit(1)
        text_prompt = prompt_path.read_text().strip()
        logger.info(f"Loaded prompt from {args.prompt_file}")

    # Validate
    if not args.server_url:
        logger.error("--server-url is required")
        sys.exit(1)

    print()
    print("╔══════════════════════════════════════════════════════════╗")
    print("║          PersonaPlex Full-Duplex Client                 ║")
    print("╠══════════════════════════════════════════════════════════╣")
    print(f"║  Server: {args.server_url:<47s} ║")
    print(f"║  Voice:  {args.voice:<47s} ║")
    print(f"║  Prompt: {(text_prompt[:44] + '...') if len(text_prompt) > 47 else text_prompt or '(default)':<47s} ║")
    print("╠══════════════════════════════════════════════════════════╣")
    print("║  Press Ctrl+C to disconnect                            ║")
    print("╚══════════════════════════════════════════════════════════╝")
    print()

    client = PersonaPlexClient(
        server_url=args.server_url,
        voice=args.voice,
        text_prompt=text_prompt,
        input_device=args.input_device,
        output_device=args.output_device,
    )

    try:
        if args.duration:
            asyncio.run(asyncio.wait_for(client.run(), timeout=args.duration))
        else:
            asyncio.run(client.run())
    except asyncio.TimeoutError:
        logger.info(f"Session duration limit reached ({args.duration}s)")
    except KeyboardInterrupt:
        logger.info("Disconnected by user.")
    except Exception as e:
        logger.error(f"Fatal error: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()
