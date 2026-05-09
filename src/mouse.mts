export type MouseInput = {
    writeTo: (
        view: DataView,
        mouseXOffset: number,
        mouseYOffset: number,
        mouseButtonsOffset: number,
    ) => void;
    clear: () => void;
    dispose: () => void;
};

type MouseState = {
    x: number;
    y: number;
    buttons: number;
};

const DOM_BUTTON_LEFT = 0;
const DOM_BUTTON_MIDDLE = 1;
const DOM_BUTTON_RIGHT = 2;

const WASM_MOUSE_LEFT = 1;
const WASM_MOUSE_MIDDLE = 2;
const WASM_MOUSE_RIGHT = 4;

function mouseButtonBit(button: number): number {
    switch (button) {
        case DOM_BUTTON_LEFT:
            return WASM_MOUSE_LEFT;
        case DOM_BUTTON_MIDDLE:
            return WASM_MOUSE_MIDDLE;
        case DOM_BUTTON_RIGHT:
            return WASM_MOUSE_RIGHT;
        default:
            return 0;
    }
}

export function createMouseInput(
    canvas: HTMLCanvasElement,
    getScale: () => number,
): MouseInput {
    const state: MouseState = {
        x: 0,
        y: 0,
        buttons: 0,
    };

    function updatePosition(e: MouseEvent): void {
        const scale = getScale();

        state.x = Math.floor(e.offsetX / scale);
        state.y = Math.floor(e.offsetY / scale);
    }

    function onMouseMove(e: MouseEvent): void {
        updatePosition(e);
    }

    function onMouseDown(e: MouseEvent): void {
        updatePosition(e);

        const bit = mouseButtonBit(e.button);
        if (bit !== 0) {
            state.buttons |= bit;
        }
    }

    function onMouseUp(e: MouseEvent): void {
        updatePosition(e);

        const bit = mouseButtonBit(e.button);
        if (bit !== 0) {
            state.buttons &= ~bit;
        }
    }

    function onMouseLeave(): void {
        state.buttons = 0;
    }

    function onContextMenu(e: MouseEvent): void {
        e.preventDefault();
    }

    function clear(): void {
        state.buttons = 0;
    }

    function writeTo(
        view: DataView,
        mouseXOffset: number,
        mouseYOffset: number,
        mouseButtonsOffset: number,
    ): void {
        view.setUint32(mouseXOffset, state.x >>> 0, true);
        view.setUint32(mouseYOffset, state.y >>> 0, true);
        view.setUint32(mouseButtonsOffset, state.buttons >>> 0, true);
    }

    function dispose(): void {
        canvas.removeEventListener("mousemove", onMouseMove);
        canvas.removeEventListener("mousedown", onMouseDown);
        canvas.removeEventListener("mouseup", onMouseUp);
        canvas.removeEventListener("mouseleave", onMouseLeave);
        canvas.removeEventListener("contextmenu", onContextMenu);
    }

    canvas.addEventListener("mousemove", onMouseMove);
    canvas.addEventListener("mousedown", onMouseDown);
    canvas.addEventListener("mouseup", onMouseUp);
    canvas.addEventListener("mouseleave", onMouseLeave);
    canvas.addEventListener("contextmenu", onContextMenu);

    return {
        writeTo,
        clear,
        dispose,
    };
}