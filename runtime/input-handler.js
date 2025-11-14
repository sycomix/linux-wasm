// SPDX-License-Identifier: GPL-2.0-only

/**
 * Input handling for Linux/Wasm
 * 
 * Maps browser keyboard and mouse events to Linux input events.
 * Handles scancode translation and event injection into the kernel.
 */

class WasmInputHandler {
  constructor(canvas, linuxInstance) {
    this.canvas = canvas;
    this.linux = linuxInstance;
    this.mouseX = 0;
    this.mouseY = 0;
    this.mouseButtons = 0;
    
    // Make canvas focusable
    this.canvas.setAttribute('tabindex', '0');
    
    // Bind event handlers
    this.setupKeyboard();
    this.setupMouse();
    
    // Focus canvas initially
    this.canvas.focus();
  }

  /**
   * JavaScript keyCode to Linux scancode mapping
   * Based on standard PC keyboard scancodes (Set 1)
   * See: include/uapi/linux/input-event-codes.h
   */
  static KEY_CODE_MAP = {
    // Special keys
    8: 14,   // KEY_BACKSPACE
    9: 15,   // KEY_TAB
    13: 28,  // KEY_ENTER
    16: 42,  // KEY_LEFTSHIFT
    17: 29,  // KEY_LEFTCTRL
    18: 56,  // KEY_LEFTALT
    20: 58,  // KEY_CAPSLOCK
    27: 1,   // KEY_ESC
    32: 57,  // KEY_SPACE
    33: 104, // KEY_PAGEUP
    34: 109, // KEY_PAGEDOWN
    35: 107, // KEY_END
    36: 102, // KEY_HOME
    37: 105, // KEY_LEFT
    38: 103, // KEY_UP
    39: 106, // KEY_RIGHT
    40: 108, // KEY_DOWN
    45: 110, // KEY_INSERT
    46: 111, // KEY_DELETE
    
    // Function keys
    112: 59,  // KEY_F1
    113: 60,  // KEY_F2
    114: 61,  // KEY_F3
    115: 62,  // KEY_F4
    116: 63,  // KEY_F5
    117: 64,  // KEY_F6
    118: 65,  // KEY_F7
    119: 66,  // KEY_F8
    120: 67,  // KEY_F9
    121: 68,  // KEY_F10
    122: 87,  // KEY_F11
    123: 88,  // KEY_F12
    
    // Number row (top of keyboard)
    48: 11,  // KEY_0
    49: 2,   // KEY_1
    50: 3,   // KEY_2
    51: 4,   // KEY_3
    52: 5,   // KEY_4
    53: 6,   // KEY_5
    54: 7,   // KEY_6
    55: 8,   // KEY_7
    56: 9,   // KEY_8
    57: 10,  // KEY_9
    
    // Letters (A-Z)
    65: 30,  // KEY_A
    66: 48,  // KEY_B
    67: 46,  // KEY_C
    68: 32,  // KEY_D
    69: 18,  // KEY_E
    70: 33,  // KEY_F
    71: 34,  // KEY_G
    72: 35,  // KEY_H
    73: 23,  // KEY_I
    74: 36,  // KEY_J
    75: 37,  // KEY_K
    76: 38,  // KEY_L
    77: 50,  // KEY_M
    78: 49,  // KEY_N
    79: 24,  // KEY_O
    80: 25,  // KEY_P
    81: 16,  // KEY_Q
    82: 19,  // KEY_R
    83: 31,  // KEY_S
    84: 20,  // KEY_T
    85: 22,  // KEY_U
    86: 47,  // KEY_V
    87: 17,  // KEY_W
    88: 45,  // KEY_X
    89: 21,  // KEY_Y
    90: 44,  // KEY_Z
    
    // Symbol keys
    186: 39,  // KEY_SEMICOLON (;:)
    187: 13,  // KEY_EQUAL (=+)
    188: 51,  // KEY_COMMA (,<)
    189: 12,  // KEY_MINUS (-_)
    190: 52,  // KEY_DOT (.>)
    191: 53,  // KEY_SLASH (/?)
    192: 41,  // KEY_GRAVE (`~)
    219: 26,  // KEY_LEFTBRACE ([{)
    220: 43,  // KEY_BACKSLASH (\|)
    221: 27,  // KEY_RIGHTBRACE (]})
    222: 40,  // KEY_APOSTROPHE ('")
    
    // Numpad
    96: 82,   // KEY_KP0
    97: 79,   // KEY_KP1
    98: 80,   // KEY_KP2
    99: 81,   // KEY_KP3
    100: 75,  // KEY_KP4
    101: 76,  // KEY_KP5
    102: 77,  // KEY_KP6
    103: 71,  // KEY_KP7
    104: 72,  // KEY_KP8
    105: 73,  // KEY_KP9
    106: 55,  // KEY_KPASTERISK (*)
    107: 78,  // KEY_KPPLUS (+)
    109: 74,  // KEY_KPMINUS (-)
    110: 83,  // KEY_KPDOT (.)
    111: 98,  // KEY_KPSLASH (/)
    144: 69,  // KEY_NUMLOCK
  };

  setupKeyboard() {
    this.canvas.addEventListener('keydown', (e) => {
      const scancode = WasmInputHandler.KEY_CODE_MAP[e.keyCode];
      if (scancode !== undefined) {
        e.preventDefault();
        this.linux.input_keyboard(scancode, 1);
      }
    });

    this.canvas.addEventListener('keyup', (e) => {
      const scancode = WasmInputHandler.KEY_CODE_MAP[e.keyCode];
      if (scancode !== undefined) {
        e.preventDefault();
        this.linux.input_keyboard(scancode, 0);
      }
    });
  }

  setupMouse() {
    // Mouse movement
    this.canvas.addEventListener('mousemove', (e) => {
      const rect = this.canvas.getBoundingClientRect();
      this.mouseX = Math.floor((e.clientX - rect.left) * (800 / rect.width));
      this.mouseY = Math.floor((e.clientY - rect.top) * (600 / rect.height));
      
      // Clamp to valid range
      this.mouseX = Math.max(0, Math.min(799, this.mouseX));
      this.mouseY = Math.max(0, Math.min(599, this.mouseY));
      
      this.linux.input_mouse(this.mouseX, this.mouseY, this.mouseButtons, 0);
    });

    // Mouse buttons
    this.canvas.addEventListener('mousedown', (e) => {
      e.preventDefault();
      this.mouseButtons |= (1 << e.button);
      this.linux.input_mouse(this.mouseX, this.mouseY, this.mouseButtons, 0);
      
      // Ensure canvas has focus for keyboard events
      this.canvas.focus();
    });

    this.canvas.addEventListener('mouseup', (e) => {
      e.preventDefault();
      this.mouseButtons &= ~(1 << e.button);
      this.linux.input_mouse(this.mouseX, this.mouseY, this.mouseButtons, 0);
    });

    // Mouse wheel
    this.canvas.addEventListener('wheel', (e) => {
      e.preventDefault();
      // Normalize wheel delta (positive = scroll up, negative = scroll down)
      const delta = e.deltaY > 0 ? -1 : (e.deltaY < 0 ? 1 : 0);
      if (delta !== 0) {
        this.linux.input_mouse(this.mouseX, this.mouseY, this.mouseButtons, delta);
      }
    });

    // Prevent context menu on right-click
    this.canvas.addEventListener('contextmenu', (e) => {
      e.preventDefault();
    });

    // Mouse enter/leave - could be used to show/hide cursor
    this.canvas.addEventListener('mouseenter', (e) => {
      // Optional: notify kernel that mouse entered canvas
    });

    this.canvas.addEventListener('mouseleave', (e) => {
      // Optional: notify kernel that mouse left canvas
      // Could release all buttons on leave
    });
  }

  /**
   * Programmatically inject a key press
   * @param {string} key - Character to type
   */
  injectKey(key) {
    const keyCode = key.charCodeAt(0);
    const scancode = WasmInputHandler.KEY_CODE_MAP[keyCode];
    if (scancode !== undefined) {
      this.linux.input_keyboard(scancode, 1);
      // Brief delay then release
      setTimeout(() => this.linux.input_keyboard(scancode, 0), 50);
    }
  }

  /**
   * Inject a full string as keystrokes
   * @param {string} text - Text to type
   */
  injectText(text) {
    let delay = 0;
    for (let char of text) {
      setTimeout(() => this.injectKey(char), delay);
      delay += 100;
    }
  }
}
<<<<<<< HEAD

// Export setup function for use in HTML
function setupInputHandler(canvas, linuxInstance) {
  return new WasmInputHandler(canvas, linuxInstance);
}
=======
>>>>>>> 9c9391c134ad7c418a6fe6a9a8e4b5e8f5885024
