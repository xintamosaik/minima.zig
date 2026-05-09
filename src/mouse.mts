/**
  * Canvas that displays the WASM frame buffer.
  */
const canvasEl = document.getElementById("game");
if (!(canvasEl instanceof HTMLCanvasElement)) {
        console.error("Expected a <canvas id=\"game\"> element in the DOM.");
  
}
const canvas = canvasEl;
/** Offsets for u32 mouse fields inside shared input memory. */
const MOUSE_X_OFFSET = wasm.inputMouseXOffset();

/** 
 * Mouse Y offset within the input memory region, as provided by the WASM module.
 */
const MOUSE_Y_OFFSET: number = wasm.inputMouseYOffset();

/** 
 * Mouse buttons offset within the input memory region, as provided by the WASM module.

 */
const MOUSE_BUTTONS_OFFSET: number = wasm.inputMouseButtonsOffset();
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
function mouseButtonBit(button: number): number {
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
/**
 * DataView for writing u32 mouse fields in shared input memory.
 */
const inputView = new DataView(wasm.memory.buffer, wasm.inputPtr(), wasm.inputLen());

const pointerState: { x: number; y: number; buttons: number } = {
        x: 0,
        y: 0,
        buttons: 0
};

/**
     * Updates mouse position in game-space coordinates.
     * @param {MouseEvent} e 
     */
function registerMouseMovement(e: MouseEvent): void {
        pointerState.x = Math.floor(e.offsetX / scale);
        pointerState.y = Math.floor(e.offsetY / scale);
}
canvas.addEventListener("mousemove", registerMouseMovement);

/**
 * Updates position and sets the pressed mouse button bit.
 * @param {MouseEvent} e 
 */
function registerMouseDown(e: MouseEvent): void {
        registerMouseMovement(e);
        const bit = mouseButtonBit(e.button);
        if (bit !== 0) {
                pointerState.buttons |= bit;
        }
}
canvas.addEventListener("mousedown", registerMouseDown);

/**
 * Updates position and clears the released mouse button bit.
 * @param {MouseEvent} e 
 */
function registerMouseUp(e: MouseEvent): void {
        registerMouseMovement(e);
        const bit = mouseButtonBit(e.button);
        if (bit !== 0) {
                pointerState.buttons &= ~bit;
        }
}
canvas.addEventListener("mouseup", registerMouseUp);

// Clear button state when release happens outside the canvas.
canvas.addEventListener("mouseleave", () => { pointerState.buttons = 0; });

// Use right-click for gameplay instead of opening the browser menu.
canvas.addEventListener("contextmenu", (e: MouseEvent) => { e.preventDefault(); });

/** 
 * Writes current input state into shared WASM memory.
 */
function writeInput() {
        inputView.setUint32(MOUSE_X_OFFSET, pointerState.x >>> 0, true);
        inputView.setUint32(MOUSE_Y_OFFSET, pointerState.y >>> 0, true);
        inputView.setUint32(MOUSE_BUTTONS_OFFSET, pointerState.buttons >>> 0, true);
}
