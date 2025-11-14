# Scripts for Building a Linux/Wasm Operating System

This project contains scripts to download, build and run a Linux system that can be executed on the web, using native WebAssembly (Wasm).

These scripts can be run in the following way:

- Directly on a host machine.
- In a generic docker container.
- In a specific docker container (see Dockerfile).

## Quick Start

```bash
# Build everything from scratch
./linux-wasm.sh all

# Build lightweight rootfs (recommended for testing)
./linux-wasm.sh all-lite
./linux-wasm.sh deploy-lite

# Or build full rootfs with integrated toolchain
./linux-wasm.sh all-full
./linux-wasm.sh deploy-full

# Start the server
cd runtime && python3 server.py 8000
# Navigate to http://127.0.0.1:8000/
```

## Rootfs Options

The system now supports two deployment strategies:

### Lightweight Build (Recommended)

- **Size**: ~1.3MB initramfs + 865MB toolchain volume
- **Boot time**: Fast initial boot
- **Components**: BusyBox + musl libc (base system)
- **Toolchain**: Separate volume (can be loaded on-demand)
- **Build**: `./linux-wasm.sh all-lite && ./linux-wasm.sh deploy-lite`

### Full Build

- **Size**: ~1.3GB integrated initramfs
- **Boot time**: Slower due to large size
- **Components**: BusyBox + musl + LLVM toolchain integrated
- **Toolchain**: Built-in
- **Build**: `./linux-wasm.sh all-full && ./linux-wasm.sh deploy-full`

**Note**: The lightweight build boots much faster. Dynamic loading of the toolchain volume is planned for future implementation.

## Parts

The project is built and assembled from following pieces of software:

- LLVM Project:
  - Base version: 18.1.2
  - Patches:
    - A hack patch that enables GNU ld-style linker scripts in wasm-ld.
  - Artifacts: clang, wasm-ld (from lld), compiler-rt
- Linux kernel:
  - Base version: 6.4.16
  - Patches (14 patches total):
    - Wasm architecture support (full arch/wasm port)
    - Wasm binfmt feature patch, enabling .wasm files to run as executables
    - Console driver for Wasm "web console"
    - Framebuffer driver for graphics support (800x600x32 BGRA)
    - Input drivers (keyboard and mouse)
  - Artifacts: vmlinux.wasm, exported kernel headers
  - Dependencies: clang, wasm-ld with linker script support
- musl:
  - Base version: 1.2.5
  - Patches:
    - Wasm target support with NOMMU configuration
    - Thread-local storage support (requires -mmutable-globals)
    - vfork() implementation using kernel_clone()
  - Artifacts: musl libc with full Wasm support
  - Dependencies: clang, wasm-ld, compiler-rt
- Linux kernel headers for BusyBox
  - Base version: from the kernel
  - Patches:
    - A series of patches, originally hosted by Sabotage Linux, but modified to suit a newer kernel. These patches allow BusyBox to include kernel headers (which is not really supported by Linux). This magically just "works" with glibc but needs modding for musl.
  - Artifacts: modified kernel headers
  - Dependencies: exported Linux kernel headers
- BusyBox:
  - Base version: 1.36.1
  - Patches:
    - A hack patch (minimal and incomplete) that:
      - Allows BuxyBox to be built using clang and wasm-ld (linker script support might be unnecessary).
      - Adds a Wasm defconfig.
  - Artifacts: BusyBox installation (base binary and symlinks for ls, cat, mv etc.)
  - Dependencies: musl libc, modified headers for BusyBox
- A minimal initramfs:
  - Multiple build options available:
    - **Lightweight**: BusyBox + musl (1.3MB) - Fast boot
    - **Full**: Includes LLVM toolchain (1.3GB) - Development ready
  - Artifacts: initramfs-lite.cpio.gz or initramfs-debian.cpio.gz
  - Dependencies: BusyBox installation
- Toolchain volume (optional):
  - Complete LLVM 18.1.2 toolchain (865MB compressed)
  - Kernel sources and all patches preserved
  - Can be loaded separately for development
  - Artifacts: toolchain.tar.gz
- A runtime:
  - Notes:
    - JavaScript/WebAssembly host implementation
    - Multi-threaded model using Web Workers
    - Shared memory support (SharedArrayBuffer)
    - Memory configuration: 32MB initial, up to 4GB maximum
    - Error handling is not very graceful, more geared towards debugging than user experience.
    - This is the glue code that kicks everything off, spawns web workers, creates Wasm instances etc.

## Important Notes

**Wasm/NOMMU**: Wasm lacks an MMU, meaning that Linux needs to be built in a NOMMU configuration. Wasm programs thus need to be built using `-fPIC -Wl,-shared` with `-mmutable-globals` for TLS support.

**Compilation Flags**: All Wasm binaries must be compiled with:

```bash
--target=wasm32-unknown-unknown \
-mmutable-globals \
-Xclang -target-feature -Xclang +atomics \
-Xclang -target-feature -Xclang +bulk-memory \
-fPIC -Wl,-shared
```

**Memory**: The runtime now uses 32MB initial memory (increased from 1.92MB) to support larger initramfs files.

## Running

Run ./linux-wasm.sh to see usage. Downloads happen first, building afterwards. You may partially select what to download or (re)-build.

Due to a bug in LLVM's build system, building LLVM a second time fails when building runtimes (complaining that clang fails to build a simple test program). A workaround is to build it yet again (it works each other time, i.e. the 1st, 3rd, 5th etc. time).

Due to limitations in the Linux kernel's build system, the absolute path of the cross compiler (install path of LLVM) cannot contain spaces. Since LLVM is built by linux-wasm.sh, it more or less means its workspace directory (or at least install directory) has to be in a space free path.

### Docker

The following commands should be executed in this repo root.

There are two containers:

- **linux-wasm-base**: Contains an Ubuntu 20.04 environment with all tools installed for building (e.g. cmake, gcc etc.).
- **linux-wasm-contained**: Actually builds everything into the container. Meant as a dispoable way to build everything isolated.

Create the containers:

```
docker build -t linux-wasm-base:dev ./docker/linux-wasm-base
docker build -t linux-wasm-contained:dev ./docker/linux-wasm-contained
```

Note that the latter command will copy linux-wasm.sh, in its current state, into the container.

To launch a simple docker container with a mapping to host (recommended for development):

```
docker run -it --name my-linux-wasm --mount type=bind,src="$(pwd)",target=/linux-wasm linux-wasm-base:dev bash
(Inside the bash prompt, run for example:) /linux-wasm/linux-wasm.sh all
```

To actually build everything inside the container (mostly useful for build servers):

```
docker run -it -name full-linux-wasm linux-wasm-contained:dev /linux-wasm/linux-wasm.sh all
```

To change workspace folder, docker run -e LW_WORKSPACE=/path/to/workspace ...blah... can be used. This may be useful together with docker volumes.
