# Linux/Wasm Desktop Environment - Detailed Implementation Plan

**Status:** Planning Phase  
**Goal:** Functional graphical desktop with window manager and applications  
**Last Updated:** November 13, 2025

## Current State Assessment

### ✅ Completed Infrastructure

1. **Framebuffer Foundation (Phase 1)**

   - Kernel driver: `arch/wasm/drivers/fb_wasm.c` (800x600x32 BGRA)
   - JavaScript integration: Canvas rendering pipeline
   - Deferred I/O at ~30 FPS
   - Patches: 0013 (driver) + 0014 (config)

2. **Build System**

   - LLVM 18.1.2 with GNU linker script support
   - Kernel 6.4.16 with Wasm arch port
   - musl libc with NOMMU patches
   - BusyBox userland (modified for clone() instead of vfork())

3. **Runtime Architecture**
   - Multi-threaded Web Worker model
   - SharedArrayBuffer for shared memory
   - Atomics-based task synchronization

### 🔴 Critical Constraints

#### NOMMU Limitations (Cannot Be Bypassed)

1. **No fork()** - Must use `clone()` with specific flags
   - BusyBox already patched to use `clone(fn, NULL, CLONE_VM | CLONE_VFORK | SIGCHLD, arg)`
   - All userspace code must follow this pattern
2. **All code must be Position Independent**
   - Build flags: `-fPIC -Wl,-shared` (mandatory)
   - Static linking only (no dynamic .so loading)
3. **No vfork()** - Not implemented yet (requires longjmp support)
   - Use `clone()` with `CLONE_VFORK` flag instead
   - Already working in BusyBox init system
4. **No memory protection**

   - No mprotect(), mmap() with MAP_PRIVATE, etc.
   - All processes share same address space
   - Security implications acceptable for single-user environment

5. **Memory budget constraints**
   - ~30MB initial allocation (set in `runtime/index.html`)
   - Cannot grow dynamically
   - Must fit: kernel (~5MB) + framebuffer (~2MB) + userspace (~20-23MB)

## Phase 2: Input Subsystem (NEXT - High Priority)

### Goal

Enable keyboard and mouse interaction with the framebuffer.

### Implementation Tasks

#### 2.1 Kernel Input Drivers

**Create `patches/kernel/0015-Add-Wasm-input-support.patch`:**

```c
// arch/wasm/drivers/input_wasm.c
// - Register as input device (keyboard + mouse)
// - Implement event injection from JavaScript
// - Handle coordinate mapping for mouse
// - Queue events using kernel input subsystem
```

**Config changes:**

- `CONFIG_INPUT=y`
- `CONFIG_INPUT_KEYBOARD=y`
- `CONFIG_INPUT_MOUSE=y`
- `CONFIG_INPUT_MOUSEDEV=y` (for /dev/input/mice)
- `CONFIG_INPUT_EVDEV=y` (for /dev/input/event\*)

**Host callbacks to export:**

```c
extern void wasm_driver_input_keyboard(int keycode, int pressed);
extern void wasm_driver_input_mouse(int x, int y, int buttons, int wheel);
```

#### 2.2 JavaScript Event Capture

**Update `runtime/index.html`:**

```javascript
// Keyboard event handlers
canvas.addEventListener("keydown", (e) => {
  e.preventDefault();
  const scancode = keyCodeToLinuxScancode(e.keyCode);
  sendInputEvent("keyboard", scancode, 1);
});

canvas.addEventListener("keyup", (e) => {
  e.preventDefault();
  const scancode = keyCodeToLinuxScancode(e.keyCode);
  sendInputEvent("keyboard", scancode, 0);
});

// Mouse event handlers
canvas.addEventListener("mousemove", (e) => {
  const rect = canvas.getBoundingClientRect();
  const x = Math.floor((e.clientX - rect.left) * (800 / rect.width));
  const y = Math.floor((e.clientY - rect.top) * (600 / rect.height));
  sendInputEvent("mouse", x, y, mouseButtons, 0);
});

canvas.addEventListener("mousedown", (e) => {
  mouseButtons |= 1 << e.button;
  sendInputEvent("mouse", lastX, lastY, mouseButtons, 0);
});

// Similar for mouseup, wheel events
```

**Update `runtime/linux-worker.js`:**

Add host callbacks that forward to kernel:

```javascript
wasm_driver_input_keyboard: (keycode, pressed) => {
  // Called by JavaScript when key event occurs
  vmlinux_instance.exports.wasm_input_keyboard_event(keycode, pressed);
},

wasm_driver_input_mouse: (x, y, buttons, wheel) => {
  vmlinux_instance.exports.wasm_input_mouse_event(x, y, buttons, wheel);
}
```

#### 2.3 Key Code Mapping

Need JavaScript → Linux scancode translation table. Linux uses standard PC keyboard scancodes (see `include/uapi/linux/input-event-codes.h`).

#### 2.4 Testing

1. Boot system with framebuffer
2. Mouse cursor should be visible (rendered by fbcon or later by DirectFB)
3. Keyboard should type in framebuffer console
4. Mouse should move cursor, click should work in applications

**Success criteria:**

- `cat /dev/input/mice` shows mouse movement
- `hexdump /dev/input/event0` shows keyboard events
- Mouse pointer visible on screen
- Can interact with framebuffer console using mouse

### Estimated Effort

- Kernel patch: 4-6 hours
- JavaScript integration: 3-4 hours
- Key mapping table: 1-2 hours
- Testing and debugging: 2-3 hours
- **Total: ~12-15 hours**

## Phase 3: Graphics Stack Selection

### Decision Point: Which Graphics Library?

#### Option A: DirectFB (RECOMMENDED)

**Pros:**

- Specifically designed for framebuffer, no X11 dependency
- NOMMU-friendly (can run without fork())
- Well-documented, mature codebase
- Used in embedded systems (STB, automotive)
- Has working window manager (Matchbox supports DirectFB backend)

**Cons:**

- Large codebase (~500KB compiled)
- Requires pthread support (we have this)
- May need patches for Wasm quirks

**Memory estimate:** ~3-4 MB runtime

#### Option B: nano-X / Microwindows

**Pros:**

- Smaller footprint (~200KB)
- X11-like API, easier to port apps
- Works on framebuffer

**Cons:**

- Less actively maintained
- Limited application ecosystem
- Window manager support unclear

**Memory estimate:** ~2-3 MB runtime

#### Option C: fbui (Custom Minimal)

**Pros:**

- Tiny footprint (~50KB)
- Built specifically for this use case
- Complete control over implementation

**Cons:**

- Must implement everything from scratch
- No existing application support
- High development effort

**Memory estimate:** ~1 MB runtime

**RECOMMENDATION: DirectFB** - Best balance of features, ecosystem, and NOMMU compatibility.

### Implementation: DirectFB

#### 3.1 Add DirectFB to Build System

**Modify `linux-wasm.sh`:**

```bash
"fetch-directfb"|"all-directfb"|"fetch"|"all")
    mkdir -p "$LW_SRC/directfb"
    git clone -b 1.7.7 $LW_GITFLAGS https://github.com/directfb2/DirectFB.git "$LW_SRC/directfb"
    # Apply patches if needed
    git -C "$LW_SRC/directfb" am < "$LW_ROOT/patches/directfb/0001-Wasm-NOMMU-support.patch"
handled=1;;&

"build-directfb"|"all-directfb"|"build"|"all"|"build-os")
    mkdir -p "$LW_BUILD/directfb"
    (
        cd "$LW_BUILD/directfb"

        # DirectFB configure for Wasm/NOMMU
        CC="$LW_INSTALL/llvm/bin/clang" \
        CFLAGS="--target=wasm32-unknown-unknown -fPIC -Xclang -target-feature -Xclang +atomics -Xclang -target-feature -Xclang +bulk-memory --sysroot=$LW_INSTALL/musl" \
        LDFLAGS="-Wl,-shared" \
        "$LW_SRC/directfb/configure" \
            --host=wasm32-unknown-unknown \
            --prefix=/ \
            --disable-shared \
            --enable-static \
            --with-gfxdrivers=none \
            --with-inputdrivers=linuxinput \
            --enable-fbdev \
            --disable-x11 \
            --disable-vnc \
            --disable-sdl \
            --disable-mesa \
            --enable-zlib \
            --enable-png \
            --disable-jpeg \
            --disable-gif

        make -j $LW_JOBS_BUSYBOX_COMPILE
        mkdir -p "$LW_INSTALL/directfb"
        DESTDIR="$LW_INSTALL/directfb" make install
    )
handled=1;;&
```

#### 3.2 DirectFB Patches Needed

**Create `patches/directfb/0001-Wasm-NOMMU-support.patch`:**

Key modifications:

1. Replace fork() with clone(CLONE_VM | CLONE_VFORK)
2. Disable any mmap() with MAP_PRIVATE
3. Replace vfork() calls if any
4. Ensure all code is PIC-compatible
5. Disable shared memory segments (use malloc instead)

#### 3.3 Test Applications

Port these DirectFB examples to test graphics stack:

1. **df_andi** - Simple animation test
2. **df_fire** - Fire effect demo
3. **df_palette** - Color test
4. **df_window** - Window system test

#### 3.4 Integration

Update initramfs to include DirectFB:

- Libraries in `/lib`
- Utilities in `/usr/bin`
- Config in `/etc/directfbrc`

### Estimated Effort

- DirectFB patches: 8-10 hours
- Build system integration: 3-4 hours
- Testing and debugging: 6-8 hours
- **Total: ~20-24 hours**

## Phase 4: Window Manager

### Requirements Analysis

**NOMMU-compatible window managers:**

1. **Matchbox** (RECOMMENDED)

   - Designed for embedded systems
   - Has DirectFB backend
   - Simple, single-window focus model
   - Active project (used in Yocto)
   - Small footprint (~500KB)

2. **fbpanel**

   - Lightweight panel for framebuffer
   - Works with Matchbox
   - System tray, taskbar, etc.

3. **Custom WM**
   - Write minimal WM using DirectFB
   - Implement only needed features
   - Could be done in ~2000 lines of C

**RECOMMENDATION: Matchbox + fbpanel**

### Implementation: Matchbox Window Manager

#### 4.1 Dependencies

Matchbox requires:

- DirectFB (Phase 3)
- libpng (for decorations)
- expat (for config parsing)

**Add to build system:**

```bash
"fetch-matchbox"|"all-matchbox"|"fetch"|"all")
    # libpng
    mkdir -p "$LW_SRC/libpng"
    git clone -b v1.6.40 $LW_GITFLAGS https://github.com/glennrp/libpng.git "$LW_SRC/libpng"

    # expat
    mkdir -p "$LW_SRC/expat"
    git clone -b R_2_5_0 $LW_GITFLAGS https://github.com/libexpat/libexpat.git "$LW_SRC/expat"

    # matchbox-window-manager
    mkdir -p "$LW_SRC/matchbox-wm"
    git clone https://git.yoctoproject.org/matchbox-window-manager "$LW_SRC/matchbox-wm"
    git -C "$LW_SRC/matchbox-wm" am < "$LW_ROOT/patches/matchbox/0001-Wasm-NOMMU-support.patch"
handled=1;;&
```

#### 4.2 Matchbox Patches

**Create `patches/matchbox/0001-Wasm-NOMMU-support.patch`:**

1. Replace fork() with clone()
2. Ensure static linking
3. Remove any vfork() calls
4. Test DirectFB integration

#### 4.3 Window Manager Features

Essential features for desktop:

- Window decorations (title bar, close button)
- Window stacking and focus
- Keyboard focus management
- Mouse-based window operations (move, resize, close)
- Virtual keyboard support (for touch if needed later)

#### 4.4 Configuration

`/etc/matchbox/session`:

```bash
#!/bin/sh
# Start Matchbox window manager with DirectFB backend
matchbox-window-manager -use_titlebar yes &

# Wait for WM to start
sleep 1

# Launch initial applications
fbterm &
```

### Estimated Effort

- Port dependencies (libpng, expat): 4-6 hours
- Matchbox patches and build: 8-10 hours
- Configuration and integration: 3-4 hours
- Testing: 4-5 hours
- **Total: ~20-25 hours**

## Phase 5: Desktop Applications

### Priority Applications

#### 5.1 Terminal Emulator (HIGHEST PRIORITY)

**Option A: FbTerm**

- Direct framebuffer terminal
- UTF-8 support
- Fast text rendering

**Option B: rxvt-unicode (urxvt) with DirectFB**

- Feature-rich terminal
- Good keyboard handling

**RECOMMENDATION: FbTerm** (simpler, framebuffer-native)

#### 5.2 Web Browser

**Option A: Links2 (RECOMMENDED)**

- Has framebuffer graphics mode
- JavaScript support (basic)
- Small footprint (~2MB)
- Can display images, tables, frames
- Active project

**Option B: NetSurf**

- Modern web engine
- Full CSS support
- Larger footprint (~8MB)
- May require more memory than available

**Option C: Dillo**

- Very lightweight
- No JavaScript
- Basic HTML/CSS only

**RECOMMENDATION: Links2** for balance of features and size.

#### 5.3 Image Viewer

**feh with DirectFB backend**

- PNG/JPEG support
- Minimal UI
- Fast loading

Or custom viewer using DirectFB image loading.

#### 5.4 Text Editor

**nano** - Already in BusyBox, just needs DirectFB frontend

Or **joe** - Lightweight, WordStar-like keybindings

#### 5.5 File Manager

**Option A: MC (Midnight Commander)**

- Full-featured, dual-pane
- DirectFB capable (via ncurses)

**Option B: Custom DirectFB file browser**

- Built specifically for this project
- Minimal features (list, open, delete, copy)

**RECOMMENDATION: MC** if memory allows, otherwise custom.

#### 5.6 Calculator / Demo Apps

Simple DirectFB applications to demonstrate the system:

- Calculator
- Clock
- System monitor
- Image slideshow

### Application Porting Guide

**Standard porting steps for each app:**

1. **Replace fork() calls:**

```c
// Before:
pid = fork();

// After:
pid = clone(child_fn, NULL, CLONE_VM | CLONE_VFORK | SIGCHLD, arg);
```

2. **Ensure PIC compilation:**

```bash
CFLAGS="-fPIC" LDFLAGS="-Wl,-shared"
```

3. **Static linking only:**

```bash
--disable-shared --enable-static
```

4. **Test in NOMMU environment:**

- No assumptions about address space isolation
- All globals must be in shared memory
- Use mutexes for synchronization

### Estimated Effort per Application

- Terminal (FbTerm): 6-8 hours
- Browser (Links2): 10-12 hours
- Image viewer: 4-6 hours
- Text editor: 4-6 hours
- File manager: 8-10 hours
- Demo apps: 4-6 hours each
- **Total: ~50-65 hours**

## Phase 6: Optimization & Polish

### Performance Improvements

#### 6.1 Dirty Rectangle Tracking

**Problem:** Currently redrawing entire 800x600 framebuffer at 30 FPS = ~56 MB/s bandwidth.

**Solution:** Track dirty regions, only update changed areas.

**Kernel side:**

```c
struct fb_dirty_rect {
    int x, y, width, height;
};

void wasm_driver_fb_update_region(void *pixels,
                                   int x, int y,
                                   int width, int height,
                                   int stride);
```

**Expected improvement:** 5-10x reduction in data transfer for typical desktop use.

#### 6.2 Double Buffering Optimization

**Current:** Single buffer with deferred I/O.

**Improved:** True double buffering with explicit swap:

- Application draws to back buffer
- Swap on vsync-equivalent (requestAnimationFrame)
- Eliminates tearing artifacts

#### 6.3 WebGL Acceleration (Optional)

**Use WebGL shader to:**

- Convert BGRA→RGBA on GPU
- Apply color correction
- Scale framebuffer if needed

**Expected improvement:** 2-3x faster rendering, smoother animation.

#### 6.4 Memory Optimization

**Current memory usage estimate:**

- Kernel: ~5 MB
- Framebuffer: ~2 MB
- DirectFB: ~4 MB
- Matchbox: ~1 MB
- Applications: ~10-15 MB
- **Total: ~22-27 MB**

**Optimization targets:**

- Kernel CONFIG tuning (disable unused features)
- Aggressive compiler optimization (-Os)
- Strip all binaries
- Compress initramfs with xz (better than gzip)

**Goal:** Stay under 25 MB for comfortable operation with 30 MB limit.

### User Experience Polish

#### 6.5 Boot Splash Screen

Replace text boot with graphical splash:

- Show Linux logo
- Progress bar
- Boot messages in styled font

#### 6.6 Desktop Theme

Design consistent look:

- Matchbox theme for window decorations
- Color scheme for all applications
- Icon set (minimal, SVG-based)

#### 6.7 Keyboard Shortcuts

Define standard shortcuts:

- Alt+Tab: Switch windows
- Ctrl+Alt+T: Open terminal
- Alt+F4: Close window
- Super+D: Show desktop

#### 6.8 Demo Showcase

Create demo that shows off capabilities:

1. Boot to desktop
2. Open terminal
3. Run system monitor showing CPU/memory
4. Open image viewer with sample images
5. Launch browser, load local HTML page
6. Open multiple windows, demonstrate WM

### Estimated Effort

- Dirty rectangle tracking: 6-8 hours
- Double buffering: 4-5 hours
- WebGL acceleration: 8-10 hours
- Memory optimization: 6-8 hours
- Boot splash: 3-4 hours
- Theme design: 8-10 hours
- Keyboard shortcuts: 3-4 hours
- Demo creation: 4-6 hours
- **Total: ~45-60 hours**

## Total Project Timeline

### Phase Summary

| Phase     | Description               | Effort (hours)    | Priority |
| --------- | ------------------------- | ----------------- | -------- |
| **2**     | Input Subsystem           | 12-15             | CRITICAL |
| **3**     | Graphics Stack (DirectFB) | 20-24             | HIGH     |
| **4**     | Window Manager (Matchbox) | 20-25             | HIGH     |
| **5**     | Desktop Applications      | 50-65             | MEDIUM   |
| **6**     | Optimization & Polish     | 45-60             | LOW      |
| **TOTAL** |                           | **147-189 hours** |          |

### Development Phases

**Sprint 1: Input Foundation (Week 1)**

- Complete Phase 2 (Input Subsystem)
- Milestone: Mouse and keyboard working in framebuffer console

**Sprint 2: Graphics Stack (Week 2-3)**

- Complete Phase 3 (DirectFB)
- Milestone: DirectFB demos running

**Sprint 3: Window Manager (Week 3-4)**

- Complete Phase 4 (Matchbox)
- Milestone: Multiple windows, basic desktop

**Sprint 4: Applications (Week 5-7)**

- Port essential applications
- Milestone: Usable desktop environment

**Sprint 5: Polish (Week 8-9)**

- Optimization and user experience
- Milestone: Production-ready desktop

**Total estimated time: 8-9 weeks of full-time development**

## Risk Assessment & Mitigation

### High Risk Issues

1. **Memory constraints too tight**

   - **Risk:** 30MB not enough for all components
   - **Mitigation:** Aggressive optimization, remove non-essential features
   - **Fallback:** Increase initial memory allocation in index.html (requires testing)

2. **DirectFB incompatibility with NOMMU**

   - **Risk:** DirectFB makes assumptions about fork() behavior
   - **Mitigation:** Early testing, willingness to patch extensively
   - **Fallback:** Fall back to nano-X or custom graphics library

3. **Application porting difficulties**

   - **Risk:** Applications depend heavily on fork()/mmap()
   - **Mitigation:** Choose NOMMU-friendly applications, use clone()
   - **Fallback:** Write custom minimal applications

4. **Performance issues**
   - **Risk:** Framebuffer updates too slow for interactive use
   - **Mitigation:** Dirty rectangle tracking, WebGL acceleration
   - **Fallback:** Reduce resolution, optimize rendering path

### Medium Risk Issues

1. **Keyboard mapping complexity**
   - **Risk:** JavaScript keycodes don't map cleanly to Linux
   - **Mitigation:** Comprehensive mapping table, testing
2. **Mouse pointer rendering**
   - **Risk:** Hardware cursor not available, software cursor slow
   - **Mitigation:** Optimize cursor compositing
3. **Memory leaks**
   - **Risk:** Long-running desktop accumulates leaks, runs out of memory
   - **Mitigation:** Thorough testing, valgrind in host build

## Next Immediate Actions

### Action Items (Priority Order)

1. **[CRITICAL]** Complete current build if not done:

```bash
./linux-wasm.sh build-os
cd runtime
python3 server.py 8000
# Test framebuffer console works
```

2. **[CRITICAL]** Start Phase 2 (Input):

   - Create kernel input driver patch
   - Implement JavaScript event capture
   - Build and test

3. **[HIGH]** Research DirectFB NOMMU compatibility:

   - Clone DirectFB source
   - Audit for fork()/vfork() calls
   - Identify required patches

4. **[HIGH]** Create detailed patch templates:

   - Standard clone() replacement pattern
   - PIC/shared build configuration
   - Test framework for NOMMU apps

5. **[MEDIUM]** Set up application porting workspace:
   - Script to download and prepare app sources
   - Common patch set for NOMMU
   - Testing checklist

### Success Criteria Checklist

- [ ] Mouse moves cursor on screen
- [ ] Keyboard types in framebuffer console
- [ ] DirectFB demos run without crashes
- [ ] Matchbox WM manages multiple windows
- [ ] Terminal emulator launches and works
- [ ] Browser loads and displays HTML page
- [ ] System runs for >5 minutes without crash
- [ ] Memory usage stays under 28MB
- [ ] Framerate acceptable (>20 FPS)
- [ ] Desktop is demonstrably useful

## Conclusion

This plan provides a comprehensive roadmap from current framebuffer foundation to a fully functional desktop environment. The phased approach allows for incremental progress and testing, with clear milestones and fallback options for high-risk items.

**Key success factors:**

1. Strict adherence to NOMMU constraints (clone instead of fork)
2. Careful memory budget management
3. Early and frequent testing
4. Willingness to patch/modify applications
5. Realistic scope management (choose simple apps)

**Expected outcome:** A working, albeit basic, Linux desktop running entirely in the web browser, demonstrating that a real operating system can run in WebAssembly without emulation.
