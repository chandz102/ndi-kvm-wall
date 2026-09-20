import Foundation

/// A lightweight NDI receive connection used ONLY to talk to an
/// NDIKVMHelper instance's control-only source — video frames are received
/// and immediately discarded, just enough to keep the connection healthy so
/// NDIlib_recv_send_metadata reliably delivers our KVMWireEvent commands.
@Observable @MainActor
final class NDIControlChannel {
    var isConnected = false

    private var task: Task<Void, Never>?
    private var recvInstance: NDIlib_recv_instance_t?

    func connect(to sourceName: String) {
        task?.cancel()
        isConnected = false

        task = Task.detached(priority: .utility) { [weak self] in
            var recv: NDIlib_recv_instance_t?
            sourceName.withCString { namePtr in
                var source   = NDIlib_source_t()
                source.p_ndi_name = namePtr
                var settings = NDIlib_recv_create_v3_t()
                settings.source_to_connect_to = source
                settings.color_format         = NDIlib_recv_color_format_fastest
                settings.bandwidth            = NDIlib_recv_bandwidth_metadata_only
                recv = NDIlib_recv_create_v3(&settings)
            }
            guard let receiver = recv else { return }
            defer { NDIlib_recv_destroy(receiver) }

            await MainActor.run {
                self?.recvInstance = receiver
                self?.isConnected = true
            }

            while !Task.isCancelled {
                var videoFrame = NDIlib_video_frame_v2_t()
                let frameType = NDIlib_recv_capture_v2(receiver, &videoFrame, nil, nil, 500)
                if frameType == NDIlib_frame_type_video {
                    NDIlib_recv_free_video_v2(receiver, &videoFrame)
                }
            }

            await MainActor.run {
                self?.recvInstance = nil
                self?.isConnected = false
            }
        }
    }

    func disconnect() {
        task?.cancel()
        task = nil
        isConnected = false
        recvInstance = nil
    }

    func send(_ command: String) {
        guard let recv = recvInstance else { return }
        command.withCString { ptr in
            var metadata = NDIlib_metadata_frame_t()
            metadata.length = Int32(strlen(ptr) + 1) // include NULL terminator, per NDI convention
            metadata.p_data = UnsafeMutablePointer(mutating: ptr)
            NDIlib_recv_send_metadata(recv, &metadata)
        }
    }
}
