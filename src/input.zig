/// Mouse button bitmask values shared with JS.
pub const MOUSE_BUTTON_LEFT: u32 = 1;
pub const MOUSE_BUTTON_RIGHT: u32 = 4;
pub const MOUSE_BUTTON_MIDDLE: u32 = 2;

// Controller low-byte bits.
pub const BTN_UP: u8 = 1 << 0;
pub const BTN_DOWN: u8 = 1 << 1;
pub const BTN_LEFT: u8 = 1 << 2;
pub const BTN_RIGHT: u8 = 1 << 3;
pub const BTN_A: u8 = 1 << 4;
pub const BTN_B: u8 = 1 << 5;
pub const BTN_X: u8 = 1 << 6;
pub const BTN_Y: u8 = 1 << 7;

// Controller high-byte bits.
pub const BTN_L: u8 = 1 << 0;
pub const BTN_R: u8 = 1 << 1;
pub const BTN_START: u8 = 1 << 2;
pub const BTN_SELECT: u8 = 1 << 3;

/// C-layout struct for input data, written to by JS.
/// The `extern` attribute ensures C-compatible layout and stable byte offsets.
pub const Layout = extern struct {
    buttons_lo: u8,
    buttons_hi: u8,
    _reserved: u16,
    mouse_x: u32,
    mouse_y: u32,
    mouse_buttons: u32,
};
