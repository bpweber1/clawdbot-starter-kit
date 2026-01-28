#!/usr/bin/env python3
"""
voice_bridge.py — Map between ElevenLabs voice names and PersonaPlex presets.

Maintains consistent persona identity across async TTS (ElevenLabs) and
real-time full-duplex conversation (PersonaPlex).

Usage:
    # List all mappings
    python voice_bridge.py --list

    # Look up a voice
    python voice_bridge.py --lookup rachel
    python voice_bridge.py --lookup NATM1

    # JSON output
    python voice_bridge.py --lookup rachel --json

    # As a Python module
    from voice_bridge import VoiceBridge
    bridge = VoiceBridge()
    bridge.get_personaplex_voice("rachel")  # → "NATF2"
    bridge.get_elevenlabs_voice("NATM1")    # → "adam"
"""

import argparse
import json
import sys


class VoiceBridge:
    """
    Bidirectional mapping between ElevenLabs voice names and PersonaPlex presets.

    Enables consistent voice persona across:
    - ElevenLabs: async TTS for voice messages, narration, notifications
    - PersonaPlex: real-time full-duplex conversation
    """

    # ElevenLabs voice name → PersonaPlex preset
    # Mapping based on vocal characteristics similarity
    ELEVENLABS_TO_PERSONAPLEX = {
        # Primary mappings (strong matches)
        "rachel":  "NATF2",   # Warm, friendly female → Natural Female 2
        "adam":    "NATM1",   # Smooth narrator male → Natural Male 1
        "george":  "NATM0",   # Deep, authoritative male → Natural Male 0
        "alice":   "NATF1",   # Warm, approachable female → Natural Female 1
        "brian":   "NATM2",   # Calm, reassuring male → Natural Male 2
        "charlie": "NATM3",   # Energetic, clear male → Natural Male 3
        "daniel":  "VARM0",   # Rich baritone male → Variety Male 0

        # Secondary mappings (reasonable matches)
        "bella":   "NATF3",   # Calm, measured female → Natural Female 3
        "elli":    "NATF0",   # Clear, professional female → Natural Female 0
        "josh":    "VARM1",   # Light, friendly male → Variety Male 1
        "arnold":  "VARM2",   # Gruff, textured male → Variety Male 2
        "sam":     "VARM3",   # Smooth, refined male → Variety Male 3
        "domi":    "VARF0",   # Bright, energetic female → Variety Female 0
        "grace":   "VARF1",   # Soft, gentle female → Variety Female 1
        "glinda":  "VARF3",   # Warm, motherly female → Variety Female 3
        "serena":  "VARF2",   # Confident, bold female → Variety Female 2
        "emily":   "VARF4",   # Youthful, dynamic female → Variety Female 4
        "ethan":   "VARM4",   # Casual, relaxed male → Variety Male 4
    }

    # PersonaPlex preset metadata
    PRESET_INFO = {
        # Natural female voices
        "NATF0": {"gender": "female", "category": "natural", "character": "Clear, professional"},
        "NATF1": {"gender": "female", "category": "natural", "character": "Warm, approachable"},
        "NATF2": {"gender": "female", "category": "natural", "character": "Friendly, engaging"},
        "NATF3": {"gender": "female", "category": "natural", "character": "Calm, measured"},
        # Natural male voices
        "NATM0": {"gender": "male", "category": "natural", "character": "Deep, authoritative"},
        "NATM1": {"gender": "male", "category": "natural", "character": "Smooth, narrative"},
        "NATM2": {"gender": "male", "category": "natural", "character": "Calm, reassuring"},
        "NATM3": {"gender": "male", "category": "natural", "character": "Energetic, clear"},
        # Variety female voices
        "VARF0": {"gender": "female", "category": "variety", "character": "Bright, energetic"},
        "VARF1": {"gender": "female", "category": "variety", "character": "Soft, gentle"},
        "VARF2": {"gender": "female", "category": "variety", "character": "Confident, bold"},
        "VARF3": {"gender": "female", "category": "variety", "character": "Warm, motherly"},
        "VARF4": {"gender": "female", "category": "variety", "character": "Youthful, dynamic"},
        # Variety male voices
        "VARM0": {"gender": "male", "category": "variety", "character": "Rich, baritone"},
        "VARM1": {"gender": "male", "category": "variety", "character": "Light, friendly"},
        "VARM2": {"gender": "male", "category": "variety", "character": "Gruff, textured"},
        "VARM3": {"gender": "male", "category": "variety", "character": "Smooth, refined"},
        "VARM4": {"gender": "male", "category": "variety", "character": "Casual, relaxed"},
    }

    def __init__(self):
        # Build reverse mapping: PersonaPlex → ElevenLabs
        self._pp_to_el: dict[str, str] = {}
        for el_name, pp_name in self.ELEVENLABS_TO_PERSONAPLEX.items():
            # First mapping wins (primary mappings are listed first)
            if pp_name not in self._pp_to_el:
                self._pp_to_el[pp_name] = el_name

    def get_personaplex_voice(self, name: str) -> str | None:
        """
        Get the PersonaPlex preset for a given voice name.

        Accepts ElevenLabs names (e.g., "rachel") or PersonaPlex presets (e.g., "NATF2").
        Returns the PersonaPlex preset name, or None if not found.
        """
        # Check if it's already a PersonaPlex preset
        upper = name.upper()
        if upper in self.PRESET_INFO:
            return upper

        # Check ElevenLabs mapping
        lower = name.lower()
        return self.ELEVENLABS_TO_PERSONAPLEX.get(lower)

    def get_elevenlabs_voice(self, name: str) -> str | None:
        """
        Get the ElevenLabs voice name for a given PersonaPlex preset.

        Accepts PersonaPlex presets (e.g., "NATM1") or ElevenLabs names (e.g., "adam").
        Returns the ElevenLabs voice name, or None if not mapped.
        """
        # Check if it's already an ElevenLabs name
        lower = name.lower()
        if lower in self.ELEVENLABS_TO_PERSONAPLEX:
            return lower

        # Check PersonaPlex → ElevenLabs mapping
        upper = name.upper()
        return self._pp_to_el.get(upper)

    def get_voice_info(self, name: str) -> dict | None:
        """Get full info for a voice (by any name)."""
        pp_name = self.get_personaplex_voice(name)
        if not pp_name:
            return None

        info = self.PRESET_INFO.get(pp_name, {}).copy()
        info["personaplex_preset"] = pp_name
        info["personaplex_file"] = f"{pp_name}.pt"
        info["elevenlabs_name"] = self.get_elevenlabs_voice(pp_name)
        return info

    def get_all_mappings(self) -> list[dict]:
        """Get all voice mappings as a list of dicts."""
        mappings = []
        for pp_name, info in self.PRESET_INFO.items():
            entry = info.copy()
            entry["personaplex_preset"] = pp_name
            entry["personaplex_file"] = f"{pp_name}.pt"
            entry["elevenlabs_name"] = self._pp_to_el.get(pp_name)
            mappings.append(entry)
        return mappings

    def get_voices_by_gender(self, gender: str) -> list[dict]:
        """Get all voices matching a gender (male/female)."""
        return [
            m for m in self.get_all_mappings()
            if m["gender"] == gender.lower()
        ]

    def get_voices_by_category(self, category: str) -> list[dict]:
        """Get all voices matching a category (natural/variety)."""
        return [
            m for m in self.get_all_mappings()
            if m["category"] == category.lower()
        ]

    def suggest_voice(self, description: str) -> str | None:
        """
        Suggest a PersonaPlex voice based on a text description.

        Looks for keywords in the description to match voice characteristics.
        """
        desc = description.lower()

        # Gender detection
        is_female = any(w in desc for w in ["female", "woman", "she", "her", "girl"])
        is_male = any(w in desc for w in ["male", "man", "he", "him", "boy"])

        # Character keywords
        keyword_map = {
            "warm": ["NATF2", "NATF1", "VARF3"],
            "friendly": ["NATF2", "NATM3", "VARM1"],
            "professional": ["NATF0", "NATM0"],
            "calm": ["NATF3", "NATM2", "VARF1"],
            "energetic": ["NATM3", "VARF0", "VARF4"],
            "deep": ["NATM0", "VARM0"],
            "authoritative": ["NATM0", "VARM0"],
            "gentle": ["VARF1", "NATF3"],
            "confident": ["VARF2", "NATM0"],
            "casual": ["VARM4", "VARF4"],
            "narrator": ["NATM1", "VARM3"],
            "smooth": ["NATM1", "VARM3"],
            "youthful": ["VARF4", "VARM1"],
        }

        candidates: dict[str, int] = {}
        for keyword, voices in keyword_map.items():
            if keyword in desc:
                for voice in voices:
                    candidates[voice] = candidates.get(voice, 0) + 1

        # Filter by gender if specified
        if is_female:
            candidates = {k: v for k, v in candidates.items() if k.startswith(("NATF", "VARF"))}
        elif is_male:
            candidates = {k: v for k, v in candidates.items() if k.startswith(("NATM", "VARM"))}

        if candidates:
            return max(candidates, key=candidates.get)

        # Default fallback
        if is_female:
            return "NATF2"
        elif is_male:
            return "NATM1"
        return "NATF2"


def print_mapping_table(bridge: VoiceBridge):
    """Print a formatted mapping table."""
    mappings = bridge.get_all_mappings()

    print()
    print("╔══════════════╦═══════════════╦══════════╦═══════════╦════════════════════════╗")
    print("║ PersonaPlex  ║ ElevenLabs    ║ Gender   ║ Category  ║ Character              ║")
    print("╠══════════════╬═══════════════╬══════════╬═══════════╬════════════════════════╣")

    for m in mappings:
        pp = m["personaplex_preset"]
        el = m["elevenlabs_name"] or "—"
        gender = m["gender"]
        cat = m["category"]
        char_ = m["character"]
        print(f"║ {pp:<12s} ║ {el:<13s} ║ {gender:<8s} ║ {cat:<9s} ║ {char_:<22s} ║")

    print("╚══════════════╩═══════════════╩══════════╩═══════════╩════════════════════════╝")
    print()


def parse_args():
    parser = argparse.ArgumentParser(
        description="Voice Bridge — map between ElevenLabs and PersonaPlex voices.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Show all mappings
  python voice_bridge.py --list

  # Look up by ElevenLabs name
  python voice_bridge.py --lookup rachel
  # → PersonaPlex: NATF2, Character: Friendly, engaging

  # Look up by PersonaPlex preset
  python voice_bridge.py --lookup NATM1
  # → ElevenLabs: adam, Character: Smooth, narrative

  # Suggest voice from description
  python voice_bridge.py --suggest "warm friendly female voice"
  # → NATF2

  # JSON output for scripting
  python voice_bridge.py --list --json
        """,
    )
    parser.add_argument(
        "--list", "-l",
        action="store_true",
        help="List all voice mappings",
    )
    parser.add_argument(
        "--lookup",
        type=str,
        help="Look up a voice by name (ElevenLabs or PersonaPlex)",
    )
    parser.add_argument(
        "--suggest",
        type=str,
        help="Suggest a PersonaPlex voice from a description",
    )
    parser.add_argument(
        "--gender",
        type=str,
        choices=["male", "female"],
        help="Filter by gender",
    )
    parser.add_argument(
        "--category",
        type=str,
        choices=["natural", "variety"],
        help="Filter by category",
    )
    parser.add_argument(
        "--json",
        action="store_true",
        help="Output as JSON",
    )
    return parser.parse_args()


def main():
    args = parse_args()
    bridge = VoiceBridge()

    if args.lookup:
        info = bridge.get_voice_info(args.lookup)
        if info:
            if args.json:
                print(json.dumps(info, indent=2))
            else:
                print(f"\nVoice: {args.lookup}")
                print(f"  PersonaPlex Preset: {info['personaplex_preset']}")
                print(f"  PersonaPlex File:   {info['personaplex_file']}")
                print(f"  ElevenLabs Name:    {info.get('elevenlabs_name') or '(no mapping)'}")
                print(f"  Gender:             {info['gender']}")
                print(f"  Category:           {info['category']}")
                print(f"  Character:          {info['character']}")
                print()
        else:
            print(f"Unknown voice: {args.lookup}", file=sys.stderr)
            sys.exit(1)

    elif args.suggest:
        suggestion = bridge.suggest_voice(args.suggest)
        if suggestion:
            info = bridge.get_voice_info(suggestion)
            if args.json:
                print(json.dumps({"suggestion": suggestion, "info": info}, indent=2))
            else:
                print(f"\nSuggested voice for \"{args.suggest}\":")
                print(f"  → {suggestion} ({info['character']})")
                el = info.get("elevenlabs_name")
                if el:
                    print(f"  ElevenLabs equivalent: {el}")
                print()
        else:
            print("Could not suggest a voice.", file=sys.stderr)
            sys.exit(1)

    elif args.list or args.gender or args.category:
        if args.gender:
            mappings = bridge.get_voices_by_gender(args.gender)
        elif args.category:
            mappings = bridge.get_voices_by_category(args.category)
        else:
            mappings = bridge.get_all_mappings()

        if args.json:
            print(json.dumps(mappings, indent=2))
        else:
            if args.gender or args.category:
                filter_label = args.gender or args.category
                print(f"\nFiltered by: {filter_label}")
                print("-" * 60)
                for m in mappings:
                    el = m.get("elevenlabs_name") or "—"
                    print(f"  {m['personaplex_preset']:<8s} ↔ {el:<12s}  {m['character']}")
                print()
            else:
                print_mapping_table(bridge)

    else:
        # Default: show table
        print_mapping_table(bridge)


if __name__ == "__main__":
    main()
