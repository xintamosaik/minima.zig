"use strict";

/**
 * We share console.log to enable debugging messages in Zig/WASM.
 * Since Zig is strict with types we only allow "error codes"
 * 
 * @param {number} num - The number to log, typically an error code or status value from WASM.
 */
function console_log(num) {
    console.log(num);
}

/**
 * To bring JS API over into WASM we create an object.
 * For now it only contains our console_log function, 
 * but we could expand it with more features as needed.
 */
const importObject = {
    env: { console_log }
};

/**
 * This fetches the compiled WASM module as a file. 
 */
const response = await fetch("./index.wasm");
if (!response.ok) {
    console.error(`Failed to fetch wasm: ${response.statusText}`);
}

/**
 * The instance holds all exported functions and memory from our WASM module.
 */
const { instance } = await WebAssembly.instantiateStreaming(response, importObject);
if (!instance) {
    console.error("Failed to instantiate wasm");
}

/**
 * This is the width of the "game". We want to sync the canvas size.
 * 
 * @type {number}
 */
const width = instance.exports.width();

/**
 * This is the height of the "game". We want to sync the canvas size.
 * 
 * @type {number}
 */
const height = instance.exports.height();

/**
 * The canvas element that will exclusively be used to render the content of the WASM memory.
 * We will write pixel data directly into WASM memory and then use putImageData to copy it to the canvas.
 */
const canvas = document.getElementById("game");
if (!canvas) {
    console.error("Failed to find canvas element");
}
canvas.width = width; // Sync width
canvas.height = height; // Sync height

/**
 * The 2D rendering context for the canvas. 
 * It's used to draw the ImageData that we create from the WASM memory frame buffer.
 */
const ctx = canvas.getContext("2d");
if (!ctx) {
    console.error("Failed to get canvas context");
}

/**
 * The frame buffer is a Uint8ClampedArray that views the WASM memory directly.
 * The WASM module provides a pointer and length for the frame buffer, which we use to create this view.
 * We then create an ImageData object from this frame buffer, which can be drawn onto the canvas. 
 * 
 * FYI: Zig writes u32 pixels as RGBA bytes in little-endian memory; ImageData consumes that byte view directly.
 */
const frame = new Uint8ClampedArray(instance.exports.memory.buffer, instance.exports.framePtr(), instance.exports.frameLen());

/**
 * The ImageData object that wraps the frame buffer. This is what we will draw onto the canvas each frame.
 */
const image = new ImageData(frame, width, height);

const BUTTON_LEFT = 0;
const BUTTON_MIDDLE = 1;
const BUTTON_RIGHT = 2;

const MOUSE_BUTTON_LEFT = 1;
const MOUSE_BUTTON_MIDDLE = 2;
const MOUSE_BUTTON_RIGHT = 4;

/** 
 * Converts a DOM mouse button index into our WASM input bitmask.
 * @param {number} button - The DOM mouse button index.
 */
function mouseButtonBit(button) {
    switch (button) {
        case BUTTON_LEFT:
            return MOUSE_BUTTON_LEFT;
        case BUTTON_MIDDLE:
            return MOUSE_BUTTON_MIDDLE;
        case BUTTON_RIGHT:
            return MOUSE_BUTTON_RIGHT;
        default:
            return 0;
    }
}

const mouseInput = {
    x: 0,
    y: 0,
    buttons: 0
};

/**
 * Writes the current mouse position (relative to the canvas) into our mouseInput object.
 * This is called on mouse move, down, and up to keep the position updated.
 * The position is scaled down by the current canvas scale factor to match the game coordinates.
 * @param {MouseEvent} e 
 */
function registerMouseMovement(e) {
    mouseInput.x = Math.floor(e.offsetX / scale);
    mouseInput.y = Math.floor(e.offsetY / scale);
}
canvas.addEventListener("mousemove", registerMouseMovement);

/**
 * Besides updating the mouse position,
 * this also sets the appropriate button bit in the mouseInput.buttons bitmask when a button is pressed.
 * @param {MouseEvent} e 
 */
function registerMouseDown(e) {
    registerMouseMovement(e);
    const bit = mouseButtonBit(e.button);
    if (bit !== 0) {
        mouseInput.buttons |= bit;
    }
}
canvas.addEventListener("mousedown", registerMouseDown);

/**
 * Besides updating the mouse position, 
 * this also clears the appropriate button bit in the mouseInput.buttons bitmask when a button is released.
 * @param {MouseEvent} e 
 */
function registerMouseUp(e) {
    registerMouseMovement(e);
    const bit = mouseButtonBit(e.button);
    if (bit !== 0) {
        mouseInput.buttons &= ~bit;
    }
}
canvas.addEventListener("mouseup", registerMouseUp);

// If the mouse leaves the canvas, we want to clear all button state to avoid "stuck" buttons 
// when the user releases outside the canvas.
canvas.addEventListener("mouseleave", () => { mouseInput.buttons = 0; });

// Prevent the context menu from appearing on right-click, 
// since we want to use right-click in our game.
canvas.addEventListener("contextmenu", (e) => { e.preventDefault(); });

const INPUT_UP = 0;
const INPUT_DOWN = 1;
const INPUT_LEFT = 2;
const INPUT_RIGHT = 3;
const INPUT_CONFIRM = 4;
const INPUT_CANCEL = 5;
const INPUT_RESET = 6;

/**
 * The input buffer is a Uint8Array that views the WASM memory directly, starting at the pointer and length provided by the WASM module.
 * We will write the current keyboard and mouse input state into this buffer each frame before ticking the game logic.
 * The WASM module will read from this buffer to know what inputs are active.
 */
const input = new Uint8Array(instance.exports.memory.buffer, instance.exports.inputPtr(), instance.exports.inputLen());

/**
 * Since we need to write both keyboard state (as bytes) and mouse state (as 32-bit integers) into the same input memory region,
 * we create a DataView for the mouse portion to allow writing 32-bit values without affecting the keyboard byte values.
 * The WASM module will need to read the mouse state using the same offsets and sizes to get the correct values.
 * This setup allows us to efficiently share a single contiguous memory region for all input data, while still handling different data types cleanly.
 */
const inputView = new DataView(instance.exports.memory.buffer, instance.exports.inputPtr(), instance.exports.inputLen());

/** 
 * Keyboard state mapped to the input memory layout. 
 */
const keys = {
    ArrowUp: false,
    ArrowDown: false,
    ArrowLeft: false,
    ArrowRight: false,
    KeyZ: false,
    KeyX: false,
    KeyR: false
};

/** 
 * Captures key presses and marks them as active. 
 * @param {KeyboardEvent} e 
 */
function registerKeyDown(e) {
    if (e.code in keys) {
        keys[e.code] = true;
        e.preventDefault();
    }
}
window.addEventListener("keydown", registerKeyDown);

/**
 * Captures key releases and marks them as inactive.
 * @param {KeyboardEvent} e
 */
function registerKeyUp(e) {
    if (e.code in keys) {
        keys[e.code] = false;
        e.preventDefault();
    }
}
window.addEventListener("keyup", registerKeyUp);

/** 
 * Clears all key state to avoid sticky input after focus loss. 
 * @param {FocusEvent} e
 */
function registerBlur(e) {
    for (const code in keys) {
        keys[code] = false;
    }
}
window.addEventListener("blur", registerBlur);

/**
 * The WASM module provides offsets for where to write the mouse X, Y, and button state within the shared input memory region.
 * We use these offsets with the DataView to write the mouse state as 32-bit integers without interfering with the keyboard byte values.
 * This allows the WASM module to read both keyboard and mouse input from the same contiguous memory region using the defined layout.
 */

/**  
  * Mouse X offset within the input memory region, as provided by the WASM module. 
  * 
  * @type {number}
  */
const MOUSE_X_OFFSET = instance.exports.inputMouseXOffset();

/** 
 * Mouse Y offset within the input memory region, as provided by the WASM module.
 * @type {number}
 */
const MOUSE_Y_OFFSET = instance.exports.inputMouseYOffset();

/** 
 * Mouse buttons offset within the input memory region, as provided by the WASM module.
 * @type {number}
 */
const MOUSE_BUTTONS_OFFSET = instance.exports.inputMouseButtonsOffset();

/** 
 * Writes current key state into the shared input bytes for WASM.
 */
function writeInput() {
    input[INPUT_UP] = keys.ArrowUp ? 1 : 0;
    input[INPUT_DOWN] = keys.ArrowDown ? 1 : 0;
    input[INPUT_LEFT] = keys.ArrowLeft ? 1 : 0;
    input[INPUT_RIGHT] = keys.ArrowRight ? 1 : 0;
    input[INPUT_CONFIRM] = keys.KeyZ ? 1 : 0;
    input[INPUT_CANCEL] = keys.KeyX ? 1 : 0;
    input[INPUT_RESET] = keys.KeyR ? 1 : 0;

    inputView.setUint32(MOUSE_X_OFFSET, mouseInput.x >>> 0, true);
    inputView.setUint32(MOUSE_Y_OFFSET, mouseInput.y >>> 0, true);
    inputView.setUint32(MOUSE_BUTTONS_OFFSET, mouseInput.buttons >>> 0, true);
}

/**
 * The scale factor for resizing the canvas. 
 * This is calculated based on the window size and the game dimensions to maintain pixelated graphics 
 * while filling as much of the screen as possible.
 */
let scale = 1

/** 
 * Resizes the canvas element to an integer pixel scale. 
 * This ensures that the game's graphics remain sharp and pixelated, rather than blurry.
 */
function resizeCanvas() {
    const scaleX = Math.floor((window.innerWidth - 16) / width);
    const scaleY = Math.floor((window.innerHeight - 16) / height);
    scale = Math.max(1, Math.min(scaleX, scaleY));
    canvas.style.width = `${width * scale}px`;
    canvas.style.height = `${height * scale}px`;
}
resizeCanvas();
window.addEventListener("resize", resizeCanvas);

instance.exports.init();

/**
 * The target tick rate for the game logic. This determines how often the game state updates per second.
 */
const TICK_RATE = 60;

/**
 * The fixed time step in milliseconds for each game tick, calculated from the target tick rate.
 */
const FIXED_STEP_MS = 1000 / TICK_RATE;

/**
 * The maximum number of fixed update steps to perform in a single frame. 
 * This prevents the game from trying to catch up too much if the frame rate drops significantly, 
 * which could cause long freezes or spiral of death scenarios.
 */
const MAX_CATCH_UP_STEPS = 5;

/**
 * The accumulator for tracking how much time has passed since the last game tick.
 * This allows us to perform fixed time step updates for the game logic, 
 * ensuring consistent behavior regardless of frame rate fluctuations.
 * 
 * Each frame, we add the elapsed time to the accumulator and then perform as many fixed ticks 
 * as needed while the accumulator exceeds the fixed step time.
 * 
 * After ticking, we subtract the fixed step time from the accumulator. 
 * This way, we can handle variable frame rates while keeping the game logic updates consistent.
 */
let accumulatorMs = 0;

/**
 * The timestamp of the last frame in milliseconds. This is used to calculate the delta time for each frame,
 * which is then added to the accumulator to determine how many fixed ticks to perform.
 * It is initialized to 0 and set to the current time on the first frame.
 */
let lastFrameTimeMs = 0;

/** Main frame loop: write input, tick game, and present frame. */
function loop(nowMs) {
    if (lastFrameTimeMs === 0) {
        lastFrameTimeMs = nowMs;
    }

    let frameDeltaMs = nowMs - lastFrameTimeMs;
    lastFrameTimeMs = nowMs;
    if (frameDeltaMs > 250) {
        frameDeltaMs = 250;
    }

    accumulatorMs += frameDeltaMs;

    // Input is sampled once per rendered frame, then reused by all fixed ticks in this frame.
    writeInput();

    let steps = 0;
    while (accumulatorMs >= FIXED_STEP_MS && steps < MAX_CATCH_UP_STEPS) {
        instance.exports.tick();
        accumulatorMs -= FIXED_STEP_MS;
        steps += 1;
    }
    if (steps === MAX_CATCH_UP_STEPS && accumulatorMs > FIXED_STEP_MS) {
        accumulatorMs = FIXED_STEP_MS;
    }

    instance.exports.render();

    ctx.putImageData(image, 0, 0);
    requestAnimationFrame(loop);
}

requestAnimationFrame(loop);