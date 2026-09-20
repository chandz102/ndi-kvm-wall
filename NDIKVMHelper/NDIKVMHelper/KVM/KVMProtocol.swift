import Foundation

/// Our own compact control protocol carried over NDIlib_recv_send_metadata /
/// NDIlib_send_capture. Not related to NDI's official (undocumented, receive-
/// only) Advanced-SDK KVM feature — this exists because that feature has no
/// public sender-side implementation, so this app IS the sender side, and we
/// define the wire format ourselves. Keep this file identical to the copy in
/// NDIKVMWall's project (KVMProtocol.swift there has the matching encoder).
enum KVMWireEvent {
    case mouseMove(x: Float, y: Float)
    case mouseDown(String)   // "L" / "R" / "M"
    case mouseUp(String)
    case scroll(dx: Float, dy: Float)
    case keyDown(code: UInt16, flags: UInt64)
    case keyUp(code: UInt16, flags: UInt64)
}

enum KVMProtocol {
    static func parse(_ s: String) -> KVMWireEvent? {
        guard let t = attr(s, "t") else { return nil }
        switch t {
        case "mm":
            guard let x = attrFloat(s, "x"), let y = attrFloat(s, "y") else { return nil }
            return .mouseMove(x: x, y: y)
        case "md":
            guard let b = attr(s, "b") else { return nil }
            return .mouseDown(b)
        case "mu":
            guard let b = attr(s, "b") else { return nil }
            return .mouseUp(b)
        case "sc":
            guard let dx = attrFloat(s, "dx"), let dy = attrFloat(s, "dy") else { return nil }
            return .scroll(dx: dx, dy: dy)
        case "kd":
            guard let c = attrUInt(s, "c"), let m = attrUInt64(s, "m") else { return nil }
            return .keyDown(code: UInt16(c), flags: m)
        case "ku":
            guard let c = attrUInt(s, "c"), let m = attrUInt64(s, "m") else { return nil }
            return .keyUp(code: UInt16(c), flags: m)
        default:
            return nil
        }
    }

    private static func attr(_ s: String, _ name: String) -> String? {
        guard let range = s.range(of: "\(name)=\"") else { return nil }
        let after = s[range.upperBound...]
        guard let end = after.firstIndex(of: "\"") else { return nil }
        return String(after[..<end])
    }
    private static func attrFloat(_ s: String, _ name: String) -> Float? { attr(s, name).flatMap { Float($0) } }
    private static func attrUInt(_ s: String, _ name: String) -> UInt? { attr(s, name).flatMap { UInt($0) } }
    private static func attrUInt64(_ s: String, _ name: String) -> UInt64? { attr(s, name).flatMap { UInt64($0) } }
}
