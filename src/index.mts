"use strict";

type WasmExports = {
    width: () => number;
    height: () => number;
    memory: WebAssembly.Memory;
    framePtr: () => number;
    frameLen: () => number;
    inputPtr: () => number;
    inputLen: () => number;
    inputButtonsLoOffset: () => number;
    inputButtonsHiOffset: () => number;
    inputMouseXOffset: () => number;
    inputMouseYOffset: () => number;
    inputMouseButtonsOffset: () => number;
    init: () => void;
    tick: () => void;
    render: () => void;
};

/**
 * Exposed to WASM for debug logging.
 * 
 * @param {number} num - The number to log, typically an error code or status value from WASM.
 */
function console_log(num: number) {
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
void (async function main(): Promise<void> {
    const response = await fetch("./index.wasm");
    if (!response.ok) {
        console.error(`Failed to fetch wasm: ${response.status} ${response.statusText}`);
        return;
    }

    /**
     * Instance exposes WASM exports and memory.
     */
    const { instance } = await WebAssembly.instantiateStreaming(response, importObject);
    const wasm = instance.exports as unknown as WasmExports;

    /**
     * Game width used to size the canvas.
     */
    const width: number = wasm.width();

    /**
     * Game height used to size the canvas.

     */
    const height: number = wasm.height();

    /**
     * Canvas that displays the WASM frame buffer.
     */
    const canvasEl = document.getElementById("game");
    if (!(canvasEl instanceof HTMLCanvasElement)) {
        console.error("Expected a <canvas id=\"game\"> element in the DOM.");
        return;
    }
    const canvas = canvasEl;
    canvas.width = width; // Sync width
    canvas.height = height; // Sync height

    /**
     * 2D context used to draw ImageData.
     */
    const ctx = canvas.getContext("2d");
    if (!ctx) {
        console.error("Failed to get 2D canvas context from #game.");
        return;
    }
    const renderCtx: CanvasRenderingContext2D = ctx;

    /**
     * Direct byte view of the WASM frame buffer.
     * Zig writes u32 RGBA pixels in little-endian order, matching ImageData layout.
     */
    const frame = new Uint8ClampedArray(wasm.memory.buffer, wasm.framePtr(), wasm.frameLen());

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

    const pointerState: { x: number; y: number; buttons: number } = {
        x: 0,
        y: 0,
        buttons: 0
    };

    /**
     * Integer scale used for crisp pixel rendering.
     */
    let scale = 1;

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

    const VBTN = {
        UP: "UP",
        DOWN: "DOWN",
        LEFT: "LEFT",
        RIGHT: "RIGHT",
        A: "Y",
        B: "X",
        X: "A",
        Y: "S",
        L: "Q",
        R: "W",
        START: "SPACE",
        SELECT: "ENTER"
    } as const;

    type VirtualButton = typeof VBTN[keyof typeof VBTN];

    /**
     * Physical key -> named virtual button binding map.
     */
    const KEY_BINDINGS: Record<string, VirtualButton> = {
        ArrowUp: VBTN.UP,
        ArrowDown: VBTN.DOWN,
        ArrowLeft: VBTN.LEFT,
        ArrowRight: VBTN.RIGHT,
        KeyZ: VBTN.A,
        KeyX: VBTN.B,
        KeyA: VBTN.X,
        KeyS: VBTN.Y,
        KeyQ: VBTN.L,
        KeyW: VBTN.R,
        Enter: VBTN.START,
        ShiftLeft: VBTN.SELECT
    };

    const VBTN_TO_MASK: Record<VirtualButton, { hi: boolean; mask: number }> = {
        [VBTN.UP]: { hi: false, mask: 1 << 0 },
        [VBTN.DOWN]: { hi: false, mask: 1 << 1 },
        [VBTN.LEFT]: { hi: false, mask: 1 << 2 },
        [VBTN.RIGHT]: { hi: false, mask: 1 << 3 },
        [VBTN.A]: { hi: false, mask: 1 << 4 },
        [VBTN.B]: { hi: false, mask: 1 << 5 },
        [VBTN.X]: { hi: false, mask: 1 << 6 },
        [VBTN.Y]: { hi: false, mask: 1 << 7 },
        [VBTN.L]: { hi: true, mask: 1 << 0 },
        [VBTN.R]: { hi: true, mask: 1 << 1 },
        [VBTN.START]: { hi: true, mask: 1 << 2 },
        [VBTN.SELECT]: { hi: true, mask: 1 << 3 }
    };

    /**
     * Shared input byte buffer in WASM memory.
     */
    const input = new Uint8Array(wasm.memory.buffer, wasm.inputPtr(), wasm.inputLen());

    /**
     * DataView for writing u32 mouse fields in shared input memory.
     */
    const inputView = new DataView(wasm.memory.buffer, wasm.inputPtr(), wasm.inputLen());

    /**
     * Physical keyboard state keyed by KeyboardEvent.code.
     */
    const physicalKeys: Record<string, boolean> = {};
    for (const code of Object.keys(KEY_BINDINGS)) {
        physicalKeys[code] = false;
    }

    /** 
     * Captures key presses 
     */
    function registerKeyDown(e: KeyboardEvent): void {
        if (e.code in physicalKeys) {
            physicalKeys[e.code] = true;
            e.preventDefault();
        }
    }
    window.addEventListener("keydown", registerKeyDown);

    /**
     * Captures key releases.
     */
    function registerKeyUp(e: KeyboardEvent): void {
        if (e.code in physicalKeys) {
            physicalKeys[e.code] = false;
            e.preventDefault();
        }
    }
    window.addEventListener("keyup", registerKeyUp);

    /** 
     * Clears key state on focus loss to avoid sticky input.
     */
    function registerBlur(): void {
        for (const code in physicalKeys) {
            physicalKeys[code] = false;
        }
    }
    window.addEventListener("blur", registerBlur);

    /**
     * Packs active key bindings directly into low/high controller register bytes.
     */
    function packControllerStateFromBindings(): { buttonsLo: number; buttonsHi: number } {
        let buttonsLo = 0;
        let buttonsHi = 0;

        for (const code in KEY_BINDINGS) {
            if (!physicalKeys[code]) {
                continue;
            }

            const button = KEY_BINDINGS[code];
            const mapping = VBTN_TO_MASK[button];
            if (mapping.hi) {
                buttonsHi |= mapping.mask;
            } else {
                buttonsLo |= mapping.mask;
            }
        }

        return { buttonsLo, buttonsHi };
    }

    /** Offsets for packed controller bytes in shared input memory. */
    const BUTTONS_LO_OFFSET = wasm.inputButtonsLoOffset();
    const BUTTONS_HI_OFFSET = wasm.inputButtonsHiOffset();

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

    /** 
     * Writes current input state into shared WASM memory.
     */
    function writeInput() {
        const packedController = packControllerStateFromBindings();
        input[BUTTONS_LO_OFFSET] = packedController.buttonsLo;
        input[BUTTONS_HI_OFFSET] = packedController.buttonsHi;

        inputView.setUint32(MOUSE_X_OFFSET, pointerState.x >>> 0, true);
        inputView.setUint32(MOUSE_Y_OFFSET, pointerState.y >>> 0, true);
        inputView.setUint32(MOUSE_BUTTONS_OFFSET, pointerState.buttons >>> 0, true);
    }

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

    wasm.init();

    /**
     * Target simulation ticks per second.
     */
    const TICK_RATE: number = 60;

    /**
     * Fixed timestep duration in milliseconds.
     */
    const FIXED_STEP_MS: number = 1000 / TICK_RATE;

    /**
     * Max fixed steps processed in one frame.
     */
    const MAX_CATCH_UP_STEPS: number = 5;

    /**
     * Accumulated unprocessed frame time for fixed-step updates.
     */
    let accumulatorMs: number = 0;

    /**
     * Timestamp of the previous frame.
     */
    let lastFrameTimeMs: number = 0;

    /** Main frame loop: write input, tick game, and present frame. */
    function loop(nowMs: number): void {
        if (lastFrameTimeMs === 0) {
            lastFrameTimeMs = nowMs;
        }

        let frameDeltaMs: number = nowMs - lastFrameTimeMs;
        lastFrameTimeMs = nowMs;
        if (frameDeltaMs > 250) {
            frameDeltaMs = 250;
        }

        accumulatorMs += frameDeltaMs;

        // Input is sampled once per rendered frame, then reused by all fixed ticks in this frame.
        writeInput();

        let steps: number = 0;
        while (accumulatorMs >= FIXED_STEP_MS && steps < MAX_CATCH_UP_STEPS) {
            wasm.tick();
            accumulatorMs -= FIXED_STEP_MS;
            steps += 1;
        }
        if (steps === MAX_CATCH_UP_STEPS && accumulatorMs > FIXED_STEP_MS) {
            accumulatorMs = FIXED_STEP_MS;
        }

        wasm.render();

        renderCtx.putImageData(image, 0, 0);
        requestAnimationFrame(loop);
    }

    requestAnimationFrame(loop);
})().catch((error: unknown) => {
    console.error("Failed to start game runtime.", error);
});