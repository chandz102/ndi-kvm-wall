import CoreGraphics

/// Injects parsed KVMWireEvents into this Mac's own input stream via CGEvent.
/// Runs entirely locally — the machine controlling itself on its own behalf,
/// same as any remote-support/VNC agent. Requires Accessibility trust.
@MainActor
enum KVMEventInjector {
    private static var heldButton: CGMouseButton?
    private static var heldKeys: Set<UInt16> = []
    private static var lastPosition: CGPoint = .zero
    private static var scrollRemainder: (dx: Float, dy: Float) = (0, 0)

    /// Releases anything the controller left pressed. Called when the last
    /// controller disconnects: its keyUp/mouseUp will never arrive, and an
    /// injected key/button would otherwise stay down on this Mac.
    static func releaseAll() {
        for code in heldKeys { postKey(keyCode: code, flags: 0, down: false) }
        heldKeys = []
        if let held = heldButton {
            postMouseButton(held, down: false, at: lastPosition)
            heldButton = nil
        }
    }

    static func handle(_ message: String) {
        guard let event = KVMProtocol.parse(message) else { return }
        switch event {
        case .mouseMove(let x, let y):
            movePointer(x: x, y: y)
        case .mouseDown(let b):
            let button = mouseButton(for: b)
            heldButton = button
            postMouseButton(button, down: true, at: lastPosition)
        case .mouseUp(let b):
            let button = mouseButton(for: b)
            postMouseButton(button, down: false, at: lastPosition)
            heldButton = nil
        case .scroll(let dx, let dy):
            postScroll(dx: dx, dy: dy)
        case .keyDown(let code, let flags):
            heldKeys.insert(code)
            postKey(keyCode: code, flags: flags, down: true)
        case .keyUp(let code, let flags):
            heldKeys.remove(code)
            postKey(keyCode: code, flags: flags, down: false)
        }
    }

    private static func mouseButton(for code: String) -> CGMouseButton {
        switch code {
        case "R": return .right
        case "M": return .center
        default:  return .left
        }
    }

    private static func screenSize() -> CGSize {
        CGDisplayBounds(CGMainDisplayID()).size
    }

    private static func movePointer(x: Float, y: Float) {
        let size = screenSize()
        let nx = CGFloat(min(max(x, 0), 1)), ny = CGFloat(min(max(y, 0), 1))
        let point = CGPoint(x: nx * size.width, y: ny * size.height)
        lastPosition = point
        let type: CGEventType
        let button: CGMouseButton
        if let held = heldButton {
            button = held
            switch held {
            case .left:  type = .leftMouseDragged
            case .right: type = .rightMouseDragged
            default:     type = .otherMouseDragged
            }
        } else {
            type = .mouseMoved
            button = .left
        }
        let src = CGEventSource(stateID: .hidSystemState)
        let event = CGEvent(mouseEventSource: src, mouseType: type, mouseCursorPosition: point, mouseButton: button)
        event?.post(tap: .cghidEventTap)
    }

    private static func postMouseButton(_ button: CGMouseButton, down: Bool, at point: CGPoint) {
        let type: CGEventType
        switch (button, down) {
        case (.left, true):   type = .leftMouseDown
        case (.left, false):  type = .leftMouseUp
        case (.right, true):  type = .rightMouseDown
        case (.right, false): type = .rightMouseUp
        default:              type = down ? .otherMouseDown : .otherMouseUp
        }
        let src = CGEventSource(stateID: .hidSystemState)
        let event = CGEvent(mouseEventSource: src, mouseType: type, mouseCursorPosition: point, mouseButton: button)
        event?.post(tap: .cghidEventTap)
    }

    private static func postScroll(dx: Float, dy: Float) {
        // Trackpad deltas arrive as fractions (the controller divides by 10);
        // Int32(_:) truncated nearly all of them to 0, so smooth scrolling
        // did nothing. Carry the fractional part over to the next event.
        // Clamp first: Int32(_:) traps on out-of-range values from the wire.
        let ty = scrollRemainder.dy + min(max(dy, -10_000), 10_000)
        let tx = scrollRemainder.dx + min(max(dx, -10_000), 10_000)
        let iy = ty.rounded(.towardZero), ix = tx.rounded(.towardZero)
        scrollRemainder = (dx: tx - ix, dy: ty - iy)
        guard iy != 0 || ix != 0 else { return }
        let event = CGEvent(scrollWheelEvent2Source: nil, units: .pixel,
                             wheelCount: 2, wheel1: Int32(iy), wheel2: Int32(ix), wheel3: 0)
        event?.post(tap: .cghidEventTap)
    }

    private static func postKey(keyCode: UInt16, flags: UInt64, down: Bool) {
        let src = CGEventSource(stateID: .hidSystemState)
        guard let event = CGEvent(keyboardEventSource: src, virtualKey: keyCode, keyDown: down) else { return }
        event.flags = CGEventFlags(rawValue: flags)
        event.post(tap: .cghidEventTap)
    }
}
