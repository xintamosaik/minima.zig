# Runtime Cycle Protocol

Host and VM cooperate through a fixed host-driven frame loop and shared memory views.

Current implementation note: host runtime is browser JavaScript/TypeScript, VM is Zig compiled to WASM.

## Boot Sequence

- Host fetches and instantiates the WASM module
- Host reads VM exports for dimensions and input offsets
- Host binds typed array views to shared WASM memory
- Host initializes VM once via exported `init`
- Host starts browser frame loop

## Per-Frame Cycle

1. Host accumulates wall-clock time from browser frame callback.
2. Host writes input block once for this rendered frame.
3. Host runs zero or more fixed simulation ticks via VM `tick`.
4. Host runs one VM `render` to update frame buffer.
5. Host presents the frame buffer to canvas.

## Timing Rules

- Simulation tick rate is fixed at 60 Hz.
- Multiple ticks may run inside one rendered frame when catching up.
- A catch-up cap limits maximum ticks per rendered frame.
- Frame delta is clamped to avoid unstable jumps after stalls.

## Ownership Rules

- Host owns writes to input block.
- VM owns writes to frame buffer.
- Host reads frame buffer for presentation only.
- VM reads input block as immutable for each tick.

## Memory View Assumption

- Host caches typed array and DataView bindings against `wasm.memory.buffer`.
- This assumes memory does not move due to growth during runtime.