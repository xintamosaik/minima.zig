"use strict";
const out = document.getElementById("out");

try {
    const response = await fetch("./wasm.wasm");
    const { instance } = await WebAssembly.instantiateStreaming(response);
    console.log(instance);
    const result = instance.exports.add(3, 7);
    out.textContent = `3 + 7 = ${result}`;
} catch (err) {
    out.textContent = `Failed to load wasm: ${err}`;
}