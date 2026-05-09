import type { KeyboardInput } from "./keyboard.mts";
import type { MouseInput } from "./mouse.mts";

export type InputWriter = {
    write: () => void;
};

type InputWasmExports = {
    memory: WebAssembly.Memory;
    inputPtr: () => number;
    inputLen: () => number;
    inputButtonsLoOffset: () => number;
    inputButtonsHiOffset: () => number;
    inputMouseXOffset: () => number;
    inputMouseYOffset: () => number;
    inputMouseButtonsOffset: () => number;
};

export function createInputWriter(
    wasm: InputWasmExports,
    keyboard: KeyboardInput,
    mouse: MouseInput,
): InputWriter {
    const inputBytes = new Uint8Array(
        wasm.memory.buffer,
        wasm.inputPtr(),
        wasm.inputLen(),
    );

    const inputView = new DataView(
        wasm.memory.buffer,
        wasm.inputPtr(),
        wasm.inputLen(),
    );

    const buttonsLoOffset = wasm.inputButtonsLoOffset();
    const buttonsHiOffset = wasm.inputButtonsHiOffset();
    const mouseXOffset = wasm.inputMouseXOffset();
    const mouseYOffset = wasm.inputMouseYOffset();
    const mouseButtonsOffset = wasm.inputMouseButtonsOffset();

    function write(): void {
        keyboard.writeTo(inputBytes, buttonsLoOffset, buttonsHiOffset);
        mouse.writeTo(inputView, mouseXOffset, mouseYOffset, mouseButtonsOffset);
    }

    return { write };
}