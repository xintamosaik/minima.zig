export type FramePresenter = {
    present: () => void;
};

type FrameWasmExports = {
    memory: WebAssembly.Memory;
    framePtr: () => number;
    frameLen: () => number;
};

export function createFramePresenter(
    wasm: FrameWasmExports,
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