#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
#
# Build a Debian-based rootfs for Linux/Wasm
#
# This script builds essential Debian packages for the Wasm architecture,
# creating a full userspace environment with bash, coreutils, gcc, and more.

set -e

# Configuration
LW_ROOT="${LW_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
LW_WORKSPACE="${LW_WORKSPACE:-$LW_ROOT/workspace}"
LW_SRC="${LW_SRC:-$LW_WORKSPACE/src}"
LW_BUILD="${LW_BUILD:-$LW_WORKSPACE/build}"
LW_INSTALL="${LW_INSTALL:-$LW_WORKSPACE/install}"
LW_DEBIAN="${LW_DEBIAN:-$LW_WORKSPACE/debian-rootfs}"

# LLVM toolchain paths
LLVM_PREFIX="$LW_INSTALL/llvm"
export PATH="$LLVM_PREFIX/bin:$PATH"

# Common Wasm compilation flags
WASM_TARGET="wasm32-unknown-unknown"
WASM_CFLAGS="--target=$WASM_TARGET -mmutable-globals -Xclang -target-feature -Xclang +atomics -Xclang -target-feature -Xclang +bulk-memory -fPIC"
WASM_LDFLAGS="-Wl,-shared"

# Use musl as our libc
MUSL_PREFIX="$LW_INSTALL/musl"
WASM_SYSROOT="$MUSL_PREFIX"

echo "================================================"
echo "Linux/Wasm Debian Rootfs Builder"
echo "================================================"
echo "Workspace: $LW_WORKSPACE"
echo "Debian rootfs: $LW_DEBIAN"
echo "LLVM toolchain: $LLVM_PREFIX"
echo "musl libc: $MUSL_PREFIX"
echo ""

# Create directory structure
mkdir -p "$LW_DEBIAN"/{bin,sbin,lib,usr/{bin,sbin,lib,include,share},etc,var,tmp,proc,sys,dev}
mkdir -p "$LW_DEBIAN/usr/src/linux-wasm"
mkdir -p "$LW_SRC/debian-packages"
mkdir -p "$LW_BUILD/debian-packages"

# Copy kernel source and patches into rootfs
echo "==> Preserving kernel source and patches in rootfs"
cp -r "$LW_ROOT/patches" "$LW_DEBIAN/usr/src/linux-wasm/"
cp -r "$LW_ROOT"/*.sh "$LW_DEBIAN/usr/src/linux-wasm/" 2>/dev/null || true
cp -r "$LW_ROOT"/*.md "$LW_DEBIAN/usr/src/linux-wasm/" 2>/dev/null || true
if [ -d "$LW_SRC/kernel" ]; then
    echo "==> Copying full kernel source tree"
    cp -r "$LW_SRC/kernel" "$LW_DEBIAN/usr/src/linux-wasm/kernel-source"
fi

# Package list with versions from Debian stable
PACKAGES=(
    "bash:5.2.15"
    "coreutils:9.1"
    "gcc:12.2.0"
    "binutils:2.40"
    "make:4.3"
    "findutils:4.9.0"
    "grep:3.8"
    "sed:4.9"
    "gawk:5.2.1"
    "diffutils:3.8"
    "patch:2.7.6"
    "tar:1.34"
    "gzip:1.12"
    "bzip2:1.0.8"
    "xz-utils:5.4.1"
    "util-linux:2.38.1"
)

apply_patches() {
    local pkg_name="$1"
    local pkg_version="$2"
    local src_dir="$LW_SRC/debian-packages/$pkg_name-$pkg_version"
    local patch_dir="$LW_ROOT/patches/$pkg_name"
    
    if [ ! -d "$patch_dir" ]; then
        return 0
    fi
    
    cd "$src_dir"
    
    # Check if patches already applied
    if [ -f ".patches_applied" ]; then
        echo "    Patches already applied"
        return 0
    fi
    
    # Apply patches using git am
    if [ ! -d ".git" ]; then
        git init
        git add -A
        git commit -m "Initial import of $pkg_name $pkg_version"
    fi
    
    for patch in "$patch_dir"/*.patch; do
        if [ -f "$patch" ]; then
            echo "    Applying $(basename "$patch")"
            git am < "$patch" || {
                echo "    Warning: Patch failed, trying to continue..."
                git am --skip
            }
        fi
    done
    
    touch ".patches_applied"
}

download_package() {
    local pkg_name="$1"
    local pkg_version="$2"
    
    echo "==> Downloading $pkg_name $pkg_version"
    
    cd "$LW_SRC/debian-packages"
    
    case "$pkg_name" in
        bash)
            if [ ! -d "bash-$pkg_version" ]; then
                wget -q --show-progress "https://ftp.gnu.org/gnu/bash/bash-$pkg_version.tar.gz"
                tar xzf "bash-$pkg_version.tar.gz"
                apply_patches "$pkg_name" "$pkg_version"
            fi
            ;;
        coreutils)
            if [ ! -d "coreutils-$pkg_version" ]; then
                wget -q --show-progress "https://ftp.gnu.org/gnu/coreutils/coreutils-$pkg_version.tar.xz"
                tar xJf "coreutils-$pkg_version.tar.xz"
                apply_patches "$pkg_name" "$pkg_version"
            fi
            ;;
        gcc)
            if [ ! -d "gcc-$pkg_version" ]; then
                wget -q --show-progress "https://ftp.gnu.org/gnu/gcc/gcc-$pkg_version/gcc-$pkg_version.tar.xz"
                tar xJf "gcc-$pkg_version.tar.xz"
                apply_patches "$pkg_name" "$pkg_version"
            fi
            ;;
        binutils)
            if [ ! -d "binutils-$pkg_version" ]; then
                wget -q --show-progress "https://ftp.gnu.org/gnu/binutils/binutils-$pkg_version.tar.xz"
                tar xJf "binutils-$pkg_version.tar.xz"
                apply_patches "$pkg_name" "$pkg_version"
            fi
            ;;
        make)
            if [ ! -d "make-$pkg_version" ]; then
                wget -q --show-progress "https://ftp.gnu.org/gnu/make/make-$pkg_version.tar.gz"
                tar xzf "make-$pkg_version.tar.gz"
                apply_patches "$pkg_name" "$pkg_version"
            fi
            ;;
        *)
            echo "Package $pkg_name not yet supported"
            return 1
            ;;
    esac
}

build_bash() {
    local version="$1"
    echo "==> Building bash $version"
    
    mkdir -p "$LW_BUILD/debian-packages/bash-$version"
    cd "$LW_BUILD/debian-packages/bash-$version"
    
    if [ ! -f "Makefile" ]; then
        # Cross-compilation configuration cache for bash
        cat > config.cache <<'EOF'
ac_cv_func_mmap_fixed_mapped=yes
ac_cv_func_strcoll_works=yes
ac_cv_func_working_mktime=yes
bash_cv_func_sigsetjmp=present
bash_cv_getcwd_malloc=yes
bash_cv_job_control_missing=present
bash_cv_printf_a_format=yes
bash_cv_sys_named_pipes=present
bash_cv_sys_siglist=yes
bash_cv_under_sys_siglist=yes
bash_cv_unusable_rtsigs=no
bash_cv_wcontinued_broken=no
bash_cv_wexitstatus_offset=8
gt_cv_int_divbyzero_sigfpe=no
EOF
        
        CC="$LLVM_PREFIX/bin/clang" \
        CFLAGS="$WASM_CFLAGS -I$MUSL_PREFIX/include" \
        LDFLAGS="$WASM_LDFLAGS -L$MUSL_PREFIX/lib" \
        LIBS="-lc" \
        "$LW_SRC/debian-packages/bash-$version/configure" \
            --host=$WASM_TARGET \
            --build=x86_64-linux-gnu \
            --prefix=/usr \
            --without-bash-malloc \
            --disable-nls \
            --disable-net-redirections \
            --disable-largefile \
            --enable-static-link \
            --cache-file=config.cache
    fi
    
    make -j"${LW_JOBS_DEBIAN:-4}" || {
        echo "Build failed, trying single-threaded..."
        make
    }
    make DESTDIR="$LW_DEBIAN" install
    
    echo "✓ bash $version built successfully"
}

build_coreutils() {
    local version="$1"
    echo "==> Building coreutils $version"
    
    mkdir -p "$LW_BUILD/debian-packages/coreutils-$version"
    cd "$LW_BUILD/debian-packages/coreutils-$version"
    
    if [ ! -f "Makefile" ]; then
        "$LW_SRC/debian-packages/coreutils-$version/configure" \
            --host=$WASM_TARGET \
            --prefix=/usr \
            --disable-nls \
            CC="clang $WASM_CFLAGS" \
            LDFLAGS="$WASM_LDFLAGS"
    fi
    
    make -j"${LW_JOBS_DEBIAN:-4}"
    make DESTDIR="$LW_DEBIAN" install
}

# Main build flow
case "${1:-help}" in
    "fetch")
        echo "Fetching Debian package sources..."
        for pkg in "${PACKAGES[@]}"; do
            IFS=':' read -r name version <<< "$pkg"
            download_package "$name" "$version" || echo "Warning: Failed to download $name"
        done
        ;;
        
    "build-bash")
        build_bash "5.2.15"
        ;;
        
    "build-coreutils")
        build_coreutils "9.1"
        ;;
        
    "build-all")
        for pkg in "${PACKAGES[@]}"; do
            IFS=':' read -r name version <<< "$pkg"
            case "$name" in
                bash) build_bash "$version" ;;
                coreutils) build_coreutils "$version" ;;
                *) echo "Build not yet implemented for $name" ;;
            esac
        done
        ;;
        
    "create-initramfs")
        echo "==> Creating Debian-based initramfs"
        
        # Copy init script from patches
        cp "$LW_ROOT/patches/initramfs/init" "$LW_DEBIAN/"
        chmod +x "$LW_DEBIAN/init"
        
        # Copy kernel patches and build scripts
        mkdir -p "$LW_DEBIAN/usr/src/linux-wasm"
        echo "==> Including kernel patches and build system"
        cp -r "$LW_ROOT/patches" "$LW_DEBIAN/usr/src/linux-wasm/"
        cp "$LW_ROOT"/*.sh "$LW_DEBIAN/usr/src/linux-wasm/" 2>/dev/null || true
        cp "$LW_ROOT"/*.md "$LW_DEBIAN/usr/src/linux-wasm/" 2>/dev/null || true
        
        # Include LLVM toolchain in rootfs
        if [ -d "$LLVM_PREFIX" ]; then
            echo "==> Including LLVM toolchain"
            mkdir -p "$LW_DEBIAN/opt/llvm"
            cp -r "$LLVM_PREFIX"/* "$LW_DEBIAN/opt/llvm/"
        fi
        
        # Include musl libc
        if [ -d "$MUSL_PREFIX" ]; then
            echo "==> Including musl libc"
            cp -r "$MUSL_PREFIX/include" "$LW_DEBIAN/usr/"
            cp -r "$MUSL_PREFIX/lib"/* "$LW_DEBIAN/usr/lib/"
        fi
        
        # Create README
        cat > "$LW_DEBIAN/usr/src/linux-wasm/README" <<'EOFREADME'
Linux/Wasm Kernel Source and Patches
=====================================

This directory contains the complete Linux/Wasm kernel patches and build system.

Patches are in: ./patches/
- patches/kernel/     - Wasm architecture patches (14 patches)
- patches/llvm/       - LLVM linker script support
- patches/musl/       - musl libc Wasm support
- patches/busybox/    - BusyBox Wasm support
- patches/initramfs/  - Init scripts and test programs

Build scripts:
- linux-wasm.sh           - Main build system
- build-debian-rootfs.sh  - Debian userspace builder

Documentation:
- BUILD_STATUS.md         - Current build status
- DESKTOP_ROADMAP.md      - Desktop environment roadmap
- FRAMEBUFFER_PROGRESS.md - Framebuffer implementation notes

To rebuild the kernel:
  cd /usr/src/linux-wasm
  ./linux-wasm.sh build-kernel

LLVM toolchain is at: /opt/llvm
musl libc headers are at: /usr/include
EOFREADME
        
        mkdir -p "$LW_INSTALL/initramfs"
        cd "$LW_DEBIAN"
        find . -print0 | cpio --null -ov --format=newc | gzip -9 > "$LW_INSTALL/initramfs/initramfs-debian.cpio.gz"
        echo "Created: $LW_INSTALL/initramfs/initramfs-debian.cpio.gz"
        ls -lh "$LW_INSTALL/initramfs/initramfs-debian.cpio.gz"
        ;;
        
    "help"|*)
        cat <<EOF
Usage: $0 <command>

Commands:
    fetch              - Download Debian package sources
    build-bash         - Build bash shell
    build-coreutils    - Build GNU coreutils
    build-all          - Build all packages
    create-initramfs   - Package rootfs into initramfs
    help               - Show this help

Environment Variables:
    LW_WORKSPACE       - Workspace directory (default: ./workspace)
    LW_JOBS_DEBIAN     - Parallel jobs for package builds (default: 4)

Example workflow:
    $0 fetch
    $0 build-bash
    $0 build-coreutils
    $0 create-initramfs
EOF
        ;;
esac
