# Virtual Volume System

## Architecture

The Linux/Wasm system now uses a **two-stage loading approach**:

### Stage 1: Lightweight Initramfs (1.3MB)

- BusyBox utilities
- musl libc (headers + libraries)
- Basic system configuration
- Fast boot time

### Stage 2: Toolchain Volume (865MB)

- Complete LLVM 18.1.2 toolchain
- Kernel sources and patches
- Development utilities
- Loaded on-demand after boot

## Benefits

1. **Fast Initial Boot** - Only 1.3MB needs to load initially
2. **Optional Development Tools** - Load toolchain only when needed
3. **Memory Efficient** - Kernel can grow memory as needed
4. **Modular** - Additional volumes can be added (Python, Node.js, etc.)

## Current Status

✅ Lightweight rootfs builds and packages correctly
✅ Toolchain volume created as separate tar.gz
🔄 Volume mounting needs kernel ramdisk support
🔄 JavaScript loader needs tar extraction implementation

## Implementation Plan

### Phase 1: Manual Integration (Current)

For now, we can rebuild the full rootfs by combining both:

```bash
./build-minimal-rootfs.sh  # Includes everything (1.3GB)
```

### Phase 2: Dynamic Loading (Next)

Implement kernel support for mounting compressed volumes:

1. **Add ramdisk support** to kernel
2. **Implement tar extraction** in JavaScript
3. **Create mount syscall hook** to load volume from URL
4. **Update init script** to auto-mount /opt

### Phase 3: Multiple Volumes (Future)

Support for multiple mountable volumes:

- `/opt/llvm` - Toolchain
- `/opt/python` - Python runtime
- `/opt/nodejs` - Node.js runtime
- `/usr/share/packages` - Debian packages

## Testing Current Setup

The lightweight version is ready to test:

```bash
cd runtime
python3 server.py 8000
# Navigate to http://127.0.0.1:8000/
```

System will boot with BusyBox + musl libc. The full toolchain can be added later when dynamic loading is implemented.
