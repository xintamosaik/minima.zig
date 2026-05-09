"use strict";

import { init } from "./wasm.mts"
import { createKeyboardInput, DEFAULT_KEY_BINDINGS } from "./keyboard.mts"

function initCanvas(width: number, height: number) {
    const canvas = document.getElementById("game");
    if (!(canvas instanceof HTMLCanvasElement)) {
        throw new Error("Expected a <canvas id=\"game\"> element in the DOM.");
    }

    canvas.width = width; // Sync width
    canvas.height = height; // Sync height
    return canvas;
}

function initContext(canvas: HTMLCanvasElement): CanvasRenderingContext2D {

    const ctx = canvas.getContext("2d");
    if (!ctx || ctx instanceof CanvasRenderingContext2D === false) {
        throw new Error("Failed to get 2D canvas context from #game.");
    }

    return ctx;
}


type CanvasResizer = {
    resize: () => void;
    getScale: () => number;
};

function createCanvasResizer(
    canvas: HTMLCanvasElement,
    width: number,
    height: number,
): CanvasResizer {
    let scale = 1;

    function resize(): void {
        const scaleX = Math.floor((window.innerWidth - 16) / width);
        const scaleY = Math.floor((window.innerHeight - 16) / height);

        scale = Math.max(1, Math.min(scaleX, scaleY));

        canvas.style.width = `${width * scale}px`;
        canvas.style.height = `${height * scale}px`;
    }

    function getScale(): number {
        return scale;
    }

    return {
        resize,
        getScale,
    };
}
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

    const canvas = initCanvas(width, height);


    const resizer = createCanvasResizer(canvas, width, height)

    resizer.resize();
    window.addEventListener("resize", resizer.resize);

    /**
     * 2D context used to draw ImageData.
     */
    const renderCtx = initContext(canvas);

    /**
     * Direct byte view of the WASM frame buffer.
     * Zig writes u32 RGBA pixels in little-endian order, matching ImageData layout.
     */
    const frame = new Uint8ClampedArray(wasm.memory.buffer, wasm.framePtr(), wasm.frameLen());

    /**
     * ImageData wrapper for the shared frame buffer.
     */
    const image = new ImageData(frame, width, height);

  
    /**
     * Shared input byte buffer in WASM memory.
     */
    const input = new Uint8Array(wasm.memory.buffer, wasm.inputPtr(), wasm.inputLen());

    /** Offsets for packed controller bytes in shared input memory. */
    const BUTTONS_LO_OFFSET = wasm.inputButtonsLoOffset();
    const BUTTONS_HI_OFFSET = wasm.inputButtonsHiOffset();


    const keyboard = createKeyboardInput(DEFAULT_KEY_BINDINGS);
    /** 
     * Writes current input state into shared WASM memory.
     */
    function writeInput() {
        keyboard.writeTo(input, BUTTONS_LO_OFFSET, BUTTONS_HI_OFFSET);

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