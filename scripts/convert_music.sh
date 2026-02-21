#!/usr/bin/env bash
# Convert a WAV/MP3/FLAC file to OGG Vorbis suitable for Godot music stems.
# Usage: ./scripts/convert_music.sh input.wav [output.ogg]
#
# Output defaults to same name with .ogg extension in assets/music/

set -euo pipefail

if [ $# -lt 1 ]; then
    echo "Usage: $0 <input_file> [output.ogg]"
    exit 1
fi

INPUT="$1"
BASENAME=$(basename "${INPUT%.*}")
OUTPUT="${2:-assets/music/${BASENAME}.ogg}"

if ! command -v ffmpeg &>/dev/null; then
    echo "Error: ffmpeg not found. Install with: brew install ffmpeg"
    exit 1
fi

ffmpeg -y -i "$INPUT" \
    -strict -2 \
    -c:a vorbis \
    -q:a 6 \
    -ar 44100 \
    -ac 2 \
    "$OUTPUT"

echo "Converted: $OUTPUT"
