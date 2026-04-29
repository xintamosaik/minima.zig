# Codebase Review TODO

## High-priority issues

- [ ] **Fix menu selection bounds bug in `src/scenes/menu.zig`.**
  - Current logic allows `menuCursor.y` to move to `8 * 20` while selectable entries are rendered at `8 + JUMP * [0..5]` (`8..168`).
  - Result: cursor can land on rows that are not actionable; pressing START does nothing.
  - Suggested fix: derive an integer `selected_index` and clamp movement to `[0, 5]`, then compute `y = 8 + selected_index * JUMP`.

- [ ] **Implement real scene transitions for menu actions.**
  - All START branches in `menu.tick()` currently set `scene.scene = .intro`, including `new`, `load`, `exit`, etc.
  - Suggested fix: map each entry to an intended scene (`.new`, `.load`, `.exit`) or add placeholders that at least show distinct screens.

- [ ] **Add cleanup for DOM event listeners in `src/index.mts`.**
  - The runtime registers multiple `window`/`canvas` listeners but never unregisters them.
  - This is fine for one-shot startup but leaks handlers if startup is retried or hot-reloaded.
  - Suggested fix: keep disposer functions and expose a teardown path.

## Medium-priority issues

- [ ] **Avoid stale TypedArray/DataView references after WASM memory growth.**
  - `frame`, `input`, and `inputView` are created once from `wasm.memory.buffer`.
  - If memory grows, old views may point to detached/obsolete buffers.
  - Suggested fix: add a `refreshViewsIfNeeded()` that checks `wasm.memory.buffer` identity each frame.

- [ ] **Harden pointer coordinate conversion for out-of-canvas mouse events.**
  - `registerMouseMovement` uses `e.offsetX / scale` and `e.offsetY / scale` with no clamping.
  - Suggested fix: clamp to `[0, width - 1]` and `[0, height - 1]` before writing to input memory.

- [ ] **Reduce duplicated menu rendering code.**
  - `menu.render()` repeats many `drawString` calls with hard-coded line numbers/colors.
  - Suggested fix: define a small data table (`label`, `row`, `color`) and loop.

## Quality improvements

- [ ] **Add basic automated checks in CI.**
  - Include at least `pnpm run build`, `go build ./...`, and Zig build script execution.
  - This catches runtime/export drift across Zig/TS integration points.

- [ ] **Document scene contract and navigation behavior.**
  - Add a short doc describing expected transitions and control mappings for each scene.
  - This will make placeholder states less ambiguous for future contributors.
