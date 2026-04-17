#!/bin/sh
set -eu

mkdir -p dist

zig build-exe src/index.zig \
  -target wasm32-freestanding \
  -fno-entry \
  -rdynamic \
  -femit-bin=dist/index.wasm

 