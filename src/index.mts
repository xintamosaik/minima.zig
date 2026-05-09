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
    if (!ctx) {
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

type FramePresenter = {
    present: () => void;
};

function createFramePresenter(
    wasm: {
        memory: WebAssembly.Memory;
        framePtr: () => number;
        frameLen: () => number;
    },
    width: number,
    height: number,
    renderCtx: CanvasRenderingContext2D,
): FramePresenter {
    const frame = new Uint8ClampedArray(
        wasm.memory.buffer,
        wasm.framePtr(),
        wasm.frameLen(),
    );

    const image = new ImageData(frame, width, height);

    function present(): void {
        renderCtx.putImageData(image, 0, 0);
    }

    return { present };
}

type InputWriter = {
    write: () => void;
};

function createInputWriter(
    wasm: {
        memory: WebAssembly.Memory;
        inputPtr: () => number;
        inputLen: () => number;
        inputButtonsLoOffset: () => number;
        inputButtonsHiOffset: () => number;
    },
): InputWriter {
    const input = new Uint8Array(
        wasm.memory.buffer,
        wasm.inputPtr(),
        wasm.inputLen(),
    );

    const buttonsLoOffset = wasm.inputButtonsLoOffset();
    const buttonsHiOffset = wasm.inputButtonsHiOffset();

    const keyboard = createKeyboardInput(DEFAULT_KEY_BINDINGS);

    function write(): void {
        keyboard.writeTo(input, buttonsLoOffset, buttonsHiOffset);
    }

    return { write };
}

type GameLoop = {
    start: () => void;
    stop: () => void;
    restart: () => void;
};
function createGameLoop(config: {
    tickRate: number;
    maxCatchUpSteps: number;
    writeInput: () => void;
    tick: () => void;
    render: () => void;
    present: () => void;
}): GameLoop {
    const fixedStepMs = 1000 / config.tickRate;

    let accumulatorMs = 0;
    let lastFrameTimeMs = 0;
    let animationFrameId: number | null = null;
    let running = false;
    function loop(nowMs: number): void {
        if (!running) {
            return;
        }

        if (lastFrameTimeMs === 0) {
            lastFrameTimeMs = nowMs;
        }

        let frameDeltaMs = nowMs - lastFrameTimeMs;
        lastFrameTimeMs = nowMs;

        if (frameDeltaMs > 250) {
            frameDeltaMs = 250;
        }

        accumulatorMs += frameDeltaMs;

        config.writeInput();

        let steps = 0;

        while (accumulatorMs >= fixedStepMs && steps < config.maxCatchUpSteps) {
            config.tick();
            accumulatorMs -= fixedStepMs;
            steps += 1;
        }

        if (steps === config.maxCatchUpSteps && accumulatorMs > fixedStepMs) {
            accumulatorMs = fixedStepMs;
        }

        config.render();
        config.present();

        animationFrameId = requestAnimationFrame(loop);
    }

    function restart(): void {
        stop();

        accumulatorMs = 0;
        lastFrameTimeMs = 0;

        start();
    }
    function start(): void {
        if (running) {
            return;
        }

        running = true;
        lastFrameTimeMs = 0;

        animationFrameId = requestAnimationFrame(loop);
    }

    function stop(): void {
        running = false;

        if (animationFrameId !== null) {
            cancelAnimationFrame(animationFrameId);
            animationFrameId = null;
        }
    }

    return { start, stop, restart };
}


/**
 * Fetch compiled WASM module.
 */
async function main(): Promise<void> {
    let wasm;

    try {
        wasm = await init("index.wasm");
    } catch (error) {
        console.error(error);
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

    const presenter = createFramePresenter(wasm, width, height, renderCtx);

    const inputWriter = createInputWriter(wasm);

    const DEBUG_SCENE = 8;
    wasm.init(DEBUG_SCENE);

    /** Main frame loop: write input, tick game, and present frame. */
    const runner = createGameLoop({
        tickRate: 60,
        maxCatchUpSteps: 5,
        writeInput: inputWriter.write,
        tick: wasm.tick,
        render: wasm.render,
        present: presenter.present,
    });

    runner.start();
}

main()