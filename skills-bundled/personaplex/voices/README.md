# PersonaPlex Voice Mapping

## Voice Presets

PersonaPlex ships with 18 pre-packaged voice embeddings (`.pt` files) organized in two categories:

### Natural Voices

Optimized for conversational, warm, and natural-sounding interactions.

| Preset | Gender | Character | ElevenLabs Match |
|--------|--------|-----------|-----------------|
| `NATF0` | Female | Clear, professional | elli |
| `NATF1` | Female | Warm, approachable | alice |
| `NATF2` | Female | Friendly, engaging | **rachel** |
| `NATF3` | Female | Calm, measured | bella |
| `NATM0` | Male | Deep, authoritative | **george** |
| `NATM1` | Male | Smooth, narrative | **adam** |
| `NATM2` | Male | Calm, reassuring | **brian** |
| `NATM3` | Male | Energetic, clear | **charlie** |

### Variety Voices

More diverse vocal characteristics for specialized roles.

| Preset | Gender | Character | ElevenLabs Match |
|--------|--------|-----------|-----------------|
| `VARF0` | Female | Bright, energetic | domi |
| `VARF1` | Female | Soft, gentle | grace |
| `VARF2` | Female | Confident, bold | serena |
| `VARF3` | Female | Warm, motherly | glinda |
| `VARF4` | Female | Youthful, dynamic | emily |
| `VARM0` | Male | Rich, baritone | **daniel** |
| `VARM1` | Male | Light, friendly | josh |
| `VARM2` | Male | Gruff, textured | arnold |
| `VARM3` | Male | Smooth, refined | sam |
| `VARM4` | Male | Casual, relaxed | ethan |

## How Voice Conditioning Works

PersonaPlex uses audio token embeddings to condition voice output:

1. Each preset is a `.pt` file containing pre-extracted audio token sequences
2. These tokens are fed to the model at the start of a session
3. The model's output speech adopts the vocal characteristics encoded in the embedding
4. Voice conditioning persists throughout the entire conversation session

## Routing Strategy

Use `voice_bridge.py` to maintain consistent persona across systems:

```python
from scripts.voice_bridge import VoiceBridge

bridge = VoiceBridge()

# For async voice messages → use ElevenLabs
elevenlabs_voice = bridge.get_elevenlabs_voice("NATF2")  # → "rachel"

# For real-time conversation → use PersonaPlex
personaplex_voice = bridge.get_personaplex_voice("rachel")  # → "NATF2"
```

### When to Use Which

| Use Case | System | Why |
|----------|--------|-----|
| Voice messages | ElevenLabs | Studio-quality, multilingual |
| Notifications | ElevenLabs | Quick, async, no GPU needed |
| Narration | ElevenLabs | Optimized for long-form |
| Live phone calls | **PersonaPlex** | Full-duplex, natural dynamics |
| Interactive demos | **PersonaPlex** | Real-time, low latency |
| Customer service | **PersonaPlex** | Handles interruptions, barge-ins |

## Custom Voice Embeddings

To create custom voice embeddings from audio samples:

1. Prepare a clean audio sample (10-30 seconds, 24kHz WAV)
2. Use the Mimi encoder to extract audio tokens
3. Save as a `.pt` file in the voices directory
4. Reference in server launch or offline evaluation

See the [PersonaPlex GitHub](https://github.com/NVIDIA/personaplex) for detailed instructions on voice embedding extraction.

## Audio Specifications

- **Sample Rate:** 24kHz
- **Codec:** Opus (for streaming), WAV (for offline)
- **Channels:** Mono (1 channel)
- **Bit Depth:** 16-bit (for WAV input/output)
