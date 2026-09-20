import AppKit

/// Maps macOS NSEvent key info to X11 keysym values, which is what
/// NDIlib_recv_kvm_send_keyboard_press/release expects. Basic set only:
/// printable characters, whitespace/editing keys, arrows, and function keys.
/// Extend here if a needed key is missing — see Processing.NDI.KVM.keysymdef.h
/// for the full X11 keysym table.
enum KeySymMapping {
    // Named X11 keysyms not derivable from a printable character.
    private static let specialKeyCodes: [UInt16: Int32] = [
        36:  0xff0d,  // Return
        76:  0xff0d,  // Keypad Enter
        48:  0xff09,  // Tab
        49:  0x0020,  // Space
        51:  0xff08,  // Delete (Backspace)
        53:  0xff1b,  // Escape
        123: 0xff51,  // Left
        124: 0xff53,  // Right
        125: 0xff54,  // Down
        126: 0xff52,  // Up
        115: 0xff50,  // Home
        119: 0xff57,  // End
        116: 0xff55,  // Page Up
        121: 0xff56,  // Page Down
        117: 0xffff,  // Forward Delete
        122: 0xffbe,  // F1
        120: 0xffbf,  // F2
        99:  0xffc0,  // F3
        118: 0xffc1,  // F4
        96:  0xffc2,  // F5
        97:  0xffc3,  // F6
        98:  0xffc4,  // F7
        100: 0xffc5,  // F8
        101: 0xffc6,  // F9
        109: 0xffc7,  // F10
        103: 0xffc8,  // F11
        111: 0xffc9,  // F12
    ]

    /// Returns the X11 keysym for this key event, or nil if unmapped.
    static func keySym(for event: NSEvent) -> Int32? {
        if let special = specialKeyCodes[event.keyCode] {
            return special
        }
        // Printable characters: X11 keysyms for Latin-1 (0x20-0xFF) equal
        // the Unicode code point directly.
        guard let scalar = event.characters?.unicodeScalars.first else { return nil }
        let value = scalar.value
        guard value >= 0x20, value <= 0xFF else { return nil }
        return Int32(value)
    }
}
