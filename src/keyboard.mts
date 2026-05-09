// keyboard.mts
export const VBTN = {
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
export type VirtualButton = typeof VBTN[keyof typeof VBTN];

export type KeyboardInput = {
        writeTo: (
                input: Uint8Array,
                buttonsLoOffset: number,
                buttonsHiOffset: number,
        ) => void;
        setBinding: (code: string, button: VirtualButton) => void;
        clearBinding: (code: string) => void;
        getBindings: () => Record<string, VirtualButton>;
        clear: () => void;
        dispose: () => void;
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
        [VBTN.SELECT]: { hi: true, mask: 1 << 3 },
};

export const DEFAULT_KEY_BINDINGS: Record<string, VirtualButton> = {
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
        Enter: VBTN.SELECT,
};
export function createKeyboardInput(
        initialBindings: Record<string, VirtualButton>,
): KeyboardInput {
        const bindings: Record<string, VirtualButton> = { ...initialBindings };
        const physicalKeys: Record<string, boolean> = {};

        for (const code of Object.keys(bindings)) {
                physicalKeys[code] = false;
        }

        function registerKeyDown(e: KeyboardEvent): void {
                if (e.code in bindings) {
                        physicalKeys[e.code] = true;
                        e.preventDefault();
                }
        }

        function registerKeyUp(e: KeyboardEvent): void {
                if (e.code in bindings) {
                        physicalKeys[e.code] = false;
                        e.preventDefault();
                }
        }

        function clear(): void {
                for (const code in physicalKeys) {
                        physicalKeys[code] = false;
                }
        }

        function pack(): { buttonsLo: number; buttonsHi: number } {
                let buttonsLo = 0;
                let buttonsHi = 0;

                for (const code in bindings) {
                        if (!physicalKeys[code]) {
                                continue;
                        }

                        const button = bindings[code];
                        const mapping = VBTN_TO_MASK[button];

                        if (mapping.hi) {
                                buttonsHi |= mapping.mask;
                        } else {
                                buttonsLo |= mapping.mask;
                        }
                }

                return { buttonsLo, buttonsHi };
        }

        function writeTo(
                input: Uint8Array,
                buttonsLoOffset: number,
                buttonsHiOffset: number,
        ): void {
                const packed = pack();

                input[buttonsLoOffset] = packed.buttonsLo;
                input[buttonsHiOffset] = packed.buttonsHi;
        }

        function setBinding(code: string, button: VirtualButton): void {
                bindings[code] = button;
                physicalKeys[code] = false;
        }

        function clearBinding(code: string): void {
                delete bindings[code];
                delete physicalKeys[code];
        }

        function getBindings(): Record<string, VirtualButton> {
                return { ...bindings };
        }

        function dispose(): void {
                window.removeEventListener("keydown", registerKeyDown);
                window.removeEventListener("keyup", registerKeyUp);
                window.removeEventListener("blur", clear);
        }

        window.addEventListener("keydown", registerKeyDown);
        window.addEventListener("keyup", registerKeyUp);
        window.addEventListener("blur", clear);

        return {
                writeTo,
                setBinding,
                clearBinding,
                getBindings,
                clear,
                dispose,
        };
}