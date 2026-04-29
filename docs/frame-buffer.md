# Frame Buffer Protocol

Shared video memory block written by the VM and read by the host runtime.

## Layout

- Pixel format: RGBA8888
- Width: 320 (40 x 8)
- Height: 200 (25 x 8)
- Total size: 256000 bytes 
- Ownership: VM writes, host reads and presents

## Encoding Rules

- Each pixel is one `u32`
- In little-endian memory, bytes are laid out as `R`, `G`, `B`, `A`
- This matches browser `ImageData` byte layout directly

## Ownership Rules

- VM owns all writes to the frame buffer
- Host treats the frame buffer as read-only presentation data
