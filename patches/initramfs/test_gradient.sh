#!/bin/sh
# Draw a gradient pattern to framebuffer

echo "Drawing gradient pattern..."

# Constants
WIDTH=800
HEIGHT=600
FB=/dev/fb0

# Clear screen to black first
dd if=/dev/zero of=$FB bs=1920000 count=1 2>/dev/null

# Draw horizontal color gradient (requires writing each pixel)
# This is a simplified version - writes stripes instead of smooth gradient
echo "Drawing color stripes..."

y=0
while [ $y -lt $HEIGHT ]; do
    # Calculate color based on Y position
    if [ $y -lt 100 ]; then
        # Red stripe
        COLOR="\000\000\377\377"
    elif [ $y -lt 200 ]; then
        # Green stripe  
        COLOR="\000\377\000\377"
    elif [ $y -lt 300 ]; then
        # Blue stripe
        COLOR="\377\000\000\377"
    elif [ $y -lt 400 ]; then
        # Yellow stripe
        COLOR="\000\377\377\377"
    elif [ $y -lt 500 ]; then
        # Cyan stripe
        COLOR="\377\377\000\377"
    else
        # Magenta stripe
        COLOR="\377\000\377\377"
    fi
    
    # Write one row (this is slow but works)
    x=0
    while [ $x -lt $WIDTH ]; do
        printf "$COLOR"
        x=$((x + 1))
    done > /tmp/row_$y
    
    # Progress indicator
    if [ $((y % 100)) -eq 0 ]; then
        echo "Row $y..."
    fi
    
    y=$((y + 1))
done

# Concatenate all rows and write to framebuffer
cat /tmp/row_* > $FB 2>/dev/null
rm -f /tmp/row_*

echo "Gradient complete!"
