"use strict";

try {
    const out = document.getElementById("out");
    const importObject = {
        env: {
            console_log(num) {
                console.log(num)
            }
        },
    };
    const response = await fetch("./index.wasm");
    const { instance } = await WebAssembly.instantiateStreaming(response, importObject);
  

    const tick = instance.exports.tick;

 
    const width = instance.exports.width();
    const height = instance.exports.height();

    tick();
    out.textContent = `WASM loaded successfully! Screen size: ${width}x${height}`;
} catch (err) {
    out.textContent = `Failed to load wasm: ${err}`;
}

