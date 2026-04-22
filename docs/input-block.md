# Input Block Protocol

Shared input memory block written by the host runtime and read by the VM.

Current implementation note: host runtime is browser JavaScript, VM is Zig compiled to WASM.

## Layout (16 bytes)

- `+0x00` `buttons_lo` `u8` host writes, VM reads
- `+0x01` `buttons_hi` `u8` host writes, VM reads
- `+0x02` `reserved` `u16` must be written as `0` by the host; reserved for future protocol expansion
- `+0x04` `mouse_x` `u32` host writes, VM reads
- `+0x08` `mouse_y` `u32` host writes, VM reads
- `+0x0C` `mouse_buttons` `u32` host writes, VM reads

## Encoding Rules

- All multi-byte integer fields use little-endian byte order.
- `buttons_lo` and `buttons_hi` are single-byte bitfields.
- `mouse_x`, `mouse_y`, and `mouse_buttons` are 32-bit unsigned integers.

## Controller Bits

### buttons_lo

- bit 0: UP
- bit 1: DOWN
- bit 2: LEFT
- bit 3: RIGHT
- bit 4: A
- bit 5: B
- bit 6: X
- bit 7: Y

### buttons_hi

- bit 0: L
- bit 1: R
- bit 2: START
- bit 3: SELECT
- bit 4-7: reserved

## Ownership Rules

- Host owns all writes to the input block.
- VM treats the block as read-only input state.
- Offsets are exported from WASM and consumed by JS.

## Update Timing

- Host writes the input block once per rendered frame before VM ticks.
- VM may consume the same input block for multiple fixed simulation ticks in a single rendered frame.
- VM must treat the input block as immutable for the duration of each tick.
