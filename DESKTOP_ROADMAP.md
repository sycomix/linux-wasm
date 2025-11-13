# Linux/Wasm Desktop Environment Roadmap

## Overview

Implementation plan for adding graphical desktop environment to Linux/Wasm.

## Current Status

- ✅ Text console working (HVC driver)
- ✅ Terminal I/O via JavaScript
- ✅ BusyBox userland
- ❌ No graphics support
- ❌ No GUI input handling

## Implementation Phases

### Phase 1: Framebuffer Foundation ⬅️ **START HERE**

**Goal:** Basic pixel rendering from kernel to browser Canvas

**Kernel side:**

- [ ] Create `patches/kernel/0013-Add-Wasm-framebuffer-support.patch`
- [ ] Add `arch/wasm/drivers/fb_wasm.c` driver
- [ ] Enable `CONFIG_FB=y`, `CONFIG_FRAMEBUFFER_CONSOLE=y` in defconfig
- [ ] Export `wasm_driver_fb_update()` callback to JavaScript

**JavaScript side:**

- [ ] Add Canvas element to `runtime/index.html`
- [ ] Handle `framebuffer_update` messages in `runtime/linux.js`
- [ ] Render pixel data using Canvas ImageData API
- [ ] Implement double-buffering for performance

**Test:** Boot kernel, see framebuffer console with text

### Phase 2: Input Subsystem

**Goal:** Keyboard and mouse events from browser to kernel

**Kernel side:**

- [ ] Create `patches/kernel/0014-Add-Wasm-input-support.patch`
- [ ] Add `arch/wasm/drivers/input_wasm.c`
- [ ] Enable `CONFIG_INPUT=y`, `CONFIG_INPUT_KEYBOARD=y`, `CONFIG_INPUT_MOUSE=y`
- [ ] Export `wasm_driver_input_event()` callback

**JavaScript side:**

- [ ] Capture DOM keyboard events (keydown, keyup, keypress)
- [ ] Capture DOM mouse events (mousemove, mousedown, mouseup)
- [ ] Forward events to kernel via callbacks
- [ ] Handle coordinate mapping (Canvas to framebuffer)

**Test:** Mouse cursor moves, keyboard types in framebuffer console

### Phase 3: Graphics Libraries

**Goal:** Userspace graphics rendering stack

**Options (pick one):**

- **DirectFB** - Direct framebuffer access, NOMMU-friendly
- **nano-X** - Tiny X-like server for embedded systems
- **FbUI** - Minimal framebuffer UI toolkit

**Build system:**

- [ ] Add `fetch-directfb` / `build-directfb` to `linux-wasm.sh`
- [ ] Compile with NOMMU support (`-fPIC -shared`)
- [ ] Link against musl libc
- [ ] Package into initramfs

**Test:** Run DirectFB demo apps (df_andi, df_fire, etc.)

### Phase 4: Window Manager

**Goal:** Manage multiple graphical applications

**NOMMU-compatible options:**

- **Matchbox** - Embedded window manager
- **fbpanel** - Lightweight panel for framebuffer
- **Custom minimal WM** - Built specifically for this project

**Requirements:**

- Must work without virtual memory (NOMMU)
- Minimal memory footprint
- DirectFB or raw framebuffer backend

**Test:** Run multiple windows, switch between them

### Phase 5: Desktop Applications

**Goal:** Useful graphical programs

**Initial targets:**

- **Links2** - Framebuffer web browser
- **FbTerm** - Terminal emulator in framebuffer
- **Image viewer** - Display PNG/JPEG
- **Text editor** - nano with DirectFB frontend
- **Calculator** - Simple GUI app demo

**Test:** Browse web pages, view images, edit text

## Technical Constraints

### NOMMU Limitations

- No fork() - use vfork() or posix_spawn()
- All code must be PIC (-fPIC -shared)
- No memory overcommit
- Limited to ~30MB initial memory (from index.html)

### Performance Considerations

- Framebuffer updates: Minimize data transfer Wasm→JS
- Dirty rectangle tracking: Only update changed regions
- Canvas optimization: Use hardware acceleration where available
- Memory bandwidth: Shared memory more efficient than postMessage

### Browser Compatibility

- SharedArrayBuffer requires COOP/COEP headers (already configured)
- Canvas 2D context for rendering
- OffscreenCanvas for worker-based rendering (optional optimization)

## Build Order Dependencies

```
LLVM toolchain
  ↓
Linux kernel (with fb + input patches)
  ↓
musl libc
  ↓
BusyBox
  ↓
Graphics library (DirectFB/nano-X)
  ↓
Window manager (Matchbox)
  ↓
Desktop applications
  ↓
initramfs (package everything)
```

## Memory Budget Estimate

| Component               | Memory        |
| ----------------------- | ------------- |
| Kernel                  | ~5 MB         |
| Framebuffer (800x600x4) | ~2 MB         |
| DirectFB                | ~3 MB         |
| Window manager          | ~2 MB         |
| Applications            | ~10-15 MB     |
| **Total**               | **~22-27 MB** |

Within 30MB browser limit ✓

## Quick Start Commands

```bash
# 1. Complete current build
./linux-wasm.sh build-llvm  # (running now)
./linux-wasm.sh build-os

# 2. Test current console
cd runtime
python3 server.py 8000
# Open http://127.0.0.1:8000/

# 3. Apply framebuffer patch (after creating it)
./linux-wasm.sh build-kernel

# 4. Build graphics stack
./linux-wasm.sh build-directfb
./linux-wasm.sh build-initramfs

# 5. Test graphical mode
cd runtime
python3 server.py 8000
# Should see graphical framebuffer console
```

## Next Immediate Steps

1. ✅ Fix LLVM patch issue
2. ⏳ Complete LLVM build (3888 targets - will take ~30-60 minutes)
3. ⏳ Build kernel + musl + busybox
4. Create framebuffer patch (0013)
5. Create JavaScript Canvas integration
6. Test basic graphics

## Research Notes

### Framebuffer Driver Implementation

Based on existing `hvc_wasm.c` pattern:

- Export C function `wasm_driver_fb_update(void *pixels, int w, int h, int stride)`
- Called by framebuffer subsystem when screen updates
- JavaScript receives pixel data as Uint8Array
- Render to Canvas using `putImageData()`

### DirectFB Configuration

```bash
./configure \
  --host=wasm32-unknown-unknown \
  --prefix=/ \
  --enable-static \
  --disable-shared \
  --with-gfxdrivers=none \
  --with-inputdrivers=linuxinput \
  CC="clang --target=wasm32-unknown-unknown" \
  CFLAGS="-fPIC" \
  LDFLAGS="-Wl,-shared"
```

### Useful References

- Linux framebuffer HOWTO: https://www.kernel.org/doc/Documentation/fb/
- DirectFB documentation: http://directfb.org/docs/
- Matchbox window manager: https://www.yoctoproject.org/software-item/matchbox/
