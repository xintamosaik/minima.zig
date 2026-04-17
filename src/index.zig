extern "env" fn console_log(value: i32) void;

const SCREEN_W: i32 = 128; // 16 x 8
const SCREEN_H: i32 = 96; // 12 x 8


export fn tick() void {
    console_log(42);
}

// Returns the framebuffer height in pixels. 
export fn height() i32 {
    return SCREEN_H;
}
// Returns the framebuffer width in pixels. 
export fn width() i32 {
    return SCREEN_W;
}