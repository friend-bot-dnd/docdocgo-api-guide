#!/bin/bash
# Quick Edge TTS helper
# Usage: ./tts.sh "Text to speak" [voice_name]
#        ./tts.sh -f file.txt [voice_name]

VOICE="${2:-en-US-AndrewNeural}"
OUTPUT="/tmp/tts_$(date +%s).mp3"

if [ "$1" = "-f" ]; then
    python3 -m edge_tts --voice "$VOICE" --file "$3" --write-media "$OUTPUT"
else
    python3 -m edge_tts --voice "$VOICE" --text "$1" --write-media "$OUTPUT"
fi

echo "✅ TTS saved to: $OUTPUT"
echo "   Voice: $VOICE"
ls -lh "$OUTPUT"
