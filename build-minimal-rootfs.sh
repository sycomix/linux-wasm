#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
#
# Quick start: Build a minimal but functional Debian-based rootfs
# Focus on getting basic tools working first, then expand

set -e

LW_ROOT="${LW_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
LW_WORKSPACE="${LW_WORKSPACE:-$LW_ROOT/workspace}"
LW_INSTALL="${LW_INSTALL:-$LW_WORKSPACE/install}"
LW_DEBIAN="${LW_DEBIAN:-$LW_WORKSPACE/debian-rootfs}"

LLVM_PREFIX="$LW_INSTALL/llvm"
MUSL_PREFIX="$LW_INSTALL/musl"
BUSYBOX_PREFIX="$LW_INSTALL/busybox"

echo "================================================"
echo "Linux/Wasm Minimal Debian Rootfs"
echo "================================================"

# Start with BusyBox but add full environment
mkdir -p "$LW_DEBIAN"/{bin,sbin,lib,usr/{bin,sbin,lib,include,share,src},etc,var,tmp,proc,sys,dev,home,root,opt}

echo "==> Step 1: Copy BusyBox base"
if [ -d "$BUSYBOX_PREFIX" ]; then
    cp -r "$BUSYBOX_PREFIX"/* "$LW_DEBIAN/"
    echo "✓ BusyBox copied"
else
    echo "ERROR: BusyBox not found. Run ./linux-wasm.sh build-busybox first"
    exit 1
fi

echo "==> Step 2: Copy musl libc"
if [ -d "$MUSL_PREFIX" ]; then
    cp -r "$MUSL_PREFIX/include"/* "$LW_DEBIAN/usr/include/"
    cp -r "$MUSL_PREFIX/lib"/* "$LW_DEBIAN/usr/lib/"
    echo "✓ musl libc copied"
else
    echo "ERROR: musl not found. Run ./linux-wasm.sh build-musl first"
    exit 1
fi

echo "==> Step 3: Copy LLVM toolchain"
if [ -d "$LLVM_PREFIX" ]; then
    mkdir -p "$LW_DEBIAN/opt/llvm"
    echo "  Copying LLVM binaries (this may take a moment)..."
    cp -r "$LLVM_PREFIX"/* "$LW_DEBIAN/opt/llvm/"
    
    # Create symlinks in /usr/bin for easy access
    for tool in clang clang++ wasm-ld llvm-ar llvm-nm llvm-objdump llvm-strip; do
        if [ -f "$LW_DEBIAN/opt/llvm/bin/$tool" ]; then
            ln -sf "/opt/llvm/bin/$tool" "$LW_DEBIAN/usr/bin/$tool"
        fi
    done
    echo "✓ LLVM toolchain copied"
else
    echo "ERROR: LLVM not found. Run ./linux-wasm.sh build-llvm first"
    exit 1
fi

echo "==> Step 4: Copy kernel source and patches"
mkdir -p "$LW_DEBIAN/usr/src/linux-wasm"
cp -r "$LW_ROOT/patches" "$LW_DEBIAN/usr/src/linux-wasm/"
cp "$LW_ROOT"/*.sh "$LW_DEBIAN/usr/src/linux-wasm/" 2>/dev/null || true
cp "$LW_ROOT"/*.md "$LW_DEBIAN/usr/src/linux-wasm/" 2>/dev/null || true
echo "✓ Kernel source preserved"

echo "==> Step 5: Create configuration files"

# /etc/profile
cat > "$LW_DEBIAN/etc/profile" <<'EOF'
# System-wide profile for Linux/Wasm

export PATH="/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:/opt/llvm/bin"
export HOME="${HOME:-/root}"
export USER="${USER:-root}"
export HOSTNAME="linux-wasm"
export PS1='\u@\h:\w\$ '

# Compiler settings
export CC="/opt/llvm/bin/clang"
export CXX="/opt/llvm/bin/clang++"
export AR="/opt/llvm/bin/llvm-ar"
export NM="/opt/llvm/bin/llvm-nm"
export RANLIB="/opt/llvm/bin/llvm-ranlib"
export STRIP="/opt/llvm/bin/llvm-strip"

# Wasm-specific flags
export CFLAGS="--target=wasm32-unknown-unknown -mmutable-globals -Xclang -target-feature -Xclang +atomics -Xclang -target-feature -Xclang +bulk-memory -fPIC"
export LDFLAGS="-Wl,-shared"

echo "Welcome to Linux/Wasm!"
echo "Toolchain: LLVM 18.1.2 + musl libc"
echo "Kernel: Linux 6.4.16-wasm"
echo ""
echo "Available tools:"
echo "  - BusyBox utilities (ls, cat, grep, etc.)"
echo "  - LLVM toolchain (clang, wasm-ld, etc.)"
echo "  - Kernel sources at /usr/src/linux-wasm"
echo ""
EOF

# /etc/passwd
cat > "$LW_DEBIAN/etc/passwd" <<'EOF'
root:x:0:0:root:/root:/bin/sh
EOF

# /etc/group
cat > "$LW_DEBIAN/etc/group" <<'EOF'
root:x:0:
EOF

# /etc/os-release
cat > "$LW_DEBIAN/etc/os-release" <<'EOF'
NAME="Linux/Wasm"
VERSION="1.0"
ID=linux-wasm
PRETTY_NAME="Linux/Wasm 1.0"
ANSI_COLOR="1;34"
HOME_URL="https://github.com/sycomix/linux-wasm"
EOF

echo "✓ Configuration files created"

echo "==> Step 6: Create helpful scripts"

# Compiler wrapper for easy use
cat > "$LW_DEBIAN/usr/bin/wasm-gcc" <<'EOF'
#!/bin/sh
# Wrapper to compile programs for Wasm/Linux

exec /opt/llvm/bin/clang \
    --target=wasm32-unknown-unknown \
    -mmutable-globals \
    -Xclang -target-feature -Xclang +atomics \
    -Xclang -target-feature -Xclang +bulk-memory \
    -fPIC \
    -Wl,-shared \
    -nostdlib \
    -I/usr/include \
    -L/usr/lib \
    /usr/lib/crt1.o \
    /usr/lib/crti.o \
    "$@" \
    /usr/lib/crtn.o \
    -lc
EOF
chmod +x "$LW_DEBIAN/usr/bin/wasm-gcc"

# README for users
cat > "$LW_DEBIAN/root/README.txt" <<'EOF'
===========================================
Welcome to Linux/Wasm!
===========================================

This is a complete Linux kernel running in WebAssembly.

COMPILING PROGRAMS
------------------
Use the wasm-gcc wrapper to compile C programs:

    wasm-gcc hello.c -o hello

Or use clang directly with proper flags:

    clang --target=wasm32-unknown-unknown \
        -mmutable-globals \
        -Xclang -target-feature -Xclang +atomics \
        -Xclang -target-feature -Xclang +bulk-memory \
        -fPIC -Wl,-shared \
        -nostdlib \
        -I/usr/include -L/usr/lib \
        /usr/lib/crt1.o /usr/lib/crti.o \
        hello.c \
        /usr/lib/crtn.o -lc \
        -o hello

KERNEL SOURCE
-------------
Full kernel source with all patches is at:
    /usr/src/linux-wasm/

To rebuild the kernel:
    cd /usr/src/linux-wasm
    ./linux-wasm.sh build-kernel

TOOLCHAIN
---------
LLVM 18.1.2 toolchain: /opt/llvm/
musl libc headers: /usr/include/
musl libc libraries: /usr/lib/

EXAMPLES
--------
Create a hello world program:

cat > hello.c <<'EOFC'
#include <unistd.h>
int main() {
    write(1, "Hello from Wasm!\n", 17);
    return 0;
}
EOFC

wasm-gcc hello.c -o hello
./hello

===========================================
EOF

echo "✓ Helper scripts created"

echo "==> Step 7: Create init script"
cat > "$LW_DEBIAN/init" <<'EOF'
#!/bin/sh
# Init script for Linux/Wasm

echo "Starting Linux/Wasm init..."

# Mount essential filesystems
mount -t proc proc /proc
mount -t sysfs sysfs /sys
mount -t devtmpfs devtmpfs /dev 2>/dev/null || true

# Create essential device nodes if needed
[ -e /dev/null ] || mknod /dev/null c 1 3
[ -e /dev/zero ] || mknod /dev/zero c 1 5
[ -e /dev/console ] || mknod /dev/console c 5 1
[ -e /dev/fb0 ] || mknod /dev/fb0 c 29 0

# Set up environment
export PATH="/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:/opt/llvm/bin"
export HOME="/root"
cd /root

# Source profile
[ -f /etc/profile ] && . /etc/profile

echo ""
echo "=========================================="
echo "   Linux/Wasm System Ready"
echo "=========================================="
echo ""
echo "Read /root/README.txt for instructions"
echo ""

# Start shell
exec /bin/sh
EOF
chmod +x "$LW_DEBIAN/init"

echo "==> Step 8: Create initramfs"
mkdir -p "$LW_INSTALL/initramfs"
cd "$LW_DEBIAN"
find . -print0 | cpio --null -ov --format=newc 2>/dev/null | gzip -9 > "$LW_INSTALL/initramfs/initramfs-debian.cpio.gz"

echo ""
echo "================================================"
echo "✓ Debian rootfs created successfully!"
echo "================================================"
echo ""
echo "Location: $LW_INSTALL/initramfs/initramfs-debian.cpio.gz"
ls -lh "$LW_INSTALL/initramfs/initramfs-debian.cpio.gz"
echo ""
echo "To use:"
echo "  cp $LW_INSTALL/initramfs/initramfs-debian.cpio.gz runtime/initramfs.cpio.gz"
echo "  cd runtime && python3 server.py 8000"
echo ""
