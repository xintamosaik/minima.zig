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
    init: (s: number) => void;
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
function assertWasmExports(exports: Partial<WasmExports>): asserts exports is WasmExports {
    const functionExports: Array<keyof Omit<WasmExports, "memory">> = [
        "width",
        "height",
        "framePtr",
        "frameLen",
        "inputPtr",
        "inputLen",
        "inputButtonsLoOffset",
        "inputButtonsHiOffset",
        "inputMouseXOffset",
        "inputMouseYOffset",
        "inputMouseButtonsOffset",
        "init",
        "tick",
        "render",
    ];

    if (!(exports.memory instanceof WebAssembly.Memory)) {
        throw new Error("WASM module is missing valid memory export.");
    }

    for (const name of functionExports) {
        if (typeof exports[name] !== "function") {
            throw new Error(`WASM module is missing function export: ${name}`);
        }
    }
}
/**
 * Fetch compiled WASM module.
 */
export async function init(wasmUrl: string): Promise<WasmExports> {
    const response = await fetch(wasmUrl);
    if (!response.ok) {
        throw new Error(`Failed to fetch wasm: ${response.status} ${response.statusText}`);
    }

    /**
     * Instance exposes WASM exports and memory.
     */
    const { instance } = await WebAssembly.instantiateStreaming(response, importObject);
    const exports = instance.exports as unknown as WasmExports;


    try {
        assertWasmExports(exports);
        return exports;
    } catch (e) {
        throw new Error('invalid wasm exports found');
    }

}
