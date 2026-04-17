"use strict";

const importObject = {
    env: {
        console_log(num) {
            console.log(num)
        }
    },
};
const response = await fetch("./index.wasm");
if (!response.ok) {
    console.error(`Failed to fetch wasm: ${response.statusText}`);
}
const { instance } = await WebAssembly.instantiateStreaming(response, importObject);
if (!instance) {
    console.error("Failed to instantiate wasm");
}

const tick = instance.exports.tick;
tick(); // console.log(42);

const width = instance.exports.width();
const height = instance.exports.height();

const out = document.getElementById("out");
out.textContent = `WASM loaded successfully! Screen size: ${width}x${height}`;



