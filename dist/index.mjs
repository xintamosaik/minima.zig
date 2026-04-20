"use strict";


const importObject = {
    env: {
        console_log(num) {
            console.log(num)
        }
    },
};
const response = await fetch("./index.wasm");
if (!response.ok) {
    console.error(`Failed to fetch wasm: ${response.statusText}`);
}
const { instance } = await WebAssembly.instantiateStreaming(response, importObject);
if (!instance) {
    console.error("Failed to instantiate wasm");
}

const width = instance.exports.width();
const height = instance.exports.height();
const canvas = document.getElementById("game");
if (!canvas) {
    console.error("Failed to find canvas element");
}
canvas.width = width;
canvas.height = height;
const BUTTON_LEFT = 0;
const BUTTON_MIDDLE = 1;
const BUTTON_RIGHT = 2;

const MOUSE_BUTTON_LEFT = 1;
const MOUSE_BUTTON_MIDDLE = 2;
const MOUSE_BUTTON_RIGHT = 4;

/** Converts a DOM mouse button index into our WASM input bitmask. */
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
canvas.addEventListener("mousemove", (e) => {
    mouseInput.x = Math.floor(e.offsetX / scale);
    mouseInput.y = Math.floor(e.offsetY / scale);
});
canvas.addEventListener("mousedown", (e) => {
    mouseInput.x = Math.floor(e.offsetX / scale);
    mouseInput.y = Math.floor(e.offsetY / scale);
    const bit = mouseButtonBit(e.button);
    if (bit !== 0) {
        mouseInput.buttons |= bit;
    }
});
canvas.addEventListener("mouseup", (e) => {
    mouseInput.x = Math.floor(e.offsetX / scale);
    mouseInput.y = Math.floor(e.offsetY / scale);
    const bit = mouseButtonBit(e.button);
    if (bit !== 0) {
        mouseInput.buttons &= ~bit;
    }
});
canvas.addEventListener("contextmenu", (e) => {
    e.preventDefault();
});
canvas.addEventListener("mouseleave", () => {
    mouseInput.buttons = 0;
});
   

const ctx = canvas.getContext("2d");
if (!ctx) {
    console.error("Failed to get canvas context");
}
ctx.imageSmoothingEnabled = false;

ctx.fillStyle = "cyan"; // to see difference to the default black background
ctx.fillRect(0, 0, width, height);

const buffer = instance.exports.memory.buffer;
const framePtr = instance.exports.framePtr;
const frameLen = instance.exports.frameLen;
// Zig writes u32 pixels as RGBA bytes in little-endian memory; ImageData consumes that byte view directly.
const frame = new Uint8ClampedArray(buffer, framePtr(), frameLen());
const image = new ImageData(frame, width, height);


const INPUT_UP = 0;
const INPUT_DOWN = 1;
const INPUT_LEFT = 2;
const INPUT_RIGHT = 3;
const INPUT_CONFIRM = 4;
const INPUT_CANCEL = 5;
const INPUT_RESET = 6;

const inputPtr = instance.exports.inputPtr;
const inputLen = instance.exports.inputLen;
const inputMouseXOffset = instance.exports.inputMouseXOffset;
const inputMouseYOffset = instance.exports.inputMouseYOffset;
const inputMouseButtonsOffset = instance.exports.inputMouseButtonsOffset;
const MOUSE_X_OFFSET = inputMouseXOffset();
const MOUSE_Y_OFFSET = inputMouseYOffset();
const MOUSE_BUTTONS_OFFSET = inputMouseButtonsOffset();
const input = new Uint8Array(buffer, inputPtr(), inputLen() );
const inputView = new DataView(buffer, inputPtr(), inputLen());

/** Keyboard state mapped to the input memory layout. */
const keys = {
    ArrowUp: false,
    ArrowDown: false,
    ArrowLeft: false,
    ArrowRight: false,
    KeyZ: false,
    KeyX: false,
    KeyR: false
};

/** Captures key presses and marks them as active. */
window.addEventListener("keydown", (e) => {
    if (e.code in keys) {
        keys[e.code] = true;
        e.preventDefault();
    }
});

/** Captures key releases and marks them as inactive. */
window.addEventListener("keyup", (e) => {
    if (e.code in keys) {
        keys[e.code] = false;
        e.preventDefault();
    }
});
/** Clears all key state to avoid sticky input after focus loss. */
window.addEventListener("blur", () => {
    for (const code in keys) {
        keys[code] = false;
    }
});
/** Writes current key state into the shared input bytes for WASM. */
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
let scale = 1
/** Resizes the canvas element to an integer pixel scale. */
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
const render = instance.exports.render;
const tick = instance.exports.tick;
const TICK_RATE = 60;
const FIXED_STEP_MS = 1000 / TICK_RATE;
const MAX_CATCH_UP_STEPS = 5;

let accumulatorMs = 0;
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
        tick();
        accumulatorMs -= FIXED_STEP_MS;
        steps += 1;
    }
    if (steps === MAX_CATCH_UP_STEPS && accumulatorMs > FIXED_STEP_MS) {
        accumulatorMs = FIXED_STEP_MS;
    }

    render();

   

    ctx.putImageData(image, 0, 0);
    requestAnimationFrame(loop);
}

requestAnimationFrame(loop);