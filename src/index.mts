"use strict";

import { init } from "./wasm.mts";
import { initCanvas, initContext, createCanvasResizer } from "./canvas.mts";
import { createFramePresenter } from "./frame-presenter.mts";
import { createKeyboardInput, DEFAULT_KEY_BINDINGS, VBTN } from "./keyboard.mts";
import { createMouseInput } from "./mouse.mts";
import { createInputWriter } from "./input-writer.mts";
import { createGameLoop } from "./game-loop.mts";
import { SCENE } from "./scenes.mts";

export async function createApp() {
    const wasm = await init("index.wasm");

    const width = wasm.width();
    const height = wasm.height();

    const canvas = initCanvas(width, height);
    const renderCtx = initContext(canvas);

    const resizer = createCanvasResizer(canvas, width, height);
    resizer.resize();
    window.addEventListener("resize", resizer.resize);

    const presenter = createFramePresenter(wasm, width, height, renderCtx);

    const keyboard = createKeyboardInput(DEFAULT_KEY_BINDINGS);

    const mouse = createMouseInput(canvas, resizer.getScale);

    const inputWriter = createInputWriter(wasm, keyboard, mouse);

    wasm.init(SCENE.BATTLE_RIVER_WOLVES);

    const runner = createGameLoop({
        tickRate: 60,
        maxCatchUpSteps: 5,
        writeInput: inputWriter.write,
        tick: wasm.tick,
        render: wasm.render,
        present: presenter.present,
    });

    return {
        start: runner.start,
        stop: runner.stop,
        restart: runner.restart,

        keyboard: {
            setKey: keyboard.setKey,
            clearKey: keyboard.clearKey,
            getBindings: keyboard.getBindings,
        },
    };
}

async function main(): Promise<void> {
    try {
        const app = await createApp();
        app.start();
        app.keyboard.clearKey("KeyZ");
        app.keyboard.setKey("KeyZ", VBTN.A);
        // Optional dev/debug escape hatch.
        Object.assign(window, { minima: app });
    } catch (error) {
        console.error(error);
    }
}

main();