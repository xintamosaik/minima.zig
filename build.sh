#!/bin/sh
set -eu

mkdir -p dist

zig build-exe src/index.zig \
  -target wasm32-freestanding \
  -fno-entry \
  -rdynamic \
  -O ReleaseSmall \
  -fstrip \
  -femit-bin=dist/index.wasm

 