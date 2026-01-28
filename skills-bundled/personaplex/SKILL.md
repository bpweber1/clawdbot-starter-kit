# PersonaPlex — Full-Duplex Speech-to-Speech Conversational AI

> NVIDIA's open-source 7B parameter real-time conversational model with voice and role control.

## Overview

PersonaPlex is a real-time, full-duplex speech-to-speech conversational model that enables persona control through text-based role prompts and audio-based voice conditioning. Unlike traditional turn-based voice AI, PersonaPlex listens and speaks **simultaneously** — supporting natural conversational dynamics like interruptions, barge-ins, overlaps, and rapid turn-taking.

- **Model:** [nvidia/personaplex-7b-v1](https://huggingface.co/nvidia/personaplex-7b-v1) (7B parameters)
- **Architecture:** Based on [Moshi](https://arxiv.org/abs/2410.00037) (Mimi codec + Temporal/Depth Transformers)
- **Code:** [github.com/NVIDIA/personaplex](https://github.com/NVIDIA/personaplex) (MIT license)
- **Weights:** NVIDIA Open Model License (commercial use OK)
- **Audio:** 24kHz sample rate, Opus codec
- **Language:** English

## Key Capabilities

| Feature | Description |
|---------|-------------|
| **Full-Duplex** | Listens and speaks at the same time — no turn-taking protocol needed |
| **Voice Cloning** | Condition output voice via audio prompt embeddings (`.pt` files) |
| **Role Control** | Text prompts define persona, scenario, and behavior |
| **Low Latency** | Real-time streaming with sub-250ms interruption response |
| **WebUI** | Built-in browser interface at `https://<host>:8998` |
| **Offline Mode** | Process WAV files without real-time streaming |
| **CPU Offload** | Run on GPUs with limited VRAM via `--cpu-offload` |

## Hardware Requirements

| Tier | GPU | VRAM | Notes |
|------|-----|------|-------|
| **Recommended** | A100 80GB / H100 | 80GB | Full speed, no offloading |
| **Supported** | A100 40GB / A10G | 40GB | May need `--cpu-offload` |
| **Minimum** | Any CUDA GPU | 16GB+ | Requires `--cpu-offload` + `accelerate` |
| **CPU Only** | None | — | Offline eval only, install cpu-only PyTorch |

**Supported architectures:** NVIDIA Ampere (A100), Hopper (H100), Blackwell (B200 — needs special PyTorch, see below).

### Blackwell GPU Note

For B200/B100 GPUs, install PyTorch with CUDA 13.0 support:
```bash
pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu130
```

## Quick Start

### Prerequisites

```bash
# Install Opus codec
sudo apt install libopus-dev    # Ubuntu/Debian
sudo dnf install opus-devel     # Fedora/RHEL
brew install opus               # macOS

# Clone and install
git clone https://github.com/NVIDIA/personaplex.git
cd personaplex
pip install moshi/.

# Set HuggingFace token (must accept license at https://huggingface.co/nvidia/personaplex-7b-v1)
export HF_TOKEN=<YOUR_TOKEN>
```

### Launch Server (Live Interaction)

```bash
SSL_DIR=$(mktemp -d)
python -m moshi.server --ssl "$SSL_DIR"
# → Access WebUI at https://<your-ip>:8998
```

With CPU offload:
```bash
SSL_DIR=$(mktemp -d)
python -m moshi.server --ssl "$SSL_DIR" --cpu-offload
```

### Offline Evaluation

```bash
# Assistant mode
HF_TOKEN=<TOKEN> python -m moshi.offline \
  --voice-prompt "NATF2.pt" \
  --input-wav "assets/test/input_assistant.wav" \
  --seed 42424242 \
  --output-wav "output.wav" \
  --output-text "output.json"

# Customer service mode
HF_TOKEN=<TOKEN> python -m moshi.offline \
  --voice-prompt "NATM1.pt" \
  --text-prompt "$(cat assets/test/prompt_service.txt)" \
  --input-wav "assets/test/input_service.wav" \
  --seed 42424242 \
  --output-wav "output.wav" \
  --output-text "output.json"
```

## Voice Presets

PersonaPlex ships with 18 pre-packaged voice embeddings in two categories:

### Natural Voices (conversational, warm)

| Preset | Gender | Character | ElevenLabs Equivalent |
|--------|--------|-----------|----------------------|
| `NATF0` | Female | Clear, professional | — |
| `NATF1` | Female | Warm, approachable | alice |
| `NATF2` | Female | Friendly, engaging | rachel |
| `NATF3` | Female | Calm, measured | — |
| `NATM0` | Male | Deep, authoritative | george |
| `NATM1` | Male | Smooth, narrative | adam |
| `NATM2` | Male | Calm, reassuring | brian |
| `NATM3` | Male | Energetic, clear | charlie |

### Variety Voices (diverse, expressive)

| Preset | Gender | Character | ElevenLabs Equivalent |
|--------|--------|-----------|----------------------|
| `VARF0` | Female | Bright, energetic | — |
| `VARF1` | Female | Soft, gentle | — |
| `VARF2` | Female | Confident, bold | — |
| `VARF3` | Female | Warm, motherly | — |
| `VARF4` | Female | Youthful, dynamic | — |
| `VARM0` | Male | Rich, baritone | daniel |
| `VARM1` | Male | Light, friendly | — |
| `VARM2` | Male | Gruff, textured | — |
| `VARM3` | Male | Smooth, refined | — |
| `VARM4` | Male | Casual, relaxed | — |

Usage: Reference by name (e.g., `--voice-prompt "NATF2.pt"`) or use `voice_bridge.py` for ElevenLabs ↔ PersonaPlex mapping.

## Prompting Guide

PersonaPlex is conditioned with two prompts before conversation begins:

1. **Voice prompt** — Audio token embedding (`.pt` file) that sets vocal characteristics
2. **Text prompt** — String that defines persona, role, scenario, and behavior

### Assistant Role

Default prompt (used for QA / general assistant):
```
You are a wise and friendly teacher. Answer questions or provide advice in a clear and engaging way.
```

### Customer Service Roles

Template format:
```
You work for {company} which is a {industry} and your name is {agent_name}. Information: {context}
```

Examples:
```
You work for CitySan Services which is a waste management and your name is Ayelen Lucero.
Information: Verify customer name Omar Torres. Current schedule: every other week.
Upcoming pickup: April 12th. Compost bin service available for $8/month add-on.
```

```
You work for Jerusalem Shakshuka which is a restaurant and your name is Owen Foster.
Information: There are two shakshuka options: Classic (poached eggs, $9.50) and Spicy
(scrambled eggs with jalapenos, $10.25). Sides include warm pita ($2.50) and Israeli
salad ($3). No combo offers. Available for drive-through until 9 PM.
```

### Casual Conversation

Base prompt:
```
You enjoy having a good conversation.
```

Extended with topic + persona:
```
You enjoy having a good conversation. Have a casual conversation about favorite foods
and cooking experiences. You are David Green, a former baker now living in Boston. You
enjoy cooking diverse international dishes and appreciate many ethnic restaurants.
```

### Creative / Out-of-Distribution

PersonaPlex generalizes beyond training distribution. Example astronaut scenario:
```
You enjoy having a good conversation. Have a technical discussion about fixing a reactor
core on a spaceship to Mars. You are an astronaut on a Mars mission. Your name is Alex.
You are already dealing with a reactor core meltdown on a Mars mission.
```

## GPU Deployment Guide

### RunPod

```bash
# Using the setup script:
./scripts/setup_server.sh --provider runpod --gpu-type A100

# Manual: Create a GPU pod with:
#   - Template: RunPod PyTorch 2.x
#   - GPU: A100 80GB (or H100)
#   - Disk: 50GB+
#   - Then SSH in and run setup
```

### Lambda Labs

```bash
./scripts/setup_server.sh --provider lambda --gpu-type A100

# Manual: Launch an A100 instance via Lambda Cloud
# SSH in, then follow Quick Start above
```

### AWS

```bash
./scripts/setup_server.sh --provider aws --gpu-type A100 --region us-east-1

# Instance types:
#   - g5.xlarge (A10G 24GB) — needs --cpu-offload
#   - g5.12xlarge (4x A10G) — comfortable
#   - p4d.24xlarge (8x A100 40GB) — production
#   - p5.48xlarge (8x H100 80GB) — maximum performance
```

### Local

```bash
./scripts/setup_server.sh --provider local
```

## Integration with ElevenLabs

PersonaPlex and ElevenLabs serve different roles in the voice AI stack:

| Aspect | ElevenLabs | PersonaPlex |
|--------|-----------|-------------|
| **Mode** | Async TTS (text → speech) | Real-time full-duplex (speech ↔ speech) |
| **Latency** | ~200-500ms first byte | Sub-250ms continuous |
| **Input** | Text | Speech audio stream |
| **Use Case** | Voice messages, narration, notifications | Live conversations, phone calls, agents |
| **Voice Quality** | Studio-grade, many languages | Natural conversational, English only |
| **Cost** | Per-character API pricing | Self-hosted GPU cost |

### Routing Strategy

Use `voice_bridge.py` to maintain consistent persona across both systems:

```python
from scripts.voice_bridge import VoiceBridge

bridge = VoiceBridge()

# User wants "rachel" voice
# → ElevenLabs for async TTS (voice messages, notifications)
# → PersonaPlex NATF2 for live conversation
el_voice = bridge.get_elevenlabs_voice("rachel")     # "rachel"
pp_voice = bridge.get_personaplex_voice("rachel")     # "NATF2"
```

**When to use which:**
- **ElevenLabs:** Sending voice messages, narrating content, multilingual needs
- **PersonaPlex:** Live phone calls, interactive demos, real-time customer service

## Scripts Reference

| Script | Purpose | Usage |
|--------|---------|-------|
| `setup_server.sh` | Deploy on GPU cloud | `./scripts/setup_server.sh --provider runpod` |
| `connect.py` | WebSocket client | `python scripts/connect.py --server-url wss://host:8998/ws` |
| `offline_eval.py` | Process WAV files | `python scripts/offline_eval.py --input audio.wav --voice NATF2` |
| `voice_bridge.py` | Voice name mapping | `python scripts/voice_bridge.py --list` |
| `health_check.sh` | Server status check | `./scripts/health_check.sh https://host:8998` |

## Enterprise Deployment Notes

### For AI Agency Clients

1. **Dedicated GPU Instance:** Deploy on RunPod/Lambda/AWS with A100 80GB for production reliability
2. **SSL/TLS:** Server auto-generates temporary certs; for production, provide real certs via reverse proxy (nginx/Caddy)
3. **Scaling:** Each instance handles one concurrent conversation; scale horizontally with load balancer
4. **Monitoring:** Use `health_check.sh` in monitoring pipeline; integrate with Datadog/Grafana
5. **Voice Consistency:** Use `voice_bridge.py` to maintain same persona voice across ElevenLabs (async) and PersonaPlex (realtime)
6. **Custom Voices:** Train custom voice embeddings from client audio samples for brand-specific voices
7. **Prompt Templates:** Use `prompts/customer_service.txt` as base template; customize per client with their company info, products, and policies

### Architecture for Production

```
                    ┌─────────────────┐
                    │   Load Balancer  │
                    │   (nginx/Caddy)  │
                    └────────┬────────┘
                             │
              ┌──────────────┼──────────────┐
              │              │              │
     ┌────────▼──────┐ ┌────▼────────┐ ┌───▼─────────┐
     │ PersonaPlex   │ │ PersonaPlex │ │ PersonaPlex │
     │ Instance 1    │ │ Instance 2  │ │ Instance N  │
     │ (A100 GPU)    │ │ (A100 GPU)  │ │ (A100 GPU)  │
     └───────────────┘ └─────────────┘ └─────────────┘
```

### Cost Estimates

| Provider | GPU | Hourly Cost | Monthly (24/7) |
|----------|-----|-------------|----------------|
| RunPod | A100 80GB | ~$1.64/hr | ~$1,180/mo |
| Lambda Labs | A100 80GB | ~$1.10/hr | ~$790/mo |
| AWS p4d.24xlarge | 8x A100 40GB | ~$32.77/hr | ~$23,600/mo |
| AWS g5.xlarge | A10G 24GB | ~$1.01/hr | ~$727/mo |

## Citation

```bibtex
@article{roy2026personaplex,
  title={PersonaPlex: Voice and Role Control for Full Duplex Conversational Speech Models},
  author={Roy, Rajarshi and Raiman, Jonathan and Lee, Sang-gil and Ene, Teodor-Dumitru and Kirby, Robert and Kim, Sungwon and Kim, Jaehyeon and Catanzaro, Bryan},
  year={2026}
}
```
