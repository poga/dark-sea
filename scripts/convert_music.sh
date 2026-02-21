#!/usr/bin/env bash
# Convert audio files to OGG Vorbis suitable for Godot.
#
# Usage:
#   ./scripts/convert_music.sh                     # convert all .wav in assets/music/ and assets/sfx/
#   ./scripts/convert_music.sh input.wav [output.ogg]  # convert a single file

set -euo pipefail

if ! command -v ffmpeg &>/dev/null; then
    echo "Error: ffmpeg not found. Install with: brew install ffmpeg"
    exit 1
fi

convert_file() {
    local input="$1"
    local output="$2"

    if [ -f "$output" ]; then
        echo "Skipping (already exists): $output"
        return
    fi

    ffmpeg -y -i "$input" \
        -strict -2 \
        -c:a vorbis \
        -q:a 6 \
        -ar 44100 \
        -ac 2 \
        "$output"

    echo "Converted: $output"
}

# Batch mode: no arguments — convert all .wav files in assets/music/ and assets/sfx/
if [ $# -eq 0 ]; then
    count=0
    for dir in assets/music assets/sfx; do
        for wav in "$dir"/*.wav; do
            [ -f "$wav" ] || continue
            ogg="${wav%.wav}.ogg"
            convert_file "$wav" "$ogg"
            count=$((count + 1))
        done
    done

    if [ "$count" -eq 0 ]; then
        echo "No .wav files found in assets/music/ or assets/sfx/"
    else
        echo "Done: converted $count file(s)"
    fi
    exit 0
fi

# Single-file mode
INPUT="$1"
BASENAME=$(basename "${INPUT%.*}")
OUTPUT="${2:-assets/music/${BASENAME}.ogg}"

convert_file "$INPUT" "$OUTPUT"
