# Linux/Wasm Development Guide

## Project Overview

This project builds a complete Linux kernel that runs natively in WebAssembly, executing in the browser. It's not emulation—it's a real Linux kernel compiled to Wasm using LLVM, with a custom architecture port (`arch/wasm`).

**Key Architecture:**

- **LLVM toolchain** (clang, wasm-ld) with GNU linker script support patch
- **Linux kernel 6.4.16** with custom Wasm architecture (`ARCH=wasm`) - full kernel port in `patches/kernel/0005-Add-Wasm-architecture.patch`
- **musl libc** compiled for Wasm target (minimal/hacky patches)
- **BusyBox** providing userland utilities
- **JavaScript runtime** (`runtime/`) manages CPU threads via Web Workers
- **Multi-threaded model:** Each Linux task/thread runs in its own Web Worker with shared memory (`SharedArrayBuffer`)
- **NOMMU configuration:** Wasm lacks MMU, so kernel and userspace run without memory management unit

## Critical Build System Understanding

### The Build Script (`linux-wasm.sh`)

**Execution model:** Uses bash `;;&` fall-through case statements—**this is critical to understand!** Unlike normal `;;` which exits the case, `;;&` continues to re-test subsequent cases. This allows commands like `./linux-wasm.sh all` to match multiple cases (fetch-llvm, build-llvm, fetch-kernel, build-kernel, etc.) in sequence within a single script invocation.

**Workspace structure (all under `workspace/` by default):**

- `src/` - Downloaded sources with patches applied via `git am`
- `build/` - Build artifacts (out-of-tree builds for all components)
- `install/` - Installation destinations (NOT system paths, local staging area)

**Environment variables:**

```bash
LW_WORKSPACE=/path/to/workspace  # Override workspace location
LW_SRC=/custom/src               # Override source directory
LW_BUILD=/custom/build           # Override build directory
LW_INSTALL=/custom/install       # Override install directory
```

**Build order matters:** `llvm` → `kernel` → `musl` → `busybox-kernel-headers` → `busybox` → `initramfs`

### Common Commands

```bash
# Full build (fetch + build everything) - first-time setup
./linux-wasm.sh all

# Build only OS components (skip LLVM toolchain rebuild) - fastest for kernel/userspace changes
./linux-wasm.sh build-os

# Rebuild specific component (requires dependencies already built)
./linux-wasm.sh build-kernel       # Requires LLVM
./linux-wasm.sh build-busybox      # Requires musl, kernel headers
./linux-wasm.sh build-initramfs    # Packages BusyBox + init script

# Fetch sources only (download + apply patches via git am)
./linux-wasm.sh fetch

# Clean: manually delete workspace/{src,build,install}
# Incremental rebuilds work - just delete the specific component's build folder
```

### Known Build Quirks

1. **LLVM rebuild bug:** Second build fails on runtimes. Workaround: build again (works on 1st, 3rd, 5th attempts).
2. **No spaces in paths:** LLVM install path cannot contain spaces due to kernel Makefile limitations.
3. **Parallel jobs:** Configured via `LW_JOBS_*` variables—conservative defaults to avoid OOM.
4. **LLVM patch verification:** After `fetch-llvm`, verify patch applied with `cd workspace/src/llvm && git log --oneline -2` - should show the linker script patch. If kernel build fails with `unknown argument: --script=`, LLVM wasn't properly patched.

## Runtime Architecture

### Multi-threading Model

- **Main thread** (`linux.js`): Manages CPU/task lifecycle, coordinates Web Workers
- **Web Workers** (`linux-worker.js`): Each represents one CPU or one Linux task
- **CPU 0**: Runs `init_task` (becomes idle), boots system, brings up secondary CPUs
- **Secondary CPUs**: Start with their own idle tasks
- **Tasks**: Created via `wasm_create_and_run_task`, each gets its own Worker

### Shared Memory & Synchronization

- `WebAssembly.Memory` with `shared: true` for all CPUs
- `SharedArrayBuffer` for locks and inter-task communication
- `Atomics.wait()` / `Atomics.notify()` for task scheduling
- Task switching (`switch_to`) coordinated via serialization locks

### Framebuffer & Graphics (In Progress)

- Kernel framebuffer driver: `patches/kernel/0013-Add-Wasm-framebuffer-support.patch`
- JS Canvas rendering in `runtime/index.html` and `runtime/linux.js`
- Callbacks: `wasm_driver_fb_update()` → `framebuffer_update` message → Canvas ImageData
- Status: See `DESKTOP_ROADMAP.md` and `FRAMEBUFFER_PROGRESS.md` for current implementation phase

### Running the Runtime

```bash
cd runtime
# Copy artifacts: workspace/install/kernel/vmlinux.wasm and workspace/install/initramfs/initramfs.cpio.gz
python3 server.py 8000
# Navigate to http://127.0.0.1:8000/
```

**Browser requirements:**

- SharedArrayBuffer support requires COOP/COEP headers (handled by `server.py`)
- Best debugging: Chromium/Edge (superior Wasm debugging vs Firefox)
- Cache busting: append `?v=-1` to URL

## Patch Management

### Patch Application

All patches applied via `git am` during fetch phase. Organized by component:

- `patches/llvm/` - GNU linker script support for wasm-ld
- `patches/kernel/` - Wasm architecture port (14 patches - includes recent framebuffer support)
- `patches/musl/` - Wasm target support (minimal/hacky)
- `patches/busybox/` - Wasm build support
- `patches/busybox-kernel-headers/` - Sabotage Linux patches for musl compatibility

### Kernel Patches (Applied in Order)

Critical patches for Wasm architecture:

- `0005-Add-Wasm-architecture.patch` - Core architecture support (full `arch/wasm` port, 3700+ lines)
- `0006-Add-Wasm-binfmt.patch` - Execute .wasm files as binaries
- `0010-Add-Wasm-console-support.patch` - Web console driver
- `0011-Add-wasm_defconfig.patch` - NOMMU configuration
- `0013-Add-Wasm-framebuffer-support.patch` - Framebuffer driver (`arch/wasm/drivers/fb_wasm.c`)
- `0014-Update-wasm_defconfig-for-framebuffer.patch` - Enable CONFIG_FB in defconfig

**Important:** Wasm lacks MMU, so kernel runs in NOMMU mode. Userspace must use `-fPIC -shared`.

## Key Conventions

### Build Flags

**Wasm compilation always uses:**

- `--target=wasm32-unknown-unknown`
- `-fPIC -Wl,-shared` (required for NOMMU)
- Atomics: `-Xclang -target-feature -Xclang +atomics`
- Bulk memory: `-Xclang -target-feature -Xclang +bulk-memory`

**Kernel builds with:**

- `ARCH=wasm`
- `LLVM=/path/to/llvm/bin/` (note trailing slash requirement!)
- `CROSS_COMPILE=wasm32-unknown-unknown-`

### File Organization

- **Never modify `patches/initramfs/initramfs-base.cpio`** - Requires root to rebuild (via `tools/make-initramfs-base.sh`)
- **Init script:** `patches/initramfs/init` runs at boot, mounts proc/sys, creates `/dev/fb0`, launches shell
- **Runtime files:** Self-contained in `runtime/` directory
- **Docker:** `linux-wasm-base` for dev environment, `linux-wasm-contained` for CI builds

## Docker Development

```bash
# Build containers
docker build -t linux-wasm-base:dev ./docker/linux-wasm-base
docker build -t linux-wasm-contained:dev ./docker/linux-wasm-contained

# Development (with host mount)
docker run -it --name my-linux-wasm \
  --mount type=bind,src="$(pwd)",target=/linux-wasm \
  linux-wasm-base:dev bash

# Inside container
/linux-wasm/linux-wasm.sh all

# Change workspace location
docker run -e LW_WORKSPACE=/custom/path ...
```

## Debugging & Known Issues

### Known Bugs (documented in `patches/initramfs/init`)

- Terminal input freezes after a while (timer issue)
- longjmp() not implemented yet
- Various memory corruption issues (some fixed)
- dup_fd, wq_worker_comm, rcu_os crash (memory corruption - potentially fixed)

### Debugging Tips

- Use browser DevTools for Wasm debugging (Chromium recommended)
- Check `vmlinux` symbols with: `llvm-nm workspace/build/kernel/vmlinux`
- Build verbosity: add `V=1` to kernel make commands
- LLVM assertions enabled by default (`-DLLVM_ENABLE_ASSERTIONS=1`)

### Common Build Errors

**"wasm-ld: error: unknown argument: --script="**

- **Cause:** LLVM patch for GNU linker script support not applied
- **Solution:** Delete `workspace/src/llvm` and re-run `./linux-wasm.sh fetch-llvm build-llvm`
- **Verify fix:** `workspace/install/llvm/bin/wasm-ld --help | grep script` should show `--script` option

## Integration Points

### Kernel ↔ JavaScript Host

Host callbacks in `linux-worker.js`:

- `wasm_start_cpu()` / `wasm_stop_cpu()` - CPU lifecycle
- `wasm_create_and_run_task()` - Task creation
- `wasm_serialize()` - Task switching coordination
- Console I/O via `console_read` / `console_write` messages
- Framebuffer: `wasm_driver_fb_update()` → `framebuffer_update` message handler in `linux.js`

### User Executables

- Wasm binaries can run via kernel binfmt support (patch 0006)
- Each user process can map to separate Wasm instance (no shared memory between processes)
- Alternative: Proxy syscalls through shared kernel instance

## Version Pins

- **LLVM:** 18.1.2 (llvmorg-18.1.2)
- **Linux kernel:** 6.4.16 (v6.4.16)
- **musl:** 1.2.5 (v1.2.5)
- **BusyBox:** 1.36.1 (1_36_1)

When updating versions, expect patch conflicts requiring manual resolution.
