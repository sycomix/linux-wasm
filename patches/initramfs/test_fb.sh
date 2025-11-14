#!/bin/sh
# Simple framebuffer test using dd and /dev/zero

echo "Testing framebuffer /dev/fb0..."

# Check if framebuffer device exists
if [ ! -c /dev/fb0 ]; then
    echo "Error: /dev/fb0 not found"
    exit 1
fi

echo "Filling framebuffer with white..."
# 800x600x4 = 1920000 bytes
dd if=/dev/zero bs=1920000 count=1 2>/dev/null | tr '\0' '\377' > /dev/fb0

echo "Framebuffer test complete!"
echo "You should see a white screen on the canvas"
