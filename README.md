# minima.zig

A tiny browser-hosted Zig/WASM runtime with explicit shared-memory protocols for input and video.

## What This Is

- Zig VM compiled to WASM
- Browser host runtime in TypeScript
- Shared RGBA frame buffer for presentation
- Shared input block for host-driven controls
- Fixed-step simulation with browser frame presentation
- see https://xintamosaik.github.io/minima.zig/ for a live demo

## Project Layout

- `src/index.zig`: VM implementation and exported memory/layout offsets
- `src/index.mts`: host runtime bootstrap, input writes, frame presentation
- `docs/input-block.md`: input memory contract
- `docs/frame-buffer.md`: frame buffer memory contract
- `docs/runtime-cycle.md`: host/VM update and presentation cycle
- `dist/`: built runtime artifacts served by `main.go`

## Build

- Build WASM only: `./build.sh`
- Build TypeScript only: `pnpm run build`
- Build both: `pnpm run build:all`

## Run

- Build artifacts first
- Start server: `go run main.go`
- Open the served page in your browser

## Protocol Docs

- Input block: `docs/input-block.md`
- Frame buffer: `docs/frame-buffer.md`
- Runtime cycle: `docs/runtime-cycle.md`