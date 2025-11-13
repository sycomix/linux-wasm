#!/bin/sh
# Ultra-simple framebuffer test

echo "Direct write to framebuffer..."

# Write some data directly using echo and redirection
# This creates a small colored rectangle at the top
printf '\377\377\377\377' > /dev/fb0  # One white pixel
printf '\000\000\377\377' >> /dev/fb0 # One red pixel  
printf '\000\377\000\377' >> /dev/fb0 # One green pixel
printf '\377\000\000\377' >> /dev/fb0 # One blue pixel

echo "Test pixels written to /dev/fb0"
