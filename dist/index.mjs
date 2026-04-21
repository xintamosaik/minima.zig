"use strict";

/**
 * Exposed to WASM for debug logging.
 * 
 * @param {number} num - The number to log, typically an error code or status value from WASM.
 */
function console_log(num) {
    console.log(num);
}

/**
 * JS functions imported by WASM.
 */
const importObject = {
    env: { console_log }
};

/**
 * Fetch compiled WASM module.
 */
const response = await fetch("./index.wasm");
if (!response.ok) {
    console.error(`Failed to fetch wasm: ${response.statusText}`);
}

/**
 * Instance exposes WASM exports and memory.
 */
const { instance } = await WebAssembly.instantiateStreaming(response, importObject);
if (!instance) {
    console.error("Failed to instantiate wasm");
}

/**
 * Game width used to size the canvas.
 * 
 * @type {number}
 */
const width = instance.exports.width();

/**
 * Game height used to size the canvas.
 * 
 * @type {number}
 */
const height = instance.exports.height();

/**
 * Canvas that displays the WASM frame buffer.
 */
const canvas = document.getElementById("game");
if (!canvas) {
    console.error("Failed to find canvas element");
}
canvas.width = width; // Sync width
canvas.height = height; // Sync height

/**
 * 2D context used to draw ImageData.
 */
const ctx = canvas.getContext("2d");
if (!ctx) {
    console.error("Failed to get canvas context");
}

/**
 * Direct byte view of the WASM frame buffer.
 * Zig writes u32 RGBA pixels in little-endian order, matching ImageData layout.
 */
const frame = new Uint8ClampedArray(instance.exports.memory.buffer, instance.exports.framePtr(), instance.exports.frameLen());

/**
 * ImageData wrapper for the shared frame buffer.
 */
const image = new ImageData(frame, width, height);

const BUTTON_LEFT = 0;
const BUTTON_MIDDLE = 1;
const BUTTON_RIGHT = 2;

const MOUSE_BUTTON_LEFT = 1;
const MOUSE_BUTTON_MIDDLE = 2;
const MOUSE_BUTTON_RIGHT = 4;

/** 
 * Converts DOM mouse button index to WASM bitmask.
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
 * Updates mouse position in game-space coordinates.
 * @param {MouseEvent} e 
 */
function registerMouseMovement(e) {
    mouseInput.x = Math.floor(e.offsetX / scale);
    mouseInput.y = Math.floor(e.offsetY / scale);
}
canvas.addEventListener("mousemove", registerMouseMovement);

/**
 * Updates position and sets the pressed mouse button bit.
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
 * Updates position and clears the released mouse button bit.
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

// Clear button state when release happens outside the canvas.
canvas.addEventListener("mouseleave", () => { mouseInput.buttons = 0; });

// Use right-click for gameplay instead of opening the browser menu.
canvas.addEventListener("contextmenu", (e) => { e.preventDefault(); });

const INPUT_UP = 0;
const INPUT_DOWN = 1;
const INPUT_LEFT = 2;
const INPUT_RIGHT = 3;
const INPUT_CONFIRM = 4;
const INPUT_CANCEL = 5;
const INPUT_RESET = 6;

/**
 * Shared input byte buffer in WASM memory.
 */
const input = new Uint8Array(instance.exports.memory.buffer, instance.exports.inputPtr(), instance.exports.inputLen());

/**
 * DataView for writing u32 mouse fields in shared input memory.
 */
const inputView = new DataView(instance.exports.memory.buffer, instance.exports.inputPtr(), instance.exports.inputLen());

/** 
 * Keyboard state mapped to the input layout.
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
 * Captures key presses.
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
 * Captures key releases.
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
 * Clears key state on focus loss to avoid sticky input.
 * @param {FocusEvent} e
 */
function registerBlur(e) {
    for (const code in keys) {
        keys[code] = false;
    }
}
window.addEventListener("blur", registerBlur);

/** Offsets for u32 mouse fields inside shared input memory. */
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
 * Writes current input state into shared WASM memory.
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
 * Integer scale used for crisp pixel rendering.
 */
let scale = 1

/** 
 * Resizes the canvas using integer scaling.
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
 * Target simulation ticks per second.
 */
const TICK_RATE = 60;

/**
 * Fixed timestep duration in milliseconds.
 */
const FIXED_STEP_MS = 1000 / TICK_RATE;

/**
 * Max fixed steps processed in one frame.
 */
const MAX_CATCH_UP_STEPS = 5;

/**
 * Accumulated unprocessed frame time for fixed-step updates.
 */
let accumulatorMs = 0;

/**
 * Timestamp of the previous frame.
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