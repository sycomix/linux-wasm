#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
#
# Build a separate toolchain volume that can be mounted after boot
# This keeps the main initramfs small and fast to load

set -e

LW_ROOT="${LW_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
LW_WORKSPACE="${LW_WORKSPACE:-$LW_ROOT/workspace}"
LW_INSTALL="${LW_INSTALL:-$LW_WORKSPACE/install}"
LW_TOOLCHAIN_VOL="${LW_TOOLCHAIN_VOL:-$LW_WORKSPACE/toolchain-volume}"

LLVM_PREFIX="$LW_INSTALL/llvm"
MUSL_PREFIX="$LW_INSTALL/musl"

echo "================================================"
echo "Linux/Wasm Toolchain Volume Builder"
echo "================================================"

mkdir -p "$LW_TOOLCHAIN_VOL"/{opt,usr/src}

echo "==> Copying LLVM toolchain"
if [ -d "$LLVM_PREFIX" ]; then
    mkdir -p "$LW_TOOLCHAIN_VOL/opt/llvm"
    echo "  This will take a moment..."
    cp -r "$LLVM_PREFIX"/* "$LW_TOOLCHAIN_VOL/opt/llvm/"
    echo "✓ LLVM copied"
else
    echo "ERROR: LLVM not found at $LLVM_PREFIX"
    exit 1
fi

echo "==> Copying kernel sources and patches"
mkdir -p "$LW_TOOLCHAIN_VOL/usr/src/linux-wasm"
cp -r "$LW_ROOT/patches" "$LW_TOOLCHAIN_VOL/usr/src/linux-wasm/"
cp "$LW_ROOT"/*.sh "$LW_TOOLCHAIN_VOL/usr/src/linux-wasm/" 2>/dev/null || true
cp "$LW_ROOT"/*.md "$LW_TOOLCHAIN_VOL/usr/src/linux-wasm/" 2>/dev/null || true

echo "==> Creating helper scripts"

cat > "$LW_TOOLCHAIN_VOL/opt/llvm/setup-env.sh" <<'EOF'
#!/bin/sh
# Source this file to set up the development environment

export PATH="/opt/llvm/bin:$PATH"
export CC="/opt/llvm/bin/clang"
export CXX="/opt/llvm/bin/clang++"
export AR="/opt/llvm/bin/llvm-ar"
export NM="/opt/llvm/bin/llvm-nm"
export RANLIB="/opt/llvm/bin/llvm-ranlib"
export STRIP="/opt/llvm/bin/llvm-strip"

export CFLAGS="--target=wasm32-unknown-unknown -mmutable-globals -Xclang -target-feature -Xclang +atomics -Xclang -target-feature -Xclang +bulk-memory -fPIC"
export LDFLAGS="-Wl,-shared"

echo "LLVM toolchain environment configured"
echo "Compiler: $(clang --version | head -1)"
EOF
chmod +x "$LW_TOOLCHAIN_VOL/opt/llvm/setup-env.sh"

cat > "$LW_TOOLCHAIN_VOL/opt/llvm/bin/wasm-gcc" <<'EOF'
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
chmod +x "$LW_TOOLCHAIN_VOL/opt/llvm/bin/wasm-gcc"

cat > "$LW_TOOLCHAIN_VOL/README.txt" <<'EOF'
===========================================
Linux/Wasm Toolchain Volume
===========================================

This volume contains the LLVM toolchain and kernel sources.

MOUNTING
--------
This volume should be mounted at /opt:
    mount -t ramfs /dev/toolchain /opt

Or use the helper script in the main system:
    /usr/local/bin/mount-toolchain

SETUP
-----
After mounting, source the environment:
    . /opt/llvm/setup-env.sh

Or add to your profile:
    echo '. /opt/llvm/setup-env.sh' >> ~/.profile

USAGE
-----
Compile programs with wasm-gcc:
    wasm-gcc hello.c -o hello

Or use clang directly:
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
Full kernel source with patches:
    /usr/src/linux-wasm/

===========================================
EOF

echo "==> Creating toolchain archive"
mkdir -p "$LW_INSTALL/volumes"
cd "$LW_TOOLCHAIN_VOL"
tar czf "$LW_INSTALL/volumes/toolchain.tar.gz" .

echo ""
echo "================================================"
echo "✓ Toolchain volume created!"
echo "================================================"
echo ""
ls -lh "$LW_INSTALL/volumes/toolchain.tar.gz"
echo ""
echo "This will be loaded as a separate volume in the browser."
echo ""
