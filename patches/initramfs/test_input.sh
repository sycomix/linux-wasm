#!/bin/sh
# Test input system devices

echo "=== Input System Test ==="
echo

echo "Checking /proc/bus/input/devices:"
if [ -f /proc/bus/input/devices ]; then
    cat /proc/bus/input/devices
else
    echo "  /proc/bus/input/devices not found"
fi
echo

echo "Checking /dev/input/:"
ls -la /dev/input/ 2>/dev/null || echo "  /dev/input/ not found"
echo

echo "Checking /sys/class/input/:"
ls -la /sys/class/input/ 2>/dev/null || echo "  /sys/class/input/ not found"
echo

echo "Press any key to test keyboard (Ctrl+C to exit)..."
