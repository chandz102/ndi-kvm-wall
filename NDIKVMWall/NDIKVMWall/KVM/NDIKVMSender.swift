import Foundation

/// Thin wrapper around the NDI Advanced SDK's NDIlib_recv_kvm_* calls.
/// All calls act on the receiver's existing NDI connection — no separate
/// channel or permission is needed, unlike system-wide input injection.
enum NDIKVMSender {
    static func mouseMove(_ recv: NDIlib_recv_instance_t, x: Float, y: Float) {
        var posn: [Float] = [x, y]
        NDIlib_recv_kvm_send_mouse_position(recv, &posn)
    }

    static func mouseDown(_ recv: NDIlib_recv_instance_t, button: MouseButton) {
        switch button {
        case .left:   NDIlib_recv_kvm_send_left_mouse_click(recv)
        case .right:  NDIlib_recv_kvm_send_right_mouse_click(recv)
        case .middle: NDIlib_recv_kvm_send_middle_mouse_click(recv)
        }
    }

    static func mouseUp(_ recv: NDIlib_recv_instance_t, button: MouseButton) {
        switch button {
        case .left:   NDIlib_recv_kvm_send_left_mouse_release(recv)
        case .right:  NDIlib_recv_kvm_send_right_mouse_release(recv)
        case .middle: NDIlib_recv_kvm_send_middle_mouse_release(recv)
        }
    }

    static func scroll(_ recv: NDIlib_recv_instance_t, verticalUnits: Float, horizontalUnits: Float) {
        if verticalUnits != 0 {
            NDIlib_recv_kvm_send_vertical_mouse_wheel(recv, verticalUnits)
        }
        if horizontalUnits != 0 {
            NDIlib_recv_kvm_send_horizontal_mouse_wheel(recv, horizontalUnits)
        }
    }

    static func keyDown(_ recv: NDIlib_recv_instance_t, keySym: Int32) {
        NDIlib_recv_kvm_send_keyboard_press(recv, keySym)
    }

    static func keyUp(_ recv: NDIlib_recv_instance_t, keySym: Int32) {
        NDIlib_recv_kvm_send_keyboard_release(recv, keySym)
    }

    enum MouseButton { case left, right, middle }
}
