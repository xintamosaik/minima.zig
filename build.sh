#!/bin/sh
set -eu

mkdir -p dist

zig build-exe src/wasm.zig \
  -target wasm32-freestanding \
  -fno-entry \
  -rdynamic \
  -femit-bin=dist/wasm.wasm

 