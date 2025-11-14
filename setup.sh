#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
#
# Quick setup script for new Linux/Wasm installations
# This script automates the entire build process

set -e

echo "========================================"
echo " Linux/Wasm Automated Setup"
echo "========================================"
echo ""

# Detect script location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Check prerequisites
echo "Checking prerequisites..."
command -v git >/dev/null 2>&1 || { echo "ERROR: git not found. Please install git."; exit 1; }
command -v python3 >/dev/null 2>&1 || { echo "ERROR: python3 not found. Please install python3."; exit 1; }
command -v cmake >/dev/null 2>&1 || { echo "ERROR: cmake not found. Please install cmake."; exit 1; }
command -v ninja >/dev/null 2>&1 || { echo "WARNING: ninja not found. Build will use make (slower)."; }
echo "✓ Prerequisites OK"
echo ""

# Prompt user for build type
echo "Select build configuration:"
echo ""
echo "1) Lightweight build (RECOMMENDED)"
echo "   - Fast boot time (1.3MB initramfs)"
echo "   - Separate toolchain volume (865MB)"
echo "   - Best for testing and iteration"
echo ""
echo "2) Full build"
echo "   - Slower boot (1.3GB initramfs)"
echo "   - Integrated toolchain"
echo "   - Complete development environment"
echo ""
echo "3) Build base only (LLVM + kernel + musl + busybox)"
echo "   - Core components only"
echo "   - You'll build rootfs manually later"
echo ""
read -p "Enter choice [1-3] (default: 1): " choice
choice="${choice:-1}"

echo ""
echo "Selected configuration: "
case "$choice" in
    1) echo "Lightweight build" ;;
    2) echo "Full build" ;;
    3) echo "Base components only" ;;
    *) echo "Invalid choice. Exiting."; exit 1 ;;
esac
echo ""

# Estimate time and disk space
echo "Build requirements:"
echo "  - Disk space: ~15GB (sources + build artifacts)"
echo "  - Build time: 30-90 minutes (depends on CPU)"
echo "  - RAM: 8GB+ recommended"
echo ""
read -p "Continue? [Y/n]: " confirm
confirm="${confirm:-Y}"
if [[ ! "$confirm" =~ ^[Yy] ]]; then
    echo "Aborted."
    exit 0
fi

echo ""
echo "========================================"
echo " Starting build process..."
echo "========================================"
echo ""

# Build base components
echo ">>> Step 1/5: Building base components"
echo ""
./linux-wasm.sh all

if [ $? -ne 0 ]; then
    echo ""
    echo "ERROR: Base build failed."
    echo "Check the error messages above."
    echo ""
    echo "Common issues:"
    echo "  - LLVM build fails on 2nd attempt: This is a known bug. Run again."
    echo "  - Out of disk space: Need ~15GB free"
    echo "  - Missing dependencies: Install build-essential, cmake, ninja"
    exit 1
fi

echo ""
echo "✓ Base components built successfully"
echo ""

# Build rootfs based on user choice
if [ "$choice" = "1" ]; then
    echo ">>> Step 2/5: Building lightweight rootfs"
    ./linux-wasm.sh all-lite
    
    echo ""
    echo ">>> Step 3/5: Deploying to runtime/"
    ./linux-wasm.sh deploy-lite
    
elif [ "$choice" = "2" ]; then
    echo ">>> Step 2/5: Building full rootfs"
    ./linux-wasm.sh all-full
    
    echo ""
    echo ">>> Step 3/5: Deploying to runtime/"
    ./linux-wasm.sh deploy-full
    
else
    echo ">>> Step 2/5: Skipping rootfs build (user choice)"
    echo ">>> Step 3/5: Skipping deployment"
fi

echo ""
echo "========================================"
echo " ✓ Build Complete!"
echo "========================================"
echo ""

# Show summary
echo "Build summary:"
echo ""
ls -lh runtime/*.wasm runtime/*.gz 2>/dev/null | awk '{print "  " $9 ": " $5}'
echo ""

if [ "$choice" != "3" ]; then
    echo "To run Linux/Wasm:"
    echo ""
    echo "  cd runtime"
    echo "  python3 server.py 8000"
    echo ""
    echo "Then open your browser to: http://127.0.0.1:8000/"
    echo ""
    echo "Note: Use Chrome or Edge for best WebAssembly debugging support."
    echo ""
else
    echo "Base components are ready."
    echo "Build a rootfs with:"
    echo "  ./linux-wasm.sh all-lite && ./linux-wasm.sh deploy-lite"
    echo "or"
    echo "  ./linux-wasm.sh all-full && ./linux-wasm.sh deploy-full"
    echo ""
fi

echo "Documentation:"
echo "  README.md - Overview and usage"
echo "  BUILD_STATUS.md - Current status and known issues"
echo "  DESKTOP_ROADMAP.md - Future desktop environment plans"
echo ""
echo "Happy hacking!"
