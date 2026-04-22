# Input Block Protocol

Shared input memory block written by host (JS) and read by VM (WASM/Zig).

## Layout (16 bytes)

- `+0x00` `buttons_lo` `u8` host writes, VM reads
- `+0x01` `buttons_hi` `u8` host writes, VM reads
- `+0x02` `reserved` `u16` reserved for future use
- `+0x04` `mouse_x` `u32` host writes, VM reads
- `+0x08` `mouse_y` `u32` host writes, VM reads
- `+0x0C` `mouse_buttons` `u32` host writes, VM reads

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
