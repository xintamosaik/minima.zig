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
    mouseInput.buttons |= (1 << e.button);
});
canvas.addEventListener("mouseup", (e) => {
    mouseInput.x = Math.floor(e.offsetX / scale);
    mouseInput.y = Math.floor(e.offsetY / scale);
    mouseInput.buttons &= ~(1 << e.button);
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
const frame = new Uint8ClampedArray(buffer, framePtr(), frameLen());
const image = new ImageData(frame, width, height);


const INPUT_UP = 0;
const INPUT_DOWN = 1;
const INPUT_LEFT = 2;
const INPUT_RIGHT = 3;
const INPUT_CONFIRM = 4;
const INPUT_CANCEL = 5;
const INPUT_RESET = 6;
const MOUSE_X_OFFSET = 8;
const MOUSE_Y_OFFSET = 12;
const MOUSE_BUTTONS_OFFSET = 16;

const inputPtr = instance.exports.inputPtr;
const inputLen = instance.exports.inputLen;
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

const tick = instance.exports.tick;
/** Main frame loop: write input, tick game, and present frame. */
function loop() {
    writeInput();

    tick();
    // render();
   
   

    ctx.putImageData(image, 0, 0);
    requestAnimationFrame(loop);
}

requestAnimationFrame(loop);