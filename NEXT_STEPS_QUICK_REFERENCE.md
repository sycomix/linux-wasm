# Quick Reference: Next Steps for Desktop Environment

**Current Status:** Framebuffer foundation complete (Phase 1 ✅)  
**Next Phase:** Input Subsystem (Phase 2) ⬅️ **START HERE**

## Immediate Action Items

### 1. Complete Current Build (If Needed)

```bash
# Check if LLVM build is still running
ps aux | grep ninja

# Once LLVM completes, build the OS
./linux-wasm.sh build-os

# This will:
# - Build kernel with framebuffer support (patches 0013, 0014)
# - Build musl libc
# - Build BusyBox
# - Create initramfs

# Test current system
cd runtime
python3 server.py 8000
# Open http://127.0.0.1:8000/
# Should see framebuffer console with Linux penguin logo
```

### 2. Phase 2: Input Subsystem (Next 1-2 days)

#### Step 2.1: Create Kernel Input Driver

Create `patches/kernel/0015-Add-Wasm-input-support.patch`:

**Keyboard driver skeleton:**

```c
// arch/wasm/drivers/input_kbd_wasm.c
#include <linux/input.h>
#include <linux/platform_device.h>

static struct input_dev *kbd_dev;

// Called from JavaScript when key event occurs
void wasm_input_keyboard_event(int scancode, int pressed) {
    input_event(kbd_dev, EV_KEY, scancode, pressed);
    input_sync(kbd_dev);
}
EXPORT_SYMBOL(wasm_input_keyboard_event);

// Device registration
static int __init kbd_wasm_init(void) {
    kbd_dev = input_allocate_device();
    kbd_dev->name = "Wasm Keyboard";
    kbd_dev->id.bustype = BUS_HOST;

    // Set supported keys
    set_bit(EV_KEY, kbd_dev->evbit);
    set_bit(EV_REP, kbd_dev->evbit);
    for (int i = 0; i < KEY_MAX; i++)
        set_bit(i, kbd_dev->keybit);

    return input_register_device(kbd_dev);
}
module_init(kbd_wasm_init);
```

**Mouse driver skeleton:**

```c
// arch/wasm/drivers/input_mouse_wasm.c
#include <linux/input.h>

static struct input_dev *mouse_dev;

void wasm_input_mouse_event(int x, int y, int buttons, int wheel) {
    input_report_abs(mouse_dev, ABS_X, x);
    input_report_abs(mouse_dev, ABS_Y, y);
    input_report_key(mouse_dev, BTN_LEFT, buttons & 1);
    input_report_key(mouse_dev, BTN_RIGHT, buttons & 2);
    input_report_key(mouse_dev, BTN_MIDDLE, buttons & 4);
    if (wheel)
        input_report_rel(mouse_dev, REL_WHEEL, wheel);
    input_sync(mouse_dev);
}
EXPORT_SYMBOL(wasm_input_mouse_event);

static int __init mouse_wasm_init(void) {
    mouse_dev = input_allocate_device();
    mouse_dev->name = "Wasm Mouse";

    set_bit(EV_KEY, mouse_dev->evbit);
    set_bit(EV_ABS, mouse_dev->evbit);
    set_bit(EV_REL, mouse_dev->evbit);

    set_bit(BTN_LEFT, mouse_dev->keybit);
    set_bit(BTN_RIGHT, mouse_dev->keybit);
    set_bit(BTN_MIDDLE, mouse_dev->keybit);

    input_set_abs_params(mouse_dev, ABS_X, 0, 800, 0, 0);
    input_set_abs_params(mouse_dev, ABS_Y, 0, 600, 0, 0);
    set_bit(REL_WHEEL, mouse_dev->relbit);

    return input_register_device(mouse_dev);
}
module_init(mouse_wasm_init);
```

**Update arch/wasm/drivers/Makefile:**

```makefile
obj-$(CONFIG_INPUT_WASM_KEYBOARD) += input_kbd_wasm.o
obj-$(CONFIG_INPUT_WASM_MOUSE) += input_mouse_wasm.o
```

**Update arch/wasm/drivers/Kconfig:**

```kconfig
config INPUT_WASM_KEYBOARD
    bool "Wasm keyboard driver"
    depends on WASM
    select INPUT_KEYBOARD
    help
      Keyboard input from JavaScript host

config INPUT_WASM_MOUSE
    bool "Wasm mouse driver"
    depends on WASM
    select INPUT_MOUSE
    help
      Mouse input from JavaScript host
```

**Update wasm_defconfig:**

```
CONFIG_INPUT=y
CONFIG_INPUT_KEYBOARD=y
CONFIG_INPUT_MOUSE=y
CONFIG_INPUT_MOUSEDEV=y
CONFIG_INPUT_EVDEV=y
CONFIG_INPUT_WASM_KEYBOARD=y
CONFIG_INPUT_WASM_MOUSE=y
```

#### Step 2.2: JavaScript Event Handling

**Update `runtime/index.html`** - Add after framebuffer_write function:

```javascript
// Keyboard scancode mapping (JS keyCode -> Linux scancode)
const keyCodeMap = {
  8: 14, // Backspace
  9: 15, // Tab
  13: 28, // Enter
  16: 42, // Shift
  17: 29, // Ctrl
  18: 56, // Alt
  27: 1, // Escape
  32: 57, // Space
  37: 105, // Left arrow
  38: 103, // Up arrow
  39: 106, // Right arrow
  40: 108, // Down arrow
  // Add more as needed...
  // A-Z: 30-44, 16-25, 44-50
  // 0-9: 11-2 (top row), 82-89 (numpad)
};

for (let i = 65; i <= 90; i++) {
  // A-Z keys
  const scancodes = [
    30, 48, 46, 32, 18, 33, 34, 35, 23, 36, 37, 38, 50, 49, 24, 25, 16, 19, 31,
    20, 22, 47, 17, 45, 21, 44,
  ];
  keyCodeMap[i] = scancodes[i - 65];
}

for (let i = 48; i <= 57; i++) {
  // 0-9 keys
  keyCodeMap[i] = i - 48 + 11;
  if (keyCodeMap[i] === 11) keyCodeMap[i] = 2; // Special case for 0
}

let mouseX = 0,
  mouseY = 0,
  mouseButtons = 0;

// Attach to canvas
const canvas = document.getElementById("framebuffer");

canvas.addEventListener("keydown", (e) => {
  e.preventDefault();
  const scancode = keyCodeMap[e.keyCode];
  if (scancode !== undefined) {
    linux.input_keyboard(scancode, 1);
  }
});

canvas.addEventListener("keyup", (e) => {
  e.preventDefault();
  const scancode = keyCodeMap[e.keyCode];
  if (scancode !== undefined) {
    linux.input_keyboard(scancode, 0);
  }
});

canvas.addEventListener("mousemove", (e) => {
  const rect = canvas.getBoundingClientRect();
  mouseX = Math.floor((e.clientX - rect.left) * (800 / rect.width));
  mouseY = Math.floor((e.clientY - rect.top) * (600 / rect.height));
  linux.input_mouse(mouseX, mouseY, mouseButtons, 0);
});

canvas.addEventListener("mousedown", (e) => {
  e.preventDefault();
  mouseButtons |= 1 << e.button;
  linux.input_mouse(mouseX, mouseY, mouseButtons, 0);
});

canvas.addEventListener("mouseup", (e) => {
  e.preventDefault();
  mouseButtons &= ~(1 << e.button);
  linux.input_mouse(mouseX, mouseY, mouseButtons, 0);
});

canvas.addEventListener("wheel", (e) => {
  e.preventDefault();
  const delta = e.deltaY > 0 ? -1 : 1;
  linux.input_mouse(mouseX, mouseY, mouseButtons, delta);
});

canvas.addEventListener("contextmenu", (e) => e.preventDefault());

// Make canvas focusable
canvas.setAttribute("tabindex", "0");
canvas.focus();
```

**Update `runtime/linux.js`** - Add to message_callbacks:

```javascript
input_keyboard_event: (message) => {
  // Forward to all CPUs that might need it
  // Usually handled by CPU 0
  if (cpus[0]) {
    cpus[0].worker.postMessage({
      method: "input_keyboard",
      scancode: message.scancode,
      pressed: message.pressed
    });
  }
},

input_mouse_event: (message) => {
  if (cpus[0]) {
    cpus[0].worker.postMessage({
      method: "input_mouse",
      x: message.x,
      y: message.y,
      buttons: message.buttons,
      wheel: message.wheel
    });
  }
}
```

**Add to linux() function return object:**

```javascript
return {
  input_keyboard: (scancode, pressed) => {
    port.postMessage({
      method: "input_keyboard_event",
      scancode: scancode,
      pressed: pressed,
    });
  },

  input_mouse: (x, y, buttons, wheel) => {
    port.postMessage({
      method: "input_mouse_event",
      x: x,
      y: y,
      buttons: buttons,
      wheel: wheel,
    });
  },
};
```

**Update `runtime/linux-worker.js`** - Add to message handlers:

```javascript
case "input_keyboard":
  if (vmlinux_instance && vmlinux_instance.exports.wasm_input_keyboard_event) {
    vmlinux_instance.exports.wasm_input_keyboard_event(
      message.scancode,
      message.pressed
    );
  }
  break;

case "input_mouse":
  if (vmlinux_instance && vmlinux_instance.exports.wasm_input_mouse_event) {
    vmlinux_instance.exports.wasm_input_mouse_event(
      message.x,
      message.y,
      message.buttons,
      message.wheel
    );
  }
  break;
```

#### Step 2.3: Build and Test

```bash
# Apply the new patch
cd workspace/src/kernel
git am < ../../../patches/kernel/0015-Add-Wasm-input-support.patch

# Rebuild kernel
cd ../../..
./linux-wasm.sh build-kernel

# Rebuild initramfs if needed
./linux-wasm.sh build-initramfs

# Copy to runtime
cp workspace/install/kernel/vmlinux.wasm runtime/
cp workspace/install/initramfs/initramfs.cpio.gz runtime/

# Test
cd runtime
python3 server.py 8000
```

**Testing checklist:**

- [ ] Keyboard types in framebuffer console
- [ ] Mouse moves (visible cursor in fbcon)
- [ ] Mouse clicks work
- [ ] Arrow keys work
- [ ] Special keys (Ctrl, Alt, etc.) work
- [ ] `/dev/input/event0` shows keyboard events: `hexdump -C /dev/input/event0`
- [ ] `/dev/input/mice` shows mouse data: `hexdump -C /dev/input/mice`

## Phase 3 Preview: DirectFB (Next 1-2 weeks)

Once input is working, move to graphics stack:

```bash
# Download DirectFB source
git clone https://github.com/directfb2/DirectFB.git workspace/src/directfb

# Audit for NOMMU issues
cd workspace/src/directfb
grep -r "fork()" .
grep -r "vfork()" .
grep -r "mmap.*MAP_PRIVATE" .

# Create patches as needed
# Add to build system
# Test with sample applications
```

## Critical Reminders

### NOMMU Constraints (ALWAYS REMEMBER!)

❌ **DO NOT USE:**

- `fork()` - Use `clone(fn, NULL, CLONE_VM | CLONE_VFORK | SIGCHLD, arg)`
- `vfork()` - Not implemented (use clone with CLONE_VFORK)
- `mmap(MAP_PRIVATE)` - No memory protection available
- Dynamic linking - Use static only

✅ **ALWAYS USE:**

- `-fPIC -Wl,-shared` for all Wasm compilation
- `clone()` with appropriate flags
- Static linking
- Shared memory for IPC

### Build Flags Reference

```bash
# Wasm compilation
CC="$LW_INSTALL/llvm/bin/clang"
CFLAGS="--target=wasm32-unknown-unknown \
        -fPIC \
        -Xclang -target-feature -Xclang +atomics \
        -Xclang -target-feature -Xclang +bulk-memory \
        --sysroot=$LW_INSTALL/musl"
LDFLAGS="-Wl,-shared"

# Kernel build
make ARCH=wasm \
     LLVM=$LW_INSTALL/llvm/bin/ \
     CROSS_COMPILE=wasm32-unknown-unknown- \
     -j8
```

### Memory Budget

- Total available: ~30 MB
- Kernel: ~5 MB
- Framebuffer: ~2 MB
- Remaining for userspace: ~23 MB
- Target usage: <25 MB

## Questions to Answer Before Proceeding

1. **Is framebuffer console currently working?**

   - Boot and check for Linux logo
   - Verify text output on Canvas

2. **Are there any build errors?**

   - Check LLVM patch applied: `workspace/install/llvm/bin/wasm-ld --help | grep script`
   - Verify kernel built: `ls -lh workspace/install/kernel/vmlinux.wasm`

3. **What's the current memory usage?**

   - Boot and check `free -m` in console
   - Monitor browser memory usage

4. **Which applications are priorities?**
   - Terminal emulator?
   - Web browser?
   - File manager?
   - Other?

## Success Criteria

### Phase 2 Complete When:

- [x] Mouse cursor visible and moves smoothly
- [x] Keyboard input works in console
- [x] Input devices appear in `/dev/input/`
- [x] No crashes or hangs
- [x] Latency acceptable (<50ms)

### Phase 3 Complete When:

- [ ] DirectFB library built and linked
- [ ] DirectFB demos run without crashes
- [ ] Graphics acceleration working
- [ ] Multiple windows can be drawn

### Phase 4 Complete When:

- [ ] Matchbox WM running
- [ ] Can create/close windows
- [ ] Can switch between windows
- [ ] Window decorations present

## Resources

- **Detailed plan:** `DESKTOP_IMPLEMENTATION_PLAN.md`
- **Current progress:** `FRAMEBUFFER_PROGRESS.md`
- **Overall roadmap:** `DESKTOP_ROADMAP.md`
- **Linux input docs:** `workspace/src/kernel/Documentation/input/`
- **DirectFB docs:** https://directfb.net/docs/

## Getting Help

If stuck:

1. Check kernel logs: `dmesg` in console
2. Check browser console for JavaScript errors
3. Verify patch applied: `git log` in component source
4. Review build output for warnings
5. Compare with working components (e.g., console driver)

---

**Next action:** Create kernel input driver patch and test keyboard/mouse events.
