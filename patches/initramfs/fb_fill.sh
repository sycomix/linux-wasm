#!/bin/sh
# Simple framebuffer fill - no functions, just direct writes

case "$1" in
    red)
        echo "Filling with red..."
        # Red in BGRA: 0x00 0x00 0xFF 0xFF
        yes "$(printf '\000\000\377\377')" | head -c 1920000 > /dev/fb0
        ;;
    green)
        echo "Filling with green..."
        # Green in BGRA: 0x00 0xFF 0x00 0xFF
        yes "$(printf '\000\377\000\377')" | head -c 1920000 > /dev/fb0
        ;;
    blue)
        echo "Filling with blue..."
        # Blue in BGRA: 0xFF 0x00 0x00 0xFF
        yes "$(printf '\377\000\000\377')" | head -c 1920000 > /dev/fb0
        ;;
    white)
        echo "Filling with white..."
        # White in BGRA: 0xFF 0xFF 0xFF 0xFF
        yes "$(printf '\377\377\377\377')" | head -c 1920000 > /dev/fb0
        ;;
    black)
        echo "Filling with black..."
        # Black in BGRA: 0x00 0x00 0x00 0xFF
        yes "$(printf '\000\000\000\377')" | head -c 1920000 > /dev/fb0
        ;;
    *)
        echo "Usage: fb_fill [red|green|blue|white|black]"
        echo "Fills 800x600 framebuffer with solid color"
        ;;
esac
