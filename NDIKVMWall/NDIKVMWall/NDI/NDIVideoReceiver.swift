import CoreGraphics
import Foundation

@Observable @MainActor
final class NDIVideoReceiver: Identifiable {
    let id = UUID()
    var isConnected = false
    var kvmSupported = false

    /// Opaque NDI receive handle backing this connection. KVM send calls
    /// (NDIlib_recv_kvm_*) are made directly against this instance — the
    /// same connection already used for video, no separate channel.
    private(set) var recvInstance: NDIlib_recv_instance_t?

    /// Pushed directly to the displaying NSView's CALayer, bypassing
    /// SwiftUI's @Observable diffing entirely. Video arrives at 30-60fps;
    /// routing it through an @Observable property forced the whole tile's
    /// SwiftUI body (including its context menu) to re-evaluate that often,
    /// which was disrupting/flickering any open NSMenu on the tile.
    var onFrame: ((CGImage) -> Void)?

    private var task: Task<Void, Never>?

    func connect(to sourceName: String) {
        task?.cancel()
        isConnected = false
        kvmSupported = false

        task = Task.detached(priority: .userInitiated) { [weak self] in
            var recv: NDIlib_recv_instance_t?

            sourceName.withCString { namePtr in
                var source   = NDIlib_source_t()
                source.p_ndi_name = namePtr
                var settings = NDIlib_recv_create_v3_t()
                settings.source_to_connect_to = source
                settings.color_format         = NDIlib_recv_color_format_RGBX_RGBA
                settings.bandwidth            = NDIlib_recv_bandwidth_highest
                settings.allow_video_fields   = false
                recv = NDIlib_recv_create_v3(&settings)
            }

            guard let receiver = recv else { return }
            defer { NDIlib_recv_destroy(receiver) }

            let initialKVMSupport = NDIlib_recv_kvm_is_supported(receiver)
            await MainActor.run {
                self?.isConnected = true
                self?.recvInstance = receiver
                self?.kvmSupported = initialKVMSupport
            }

            while !Task.isCancelled {
                var videoFrame = NDIlib_video_frame_v2_t()
                let frameType = NDIlib_recv_capture_v2(receiver, &videoFrame, nil, nil, 1000)

                if frameType == NDIlib_frame_type_video {
                    let image = NDIVideoReceiver.makeImage(from: videoFrame)
                    NDIlib_recv_free_video_v2(receiver, &videoFrame)
                    if let image {
                        await MainActor.run { self?.onFrame?(image) }
                    }

                } else if frameType == NDIlib_frame_type_status_change {
                    let supported = NDIlib_recv_kvm_is_supported(receiver)
                    await MainActor.run { self?.kvmSupported = supported }
                }
            }

            await MainActor.run {
                self?.isConnected = false
                self?.recvInstance = nil
            }
        }
    }

    func disconnect() {
        task?.cancel()
        task         = nil
        isConnected  = false
        kvmSupported = false
        recvInstance = nil
    }

    nonisolated static func makeImage(from frame: NDIlib_video_frame_v2_t) -> CGImage? {
        guard let data = frame.p_data else { return nil }
        let width  = Int(frame.xres)
        let height = Int(frame.yres)
        let stride = Int(frame.line_stride_in_bytes)
        guard width > 0, height > 0, stride > 0 else { return nil }

        let buffer = Data(bytes: data, count: stride * height)
        guard let provider = CGDataProvider(data: buffer as CFData) else { return nil }

        return CGImage(
            width: width, height: height,
            bitsPerComponent: 8, bitsPerPixel: 32,
            bytesPerRow: stride,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue),
            provider: provider,
            decode: nil, shouldInterpolate: false, intent: .defaultIntent
        )
    }
}
