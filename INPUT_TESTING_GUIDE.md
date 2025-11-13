# Input Subsystem Testing Guide

**Purpose:** Verify keyboard and mouse input work correctly with the framebuffer.

## Prerequisites

1. **Complete build with input patches:**

```bash
# If kernel sources already fetched, apply new patches manually
cd workspace/src/kernel
git am < ../../../patches/kernel/0015-Add-Wasm-input-support.patch
git am < ../../../patches/kernel/0016-Update-wasm_defconfig-for-input.patch

# Or re-fetch to apply all patches cleanly
cd ../../..
rm -rf workspace/src/kernel
./linux-wasm.sh fetch-kernel

# Rebuild kernel
./linux-wasm.sh build-kernel

# Rebuild initramfs (if init script changed)
./linux-wasm.sh build-initramfs

# Copy artifacts to runtime
cp workspace/install/kernel/vmlinux.wasm runtime/
cp workspace/install/initramfs/initramfs.cpio.gz runtime/
```

2. **Verify JavaScript files are in place:**

```bash
ls -l runtime/input-handler.js
ls -l runtime/linux.js
ls -l runtime/linux-worker.js
ls -l runtime/index.html
```

## Launch System

```bash
cd runtime
python3 server.py 8000
```

Open browser to: http://127.0.0.1:8000/

## Test Procedure

### Test 1: System Boot

**Expected:**

- Terminal shows boot messages
- System boots to shell prompt
- Canvas element initially hidden

**Pass criteria:**

- [ ] No JavaScript errors in browser console (F12)
- [ ] System boots successfully
- [ ] Shell prompt appears

### Test 2: Framebuffer Activation

**Actions:**

- Wait for framebuffer to initialize
- Look for "Framebuffer mode activated" message

**Expected:**

- Canvas becomes visible
- Terminal hides
- Linux penguin logo appears on canvas
- Console text rendered in framebuffer

**Pass criteria:**

- [ ] Canvas displays properly
- [ ] Boot messages visible on canvas
- [ ] No corruption or artifacts

### Test 3: Input Devices Detection

**Actions in console:**

```bash
# Check input devices exist
ls -l /dev/input/

# Should see:
# event0 (keyboard)
# event1 (mouse)
# mice (mouse legacy interface)

# Check kernel recognized drivers
dmesg | grep -i "input\|wasm"

# Should see:
# "Wasm keyboard driver initialized"
# "Wasm mouse driver initialized"
```

**Pass criteria:**

- [ ] `/dev/input/event0` exists
- [ ] `/dev/input/event1` exists
- [ ] `/dev/input/mice` exists
- [ ] dmesg shows input drivers loaded

### Test 4: Keyboard Input

**Actions:**

```bash
# Type some text in the shell
echo "Hello from keyboard!"

# Test special keys
# Press Tab for completion
# Press Up/Down arrows for history
# Press Ctrl+C to interrupt
```

**Expected:**

- Keys appear as typed
- Special keys work correctly
- No dropped keystrokes
- No repeated characters (unless holding key)

**Pass criteria:**

- [ ] Letters and numbers work
- [ ] Special characters work (Shift+keys)
- [ ] Backspace works
- [ ] Enter executes commands
- [ ] Tab completion works
- [ ] Arrow keys work
- [ ] Ctrl+C works

**Advanced test:**

```bash
# Monitor raw keyboard events
hexdump -C /dev/input/event0

# Type some keys and watch events
# Format: timestamp (16 bytes) + type (2) + code (2) + value (4)
# Type 0x01 = EV_KEY
# Value 1 = press, 0 = release
```

**Pass criteria:**

- [ ] Each keypress generates press event (value=1)
- [ ] Each release generates release event (value=0)
- [ ] Scancodes are correct (see input-handler.js mapping)

### Test 5: Mouse Movement

**Actions:**

- Move mouse over canvas
- Watch for cursor movement (if visible)

**Expected:**

- Mouse moves smoothly
- No lag or stuttering
- Coordinates track accurately

**Pass criteria:**

- [ ] Mouse position updates in real-time
- [ ] No visible lag (<50ms)
- [ ] Smooth movement across entire canvas

**Monitor mouse events:**

```bash
# Watch raw mouse events
hexdump -C /dev/input/mice

# Or for detailed events:
hexdump -C /dev/input/event1

# Move mouse around and watch bytes change
```

**Pass criteria:**

- [ ] Movement generates events
- [ ] X and Y coordinates are reasonable
- [ ] Events stop when mouse stops

### Test 6: Mouse Buttons

**Actions:**

- Click left button
- Click right button
- Click middle button (if available)
- Try drag operations

**Expected:**

- Each button press/release generates event
- No missed clicks
- No phantom clicks

**Test commands:**

```bash
# Monitor button events
cat /dev/input/mice | od -t x1

# Or detailed view:
hexdump -C /dev/input/event1

# Click buttons and watch output
```

**Pass criteria:**

- [ ] Left click detected (bit 0)
- [ ] Right click detected (bit 1)
- [ ] Middle click detected (bit 2)
- [ ] Press and release both detected

### Test 7: Mouse Wheel

**Actions:**

- Scroll up
- Scroll down

**Expected:**

- Wheel events generated
- Direction correct (positive=up, negative=down)

**Test:**

```bash
hexdump -C /dev/input/event1
# Scroll wheel and watch REL_WHEEL events
```

**Pass criteria:**

- [ ] Scroll up generates positive values
- [ ] Scroll down generates negative values
- [ ] Magnitude reasonable (typically ±1)

### Test 8: Focus Management

**Actions:**

- Click on canvas
- Click outside canvas
- Use Tab key to move focus

**Expected:**

- Canvas captures input when focused
- Keyboard events only work when canvas focused
- Mouse events work whenever over canvas

**Pass criteria:**

- [ ] Canvas accepts focus on click
- [ ] Keyboard only works when focused
- [ ] Mouse works when over canvas area

### Test 9: Coordinate Mapping

**Actions:**

```bash
# Read mouse position
cat /proc/bus/input/devices | grep -A 10 "Mouse"

# Or use evtest if available:
# evtest /dev/input/event1
```

**Test corners:**

- Move mouse to top-left (should be near 0,0)
- Move to top-right (should be near 800,0)
- Move to bottom-left (should be near 0,600)
- Move to bottom-right (should be near 800,600)

**Pass criteria:**

- [ ] Top-left corner: X≈0, Y≈0
- [ ] Top-right corner: X≈800, Y≈0
- [ ] Bottom-left corner: X≈0, Y≈600
- [ ] Bottom-right corner: X≈800, Y≈600
- [ ] Center: X≈400, Y≈300

### Test 10: Stress Testing

**Rapid keyboard input:**

```bash
# Type rapidly
yes | head -100

# Mash keyboard
# (random key presses)
```

**Rapid mouse input:**

- Move mouse rapidly across canvas
- Click buttons rapidly
- Scroll wheel rapidly

**Expected:**

- No crashes
- No kernel panics
- Events processed smoothly

**Pass criteria:**

- [ ] System remains stable
- [ ] No memory leaks (check browser memory)
- [ ] Event queue doesn't overflow

### Test 11: Special Key Combinations

**Test these combinations:**

- Ctrl+C (interrupt)
- Ctrl+Z (suspend)
- Ctrl+D (EOF)
- Alt+key (if relevant)
- Shift+key (capitals)

**Pass criteria:**

- [ ] Ctrl+C interrupts running command
- [ ] Ctrl+D exits shell (or closes input)
- [ ] Shift produces capitals
- [ ] All modifier keys work

## Common Issues and Solutions

### Issue: Keyboard not working

**Symptoms:** No response to key presses

**Debug:**

1. Check browser console for JavaScript errors
2. Verify canvas has focus (click on it)
3. Check kernel loaded drivers: `dmesg | grep input`
4. Verify scancode mapping in input-handler.js

**Solutions:**

- Click canvas to focus it
- Check if kernel module loaded
- Verify wasm_input_keyboard_event exported

### Issue: Mouse not working

**Symptoms:** No mouse movement or clicks registered

**Debug:**

1. Check `/dev/input/mice` exists
2. Verify mouse driver loaded: `dmesg | grep mouse`
3. Test with: `cat /dev/input/mice | od -t x1`

**Solutions:**

- Ensure mouse over canvas area
- Check coordinate mapping logic
- Verify wasm_input_mouse_event exported

### Issue: Wrong characters typed

**Symptoms:** Different characters appear than keys pressed

**Debug:**

1. Check browser keyCode vs Linux scancode mapping
2. Keyboard layout issues?
3. Test with hexdump to see raw scancodes

**Solutions:**

- Update KEY_CODE_MAP in input-handler.js
- Check for keyboard layout conflicts
- Use evtest to verify scancodes

### Issue: Lag or stuttering

**Symptoms:** Delayed response to input

**Debug:**

1. Check CPU usage in browser
2. Monitor event queue depth
3. Check for JavaScript errors

**Solutions:**

- Reduce framebuffer update rate
- Optimize event handling
- Check system load

### Issue: Events not reaching kernel

**Symptoms:** `/dev/input/event*` shows no activity

**Debug:**

```bash
# Check if device nodes exist
ls -l /dev/input/

# Check kernel drivers loaded
cat /proc/bus/input/devices

# Check kernel received export
# (Should not see "Event received but device not ready")
dmesg | grep -i "not ready"
```

**Solutions:**

- Verify patch applied correctly
- Check driver initialization order
- Verify exports in vmlinux.wasm:
  ```bash
  llvm-nm workspace/build/kernel/vmlinux | grep wasm_input
  ```

## Performance Benchmarks

### Keyboard latency test:

```bash
# Measure time between keypress and response
# (Requires external tools or observation)
# Target: <50ms end-to-end
```

### Mouse latency test:

```bash
# Visual observation of cursor lag
# Target: <30ms for pointer movement
```

### Event throughput:

```bash
# Type continuously for 10 seconds
# Count events received
# Target: >100 events/second sustained
```

## Success Criteria Summary

**Phase 2 Complete when ALL of these pass:**

- [x] Kernel builds with input patches
- [x] JavaScript integration compiles without errors
- [ ] System boots without crashes
- [ ] Input device nodes appear in `/dev/input/`
- [ ] Keyboard events detected in `/dev/input/event0`
- [ ] Mouse events detected in `/dev/input/event1`
- [ ] Keyboard types correctly in shell
- [ ] Mouse moves cursor (when visible)
- [ ] Mouse buttons work
- [ ] Mouse wheel works
- [ ] Special keys work (arrows, Ctrl, etc.)
- [ ] No kernel panics under normal use
- [ ] Latency acceptable (<50ms keyboard, <30ms mouse)
- [ ] System stable under stress testing

## Next Steps

Once all tests pass, proceed to:

**Phase 3: DirectFB Graphics Stack**

- Port DirectFB library
- Test with sample applications
- See `DESKTOP_IMPLEMENTATION_PLAN.md` for details

## Debugging Commands Reference

```bash
# List all input devices
cat /proc/bus/input/devices

# Monitor all input events
for dev in /dev/input/event*; do
  echo "=== $dev ===" &
  hexdump -C $dev &
done

# Check kernel log for input messages
dmesg | grep -E "input|keyboard|mouse|wasm"

# Verify exports in kernel
llvm-nm workspace/build/kernel/vmlinux | grep -E "wasm_input|keyboard|mouse"

# Check JavaScript console (F12)
# Look for errors, warnings
# Check linuxOS and inputHandler objects exist:
console.log(window.linuxOS);
console.log(window.inputHandler);

# Test input injection from console:
window.inputHandler.injectKey('A');
window.inputHandler.injectText("hello");
```

## Resources

- Kernel input subsystem: `workspace/src/kernel/Documentation/input/`
- Linux input event codes: `workspace/src/kernel/include/uapi/linux/input-event-codes.h`
- Input handler source: `runtime/input-handler.js`
- Browser keyboard events: https://developer.mozilla.org/en-US/docs/Web/API/KeyboardEvent
- Browser mouse events: https://developer.mozilla.org/en-US/docs/Web/API/MouseEvent
