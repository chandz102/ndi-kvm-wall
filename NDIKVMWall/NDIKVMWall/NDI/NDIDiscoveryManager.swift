import Foundation

@Observable
@MainActor
final class NDIDiscoveryManager {
    var sources: [NDISource] = []

    private var discoveryTask: Task<Void, Never>?

    func start() {
        discoveryTask = Task.detached(priority: .utility) { [weak self] in
            var createSettings = NDIlib_find_create_t()
            createSettings.show_local_sources = true
            createSettings.p_groups = nil
            createSettings.p_extra_ips = nil

            guard let finder = NDIlib_find_create_v2(&createSettings) else {
                print("NDI: failed to create finder")
                return
            }
            defer { NDIlib_find_destroy(finder) }

            while !Task.isCancelled {
                NDIlib_find_wait_for_sources(finder, 1000)

                var count: UInt32 = 0
                guard let ptr = NDIlib_find_get_current_sources(finder, &count) else {
                    continue
                }

                var found: [NDISource] = []
                for i in 0..<Int(count) {
                    let src = ptr[i]
                    let name = src.p_ndi_name.map { String(cString: $0) } ?? "Unknown"
                    let url  = src.p_url_address.map { String(cString: $0) } ?? ""
                    found.append(NDISource(name: name, urlAddress: url))
                }

                await MainActor.run {
                    self?.sources = found
                }
            }
        }
    }

    func stop() {
        discoveryTask?.cancel()
        discoveryTask = nil
    }
}
