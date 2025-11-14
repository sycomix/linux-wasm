#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
#
# Build a lightweight rootfs for testing (without LLVM toolchain)
# Use this for faster loading and testing, then switch to full version for development

set -e

LW_ROOT="${LW_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
LW_WORKSPACE="${LW_WORKSPACE:-$LW_ROOT/workspace}"
LW_INSTALL="${LW_INSTALL:-$LW_WORKSPACE/install}"
LW_DEBIAN_LITE="${LW_DEBIAN_LITE:-$LW_WORKSPACE/debian-rootfs-lite}"

MUSL_PREFIX="$LW_INSTALL/musl"
BUSYBOX_PREFIX="$LW_INSTALL/busybox"

echo "================================================"
echo "Linux/Wasm Lightweight Rootfs (No Toolchain)"
echo "================================================"

mkdir -p "$LW_DEBIAN_LITE"/{bin,sbin,lib,usr/{bin,sbin,lib,include,share},etc,var,tmp,proc,sys,dev,home,root}

echo "==> Copying BusyBox"
cp -r "$BUSYBOX_PREFIX"/* "$LW_DEBIAN_LITE/"

echo "==> Copying musl libc"
cp -r "$MUSL_PREFIX/include"/* "$LW_DEBIAN_LITE/usr/include/"
cp -r "$MUSL_PREFIX/lib"/* "$LW_DEBIAN_LITE/usr/lib/"

echo "==> Creating configuration files"

cat > "$LW_DEBIAN_LITE/etc/profile" <<'EOF'
export PATH="/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
export HOME="${HOME:-/root}"
export USER="${USER:-root}"
export HOSTNAME="linux-wasm"
export PS1='\u@\h:\w\$ '

echo "Welcome to Linux/Wasm (Lightweight)"
echo ""
if [ -d /opt/llvm ]; then
    echo "Toolchain: LLVM available at /opt/llvm"
    export PATH="/opt/llvm/bin:$PATH"
else
    echo "Toolchain: Not mounted. Run 'mount-toolchain' to load it."
fi
echo ""
EOF

cat > "$LW_DEBIAN_LITE/etc/passwd" <<'EOF'
root:x:0:0:root:/root:/bin/sh
EOF

cat > "$LW_DEBIAN_LITE/etc/group" <<'EOF'
root:x:0:
EOF

cat > "$LW_DEBIAN_LITE/etc/os-release" <<'EOF'
NAME="Linux/Wasm Lite"
VERSION="1.0"
ID=linux-wasm-lite
PRETTY_NAME="Linux/Wasm 1.0 (Lightweight)"
ANSI_COLOR="1;32"
EOF

echo "==> Creating helper scripts"
mkdir -p "$LW_DEBIAN_LITE/usr/local/bin"

cat > "$LW_DEBIAN_LITE/usr/local/bin/mount-toolchain" <<'EOF'
#!/bin/sh
# Mount the toolchain volume from a URL or local file

if [ -d /opt/llvm ]; then
    echo "Toolchain already mounted at /opt/llvm"
    exit 0
fi

echo "Loading toolchain volume..."
echo "This feature requires the toolchain.tar.gz to be available."
echo ""
echo "For now, toolchain must be built into initramfs."
echo "Virtual volume loading from URLs will be implemented soon."
exit 1
EOF
chmod +x "$LW_DEBIAN_LITE/usr/local/bin/mount-toolchain"

cat > "$LW_DEBIAN_LITE/root/README.txt" <<'EOF'
===========================================
Welcome to Linux/Wasm!
===========================================

LIGHTWEIGHT BUILD
-----------------
This is a lightweight build with BusyBox and musl libc.
The LLVM toolchain can be loaded separately.

LOADING TOOLCHAIN
-----------------
To load the development toolchain:
    mount-toolchain

(Note: Virtual volume mounting is being implemented)

AVAILABLE NOW
-------------
- BusyBox utilities (ls, cat, grep, etc.)
- musl libc headers and libraries
- Shell scripting

COMPILING PROGRAMS
------------------
Once the toolchain is loaded, compile with:
    wasm-gcc hello.c -o hello

===========================================
EOF

echo "==> Creating init script"
cat > "$LW_DEBIAN_LITE/init" <<'EOF'
#!/bin/sh

echo "Starting Linux/Wasm init..."

mount -t proc proc /proc
mount -t sysfs sysfs /sys
mount -t devtmpfs devtmpfs /dev 2>/dev/null || true

[ -e /dev/null ] || mknod /dev/null c 1 3
[ -e /dev/zero ] || mknod /dev/zero c 1 5
[ -e /dev/console ] || mknod /dev/console c 5 1
[ -e /dev/fb0 ] || mknod /dev/fb0 c 29 0

# Create mount point for toolchain volume
mkdir -p /opt

export PATH="/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
export HOME="/root"
cd /root

[ -f /etc/profile ] && . /etc/profile

echo ""
echo "=========================================="
echo "   Linux/Wasm System Ready"
echo "=========================================="
echo ""
echo "Tip: Read /root/README.txt for instructions"
echo ""

exec /bin/sh
EOF
chmod +x "$LW_DEBIAN_LITE/init"

echo "==> Creating initramfs"
mkdir -p "$LW_INSTALL/initramfs"
cd "$LW_DEBIAN_LITE"
find . -print0 | cpio --null -ov --format=newc 2>/dev/null | gzip -9 > "$LW_INSTALL/initramfs/initramfs-lite.cpio.gz"

echo ""
echo "✓ Lightweight rootfs created!"
echo ""
ls -lh "$LW_INSTALL/initramfs/initramfs-lite.cpio.gz"
echo ""
echo "To use:"
echo "  cp $LW_INSTALL/initramfs/initramfs-lite.cpio.gz runtime/initramfs.cpio.gz"
echo ""
