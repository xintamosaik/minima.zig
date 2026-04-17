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

const tick = instance.exports.tick; // Just a test
tick(); // console.log(42);

const width = instance.exports.width();
const height = instance.exports.height();

const out = document.getElementById("out");
out.textContent = `WASM loaded successfully! Screen size: ${width}x${height}`;


const canvas = document.getElementById("game");
if (!canvas) {
    console.error("Failed to find canvas element");
}
canvas.width = width;
canvas.height = height;

const ctx = canvas.getContext("2d");
if (!ctx) {
    console.error("Failed to get canvas context");
}

ctx.fillStyle = "cyan"; // to see difference to the default black background
ctx.fillRect(0, 0, width, height);
