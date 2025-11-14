#!/bin/bash
# Quick build and test script for Phase 2 Input Subsystem
# Run this after creating all the patches and JavaScript files

set -e

echo "=================================="
echo "Phase 2 Input Subsystem - Build"
echo "=================================="
echo

# Step 1: Apply patches to kernel
echo "[1/5] Applying kernel patches..."
if [ -d "workspace/src/kernel" ]; then
    echo "  Kernel source exists, applying patches manually..."
    cd workspace/src/kernel
    
    # Check if patches already applied
    if git log --oneline | grep -q "Add Wasm input support"; then
        echo "  ⚠️  Input patches already applied, skipping..."
    else
        echo "  Applying 0015-Add-Wasm-input-support.patch..."
        git am < ../../../patches/kernel/0015-Add-Wasm-input-support.patch
        
        echo "  Applying 0016-Update-wasm_defconfig-for-input.patch..."
        git am < ../../../patches/kernel/0016-Update-wasm_defconfig-for-input.patch
    fi
    cd ../../..
else
    echo "  Kernel source not found, fetching with patches..."
    ./linux-wasm.sh fetch-kernel
fi
echo "  ✓ Patches applied"
echo

# Step 2: Build kernel
echo "[2/5] Building kernel with input drivers..."
./linux-wasm.sh build-kernel
echo "  ✓ Kernel built"
echo

# Step 3: Verify exports
echo "[3/5] Verifying kernel exports..."
LLVM_NM="workspace/install/llvm/bin/llvm-nm"
VMLINUX="workspace/build/kernel/vmlinux"

if [ -f "$VMLINUX" ]; then
    if $LLVM_NM $VMLINUX | grep -q "wasm_input_keyboard_event"; then
        echo "  ✓ wasm_input_keyboard_event exported"
    else
        echo "  ✗ ERROR: wasm_input_keyboard_event not found!"
        exit 1
    fi
    
    if $LLVM_NM $VMLINUX | grep -q "wasm_input_mouse_event"; then
        echo "  ✓ wasm_input_mouse_event exported"
    else
        echo "  ✗ ERROR: wasm_input_mouse_event not found!"
        exit 1
    fi
else
    echo "  ✗ ERROR: vmlinux not found at $VMLINUX"
    exit 1
fi
echo

# Step 4: Copy artifacts to runtime
echo "[4/5] Copying artifacts to runtime..."
cp workspace/install/kernel/vmlinux.wasm runtime/
echo "  ✓ Copied vmlinux.wasm"

if [ -f "workspace/install/initramfs/initramfs.cpio.gz" ]; then
    cp workspace/install/initramfs/initramfs.cpio.gz runtime/
    echo "  ✓ Copied initramfs.cpio.gz"
else
    echo "  ⚠️  initramfs not found, you may need to run: ./linux-wasm.sh build-initramfs"
fi
echo

# Step 5: Verify JavaScript files
echo "[5/5] Verifying JavaScript files..."
RUNTIME_FILES=(
    "runtime/input-handler.js"
    "runtime/linux.js"
    "runtime/linux-worker.js"
    "runtime/index.html"
)

for file in "${RUNTIME_FILES[@]}"; do
    if [ -f "$file" ]; then
        echo "  ✓ $file exists"
    else
        echo "  ✗ ERROR: $file not found!"
        exit 1
    fi
done
echo

echo "=================================="
echo "Build Complete!"
echo "=================================="
echo
echo "To test the system:"
echo "  1. cd runtime"
echo "  2. python3 server.py 8000"
echo "  3. Open http://127.0.0.1:8000/"
echo
echo "Expected behavior:"
echo "  - System boots to shell"
echo "  - Framebuffer activates (canvas appears)"
echo "  - Keyboard input works in console"
echo "  - Mouse events detected (check dmesg)"
echo
echo "Testing commands (after boot):"
echo "  ls -l /dev/input/           # Check device nodes"
echo "  dmesg | grep -i input       # Verify drivers loaded"
echo "  hexdump -C /dev/input/event0 # Monitor keyboard"
echo "  hexdump -C /dev/input/event1 # Monitor mouse"
echo
echo "See INPUT_TESTING_GUIDE.md for comprehensive testing"
echo
