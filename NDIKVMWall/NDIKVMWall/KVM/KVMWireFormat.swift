import Foundation

/// Encoder side of our custom control protocol (see KVMProtocol.swift for
/// the matching decoder, which lives in NDIKVMHelper). Used only for slots
/// paired with an NDIKVMHelper control channel — native NDI KVM (Advanced
/// SDK) sources don't need this, they use NDIKVMSender directly.
enum KVMWireFormat {
    static func mouseMove(x: Float, y: Float) -> String { "<k t=\"mm\" x=\"\(x)\" y=\"\(y)\"/>" }
    static func mouseDown(_ b: String) -> String { "<k t=\"md\" b=\"\(b)\"/>" }
    static func mouseUp(_ b: String) -> String { "<k t=\"mu\" b=\"\(b)\"/>" }
    static func scroll(dx: Float, dy: Float) -> String { "<k t=\"sc\" dx=\"\(dx)\" dy=\"\(dy)\"/>" }
    static func keyDown(code: UInt16, flags: UInt64) -> String { "<k t=\"kd\" c=\"\(code)\" m=\"\(flags)\"/>" }
    static func keyUp(code: UInt16, flags: UInt64) -> String { "<k t=\"ku\" c=\"\(code)\" m=\"\(flags)\"/>" }
}
