"use strict";
 
import {init} from "./wasm.mts" 
/**
 * Fetch compiled WASM module.
 */
async function main(): Promise<void> {
    const wasm = await init("index.wasm");
    if (wasm instanceof Error) {
        console.log(wasm.message)
        return;
    }

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
 * Integer scale used for crisp pixel rendering.
 */
    let scale = 1;
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


    const VBTN = {
        UP: "UP",
        DOWN: "DOWN",
        LEFT: "LEFT",
        RIGHT: "RIGHT",
        A: "A",
        B: "B",
        X: "X",
        Y: "Y",
        L: "L",
        R: "R",
        START: "START",
        SELECT: "SELECT",
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
        KeyY: VBTN.A,
        KeyX: VBTN.B,
        KeyA: VBTN.X,
        KeyS: VBTN.Y,
        KeyQ: VBTN.L,
        KeyW: VBTN.R,
        Space: VBTN.START,
        Enter: VBTN.SELECT
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



    /** 
     * Writes current input state into shared WASM memory.
     */
    function writeInput() {
        const packedController = packControllerStateFromBindings();
        input[BUTTONS_LO_OFFSET] = packedController.buttonsLo;
        input[BUTTONS_HI_OFFSET] = packedController.buttonsHi;
    }



    const DEBUG_SCENE = 8;
    wasm.init(DEBUG_SCENE);

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
}

main()