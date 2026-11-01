import Foundation
import ApplicationServices

@Observable @MainActor
final class KVMHelperEngine {
    var isTrusted: Bool { AXIsProcessTrusted() }
    var isRunning = false
    var sourceName = ""
    var connectionCount = 0

    private var task: Task<Void, Never>?

    init() {
        start()
    }

    @discardableResult
    func requestTrust() -> Bool {
        let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        return AXIsProcessTrustedWithOptions(opts as CFDictionary)
    }

    private func start() {
        guard task == nil else { return }

        let host = ProcessInfo.processInfo.hostName.replacingOccurrences(of: ".local", with: "")
        let name = "\(host) (KVM Helper)"
        sourceName = name

        task = Task.detached(priority: .userInitiated) { [weak self] in
            var createSettings = NDIlib_send_create_t()
            var senderOpt: NDIlib_send_instance_t?
            name.withCString { namePtr in
                createSettings.p_ndi_name  = namePtr
                createSettings.clock_video = true
                senderOpt = NDIlib_send_create(&createSettings)
            }
            guard let sender = senderOpt else { return }
            defer { NDIlib_send_destroy(sender) }

            await MainActor.run { self?.isRunning = true }

            // Minimal placeholder frame — just enough to keep this a healthy,
            // discoverable NDI source. This app carries no real video.
            let width = 64, height = 36
            var pixels = [UInt8](repeating: 0, count: width * height * 4)
            for i in stride(from: 0, to: pixels.count, by: 4) {
                pixels[i] = 20; pixels[i + 1] = 20; pixels[i + 2] = 20; pixels[i + 3] = 255
            }
            var lastFrameSent = Date.distantPast
            var lastConnections: Int32 = 0

            while !Task.isCancelled {
                if Date().timeIntervalSince(lastFrameSent) > 1.0 {
                    pixels.withUnsafeMutableBufferPointer { buf in
                        var frame = NDIlib_video_frame_v2_t()
                        frame.xres = Int32(width)
                        frame.yres = Int32(height)
                        frame.FourCC = NDIlib_FourCC_type_BGRA
                        frame.line_stride_in_bytes = Int32(width * 4)
                        frame.p_data = buf.baseAddress
                        NDIlib_send_send_video_v2(sender, &frame)
                    }
                    lastFrameSent = Date()
                }

                var metadata = NDIlib_metadata_frame_t()
                let frameType = NDIlib_send_capture(sender, &metadata, 200)
                if frameType == NDIlib_frame_type_metadata, let data = metadata.p_data {
                    let text = String(cString: data)
                    NDIlib_send_free_metadata(sender, &metadata)
                    await MainActor.run { KVMEventInjector.handle(text) }
                }

                let connections = NDIlib_send_get_no_connections(sender, 0)
                let lostAllControllers = lastConnections > 0 && connections == 0
                lastConnections = connections
                await MainActor.run {
                    if lostAllControllers { KVMEventInjector.releaseAll() }
                    self?.connectionCount = Int(connections)
                }
            }
            await MainActor.run { KVMEventInjector.releaseAll() }

            await MainActor.run { self?.isRunning = false }
        }
    }
}
