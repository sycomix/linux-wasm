#!/bin/sh
# Framebuffer drawing toolkit

FB=/dev/fb0
WIDTH=800
HEIGHT=600
PIXELS=480000

# Fill screen with color (BGRA format)
# Usage: fb_fill B G R A
fb_fill() {
    local b=$1 g=$2 r=$3 a=$4
    local pixel=$(printf "\\x$(printf '%02x' $b)\\x$(printf '%02x' $g)\\x$(printf '%02x' $r)\\x$(printf '%02x' $a)")
    
    # Write pixels in chunks using printf (shell built-in, no vfork)
    local i=0
    local chunk=""
    
    # Build a chunk of 1000 pixels
    while [ $i -lt 1000 ]; do
        chunk="$chunk$pixel"
        i=$((i + 1))
    done
    
    # Write 480 chunks to fill the screen
    i=0
    while [ $i -lt 480 ]; do
        printf "%s" "$chunk"
        i=$((i + 1))
    done > $FB
}

# Test patterns
case "$1" in
    white)
        echo "Filling with white..."
        fb_fill 255 255 255 255
        ;;
    black)
        echo "Filling with black..."
        fb_fill 0 0 0 255
        ;;
    red)
        echo "Filling with red..."
        fb_fill 0 0 255 255
        ;;
    green)
        echo "Filling with green..."
        fb_fill 0 255 0 255
        ;;
    blue)
        echo "Filling with blue..."
        fb_fill 255 0 0 255
        ;;
    checker)
        echo "Drawing checkerboard..."
        test_simple
        ;;
    *)
        echo "Framebuffer drawing toolkit"
        echo "Usage: fb_draw [white|black|red|green|blue|checker]"
        echo
        echo "Examples:"
        echo "  fb_draw white   - fill screen with white"
        echo "  fb_draw red     - fill screen with red"
        echo "  fb_draw checker - draw checkerboard pattern"
        ;;
esac
