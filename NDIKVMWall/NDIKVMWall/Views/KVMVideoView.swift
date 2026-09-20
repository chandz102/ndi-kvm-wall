import SwiftUI
import AppKit

/// How a tile's control input actually reaches its remote machine.
enum KVMTransport {
    /// The connected source itself supports NDI's official (Advanced SDK,
    /// receive-only) KVM feature — e.g. Windows NDI Screen Capture.
    case native(NDIlib_recv_instance_t)
    /// The source doesn't support native KVM (e.g. macOS NDI Scan Converter),
    /// but a paired NDIKVMHelper instance is running on the same Mac — we
    /// talk to it over our own protocol via NDIlib_recv_send_metadata.
    case relay(NDIControlChannel)
}

/// Displays the tile's video frame and, when active, captures mouse and
/// keyboard input locally within its own bounds and forwards it to whichever
/// transport is available. No system permission is needed on THIS machine —
/// input is only read while the cursor/keyboard focus is inside this view,
/// never injected into the local OS.
struct KVMVideoView: NSViewRepresentable {
    /// The receiver itself, not its current frame — video is pushed directly
    /// to the NSView's layer via `receiver.onFrame`, bypassing SwiftUI's
    /// @Observable diffing so 30-60fps frame arrival doesn't force this
    /// view's whole SwiftUI subtree (and any open context menu) to
    /// re-evaluate that often.
    let receiver: NDIVideoReceiver?
    let transport: KVMTransport?
    let isActive: Bool
    var onRequestActivate: () -> Void
    var onDeactivate: () -> Void
    /// Builds the native right-click menu (Assign Source / KVM Control /
    /// Rename / Clear) — see KVMContextMenuBuilder for why this isn't a
    /// SwiftUI .contextMenu.
    var buildMenu: () -> NSMenu

    func makeNSView(context: Context) -> KVMSurfaceNSView {
        let view = KVMSurfaceNSView()
        view.wantsLayer = true
        view.layer?.backgroundColor = CGColor(gray: 0.05, alpha: 1)
        view.layer?.contentsGravity = .resizeAspect
        return view
    }

    func updateNSView(_ nsView: KVMSurfaceNSView, context: Context) {
        if nsView.receiver !== receiver {
            nsView.receiver = receiver
            receiver?.onFrame = { [weak nsView] image in
                nsView?.layer?.contents = image
            }
        }
        nsView.transport = transport
        nsView.onRequestActivate = onRequestActivate
        nsView.onDeactivate = onDeactivate
        nsView.buildMenu = buildMenu
        if nsView.isActive != isActive {
            nsView.isActive = isActive
            if isActive { nsView.window?.makeFirstResponder(nsView) }
        }
    }
}

final class KVMSurfaceNSView: NSView {
    var receiver: NDIVideoReceiver?
    var transport: KVMTransport?
    var isActive = false
    var onRequestActivate: (() -> Void)?
    var onDeactivate: (() -> Void)?
    var buildMenu: (() -> NSMenu)?

    override func menu(for event: NSEvent) -> NSMenu? {
        guard !isActive else { return nil }
        return buildMenu?()
    }

    private var trackingArea: NSTrackingArea?

    override var acceptsFirstResponder: Bool { true }

    override func resignFirstResponder() -> Bool {
        if isActive { onDeactivate?() }
        return super.resignFirstResponder()
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea { removeTrackingArea(trackingArea) }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.activeAlways, .mouseMoved, .mouseEnteredAndExited, .inVisibleRect],
            owner: self, userInfo: nil)
        addTrackingArea(area)
        trackingArea = area
    }

    private func normalizedPosition(for event: NSEvent) -> (x: Float, y: Float) {
        let loc = convert(event.locationInWindow, from: nil)
        let x = min(max(Float(loc.x / max(bounds.width, 1)), 0), 1)
        let y = min(max(Float(1 - loc.y / max(bounds.height, 1)), 0), 1)
        return (x, y)
    }

    // MARK: - Dispatch

    private func move(x: Float, y: Float) {
        switch transport {
        case .native(let recv): NDIKVMSender.mouseMove(recv, x: x, y: y)
        case .relay(let ch):    ch.send(KVMWireFormat.mouseMove(x: x, y: y))
        case nil: break
        }
    }

    private func mouseButton(_ button: NDIKVMSender.MouseButton, down: Bool) {
        let code = { () -> String in
            switch button {
            case .left: return "L"; case .right: return "R"; case .middle: return "M"
            }
        }()
        switch transport {
        case .native(let recv):
            if down { NDIKVMSender.mouseDown(recv, button: button) }
            else    { NDIKVMSender.mouseUp(recv, button: button) }
        case .relay(let ch):
            ch.send(down ? KVMWireFormat.mouseDown(code) : KVMWireFormat.mouseUp(code))
        case nil: break
        }
    }

    private func scroll(dx: Float, dy: Float) {
        switch transport {
        case .native(let recv): NDIKVMSender.scroll(recv, verticalUnits: dy, horizontalUnits: dx)
        case .relay(let ch):    ch.send(KVMWireFormat.scroll(dx: dx, dy: dy))
        case nil: break
        }
    }

    private func key(_ event: NSEvent, down: Bool) {
        switch transport {
        case .native(let recv):
            guard let sym = KeySymMapping.keySym(for: event) else { return }
            if down { NDIKVMSender.keyDown(recv, keySym: sym) }
            else    { NDIKVMSender.keyUp(recv, keySym: sym) }
        case .relay(let ch):
            let flags = UInt64(event.modifierFlags.rawValue)
            ch.send(down ? KVMWireFormat.keyDown(code: event.keyCode, flags: flags)
                         : KVMWireFormat.keyUp(code: event.keyCode, flags: flags))
        case nil: break
        }
    }

    // MARK: - Mouse

    override func mouseDown(with event: NSEvent) {
        guard isActive, transport != nil else { onRequestActivate?(); return }
        let p = normalizedPosition(for: event)
        move(x: p.x, y: p.y)
        mouseButton(.left, down: true)
    }

    override func mouseUp(with event: NSEvent) {
        guard isActive, transport != nil else { return }
        mouseButton(.left, down: false)
    }

    override func rightMouseDown(with event: NSEvent) {
        // Not active: don't swallow the event — let it bubble up so
        // SwiftUI's .contextMenu (Assign Source / Rename / Clear) still
        // opens. Only intercept when actively driving the remote machine.
        guard isActive, transport != nil else {
            super.rightMouseDown(with: event)
            return
        }
        let p = normalizedPosition(for: event)
        move(x: p.x, y: p.y)
        mouseButton(.right, down: true)
    }

    override func rightMouseUp(with event: NSEvent) {
        guard isActive, transport != nil else {
            super.rightMouseUp(with: event)
            return
        }
        mouseButton(.right, down: false)
    }

    override func otherMouseDown(with event: NSEvent) {
        guard isActive, transport != nil else { return }
        let p = normalizedPosition(for: event)
        move(x: p.x, y: p.y)
        mouseButton(.middle, down: true)
    }

    override func otherMouseUp(with event: NSEvent) {
        guard isActive, transport != nil else { return }
        mouseButton(.middle, down: false)
    }

    override func mouseMoved(with event: NSEvent) {
        guard isActive, transport != nil else { return }
        let p = normalizedPosition(for: event)
        move(x: p.x, y: p.y)
    }

    override func mouseDragged(with event: NSEvent) {
        guard isActive, transport != nil else { return }
        let p = normalizedPosition(for: event)
        move(x: p.x, y: p.y)
    }

    override func scrollWheel(with event: NSEvent) {
        guard isActive, transport != nil else { return }
        scroll(dx: Float(-event.scrollingDeltaX / 10), dy: Float(-event.scrollingDeltaY / 10))
    }

    // MARK: - Keyboard

    override func keyDown(with event: NSEvent) {
        guard isActive else { return }
        if event.keyCode == 53 { // Escape exits capture, not forwarded
            onDeactivate?()
            return
        }
        guard transport != nil else { return }
        key(event, down: true)
    }

    override func keyUp(with event: NSEvent) {
        guard isActive, event.keyCode != 53, transport != nil else { return }
        key(event, down: false)
    }
}
