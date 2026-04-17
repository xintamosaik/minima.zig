#!/bin/sh
set -eu
zig build-exe src/wasm.zig \
  -target wasm32-freestanding \
  -fno-entry \
  --export=add \
  -femit-bin=wasm.wasm

mv wasm.wasm dist/wasm.wasm