export type CanvasResizer = {
    resize: () => void;
    getScale: () => number;
};

export function getGameCanvas(): HTMLCanvasElement {
    const canvas = document.getElementById("game");

    if (!(canvas instanceof HTMLCanvasElement)) {
        throw new Error('Expected a <canvas id="game"> element in the DOM.');
    }

    return canvas;
}

export function initCanvas(width: number, height: number): HTMLCanvasElement {
    const canvas = getGameCanvas();

    canvas.width = width;
    canvas.height = height;

    return canvas;
}

export function initContext(canvas: HTMLCanvasElement): CanvasRenderingContext2D {
    const ctx = canvas.getContext("2d");

    if (!ctx) {
        throw new Error("Failed to get 2D canvas context from #game.");
    }

    return ctx;
}

export function createCanvasResizer(
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