# Build Status - Linux/Wasm

**Last Updated:** November 13, 2025

## 🎉 Current Status: WORKING

The Linux/Wasm system successfully boots and runs in the browser with full functionality.

## ✅ Completed Features

### System Architecture
- [x] LLVM 18.1.2 toolchain with GNU linker script support
- [x] Linux kernel 6.4.16 with full Wasm architecture port (14 patches)
- [x] musl libc 1.2.5 with Wasm/NOMMU support and TLS
- [x] BusyBox 1.36.1 userland utilities
- [x] Multi-threaded runtime using Web Workers

### Kernel Features
- [x] NOMMU configuration for WebAssembly
- [x] Console driver (web console)
- [x] Framebuffer driver (800x600x32 BGRA)
- [x] Input drivers (keyboard and mouse)
- [x] Binary format loader for .wasm executables
- [x] Shell script execution (#! shebang)
- [x] vfork() syscall with kernel_clone()
- [x] Multi-CPU support (tested with 3 CPUs)

### Build System
- [x] Lightweight rootfs (1.3MB) - Fast boot
- [x] Full rootfs with toolchain (1.3GB) - Development ready
- [x] Separate toolchain volume (865MB)
- [x] Automated deployment with `deploy-lite` and `deploy-full`
- [x] All patches preserved in `/usr/src/linux-wasm/`

### Runtime & Memory
- [x] 32MB initial memory (increased from 1.92MB)
- [x] Shared memory with atomics support
- [x] Thread-local storage with -mmutable-globals
- [x] Task scheduling and context switching

## 📦 Build Options

### Lightweight Build (Recommended)
```bash
./linux-wasm.sh all-lite      # Build lite rootfs + toolchain volume
./linux-wasm.sh deploy-lite   # Deploy to runtime/
```
- **Initramfs**: 1.3MB (fast boot)
- **Toolchain**: 865MB separate volume
- **Use case**: Testing, iteration, quick boots

### Full Build
```bash
./linux-wasm.sh all-full      # Build integrated rootfs
./linux-wasm.sh deploy-full   # Deploy to runtime/
```
- **Initramfs**: 1.3GB (integrated)
- **Components**: Everything built-in
- **Use case**: Complete development environment

## 🔧 Component Versions

| Component | Version | Patches | Status |
|-----------|---------|---------|--------|
| LLVM | 18.1.2 | 1 (linker scripts) | ✅ Working |
| Linux Kernel | 6.4.16 | 14 (Wasm arch, drivers) | ✅ Working |
| musl libc | 1.2.5 | 1 (Wasm/TLS support) | ✅ Working |
| BusyBox | 1.36.1 | 1 (Wasm build) | ✅ Working |

## 🐛 Known Issues

### Fixed
- ✅ vfork() not implemented → Fixed with kernel_clone()
- ✅ TLS immutable globals → Fixed with -mmutable-globals
- ✅ Zero-size allocation crash → Fixed in binfmt_wasm
- ✅ OOM during boot → Fixed with 32MB initial memory

### Current Limitations
- ⚠️ Terminal input can freeze (timer issue)
- ⚠️ longjmp() not fully implemented
- ⚠️ Some memory corruption under investigation
- ⚠️ Dynamic volume loading not yet implemented

## 🧪 Testing Status

**Working:**
- ✅ Boot sequence completes
- ✅ Shell scripts execute
- ✅ Compiled .wasm binaries run
- ✅ vfork() creates processes
- ✅ Framebuffer operations
- ✅ Console I/O
- ✅ Multi-CPU initialization

**Needs Testing:**
- 🔄 In-browser compilation with LLVM
- 🔄 Long-running process stability

**Not Implemented:**
- ❌ Dynamic volume mounting
- ❌ Desktop environment (see DESKTOP_ROADMAP.md)
- ❌ Network stack

## 🚀 Quick Start

```bash
# First time setup
./linux-wasm.sh all           # Build base components (LLVM, kernel, musl, busybox)
./linux-wasm.sh all-lite      # Build lightweight rootfs
./linux-wasm.sh deploy-lite   # Deploy to runtime/

# Run the system
cd runtime && python3 server.py 8000
# Open browser to http://127.0.0.1:8000/
```

## 📁 Repository Structure

```
/patches/
  llvm/           - Linker script support (1 patch)
  kernel/         - Wasm architecture (14 patches)
  musl/           - Wasm/NOMMU support (1 patch)
  busybox/        - Wasm build support (1 patch)
  initramfs/      - Init scripts

/runtime/
  linux.js        - Main runtime (32MB initial memory)
  linux-worker.js - Task runner (Web Workers)
  index.html      - Browser interface
  vmlinux.wasm    - Kernel binary (30MB)
  initramfs.cpio.gz - Root filesystem (1.3MB or 1.3GB)

/workspace/       - Build artifacts (created during build)
  src/            - Source code with patches applied
  build/          - Build directories
  install/        - Installation outputs
    initramfs/    - Rootfs archives
    volumes/      - Toolchain volume
```

## 📊 Performance

- **Boot time**: 2-5 seconds (lite), 15-30 seconds (full)
- **Memory**: Starts at 32MB, grows dynamically
- **Browser**: Chrome/Edge recommended

## 🔜 Next Steps

1. Test in-browser compilation with LLVM toolchain
2. Implement dynamic volume loading (tar.gz from URL)
3. Stability improvements and bug fixes
4. Desktop environment (framebuffer + window manager)
5. Network stack integration

See also:
- `DESKTOP_ROADMAP.md` - GUI/desktop plans
- `FRAMEBUFFER_PROGRESS.md` - Graphics implementation
- `VOLUME_SYSTEM.md` - Virtual volume architecture
