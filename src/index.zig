extern "env" fn console_log(value: i32) void;

var counter: i32 = 0;

export fn add(a: i32, b: i32) i32 {
    return a + b;
}

export fn tick() void {
    counter += 1;
    console_log(counter);
}

export fn getCounter() i32 {
    return counter;
}

export fn width() i32 {
    return 128;
}