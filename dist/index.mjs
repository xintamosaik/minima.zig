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
  
    const add = instance.exports.add;
    const tick = instance.exports.tick;
    const getCounter = instance.exports.getCounter;
    const button = document.getElementById("tick");
    button.addEventListener("click", () => {
        tick();
        const counter = getCounter();
        out.textContent = `Counter: ${counter}`;
    });
    const result = instance.exports.add(3, 7);
    out.textContent = `3 + 7 = ${result}`;
} catch (err) {
    out.textContent = `Failed to load wasm: ${err}`;
}

