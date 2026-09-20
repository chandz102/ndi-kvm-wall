import SwiftUI

@main
struct NDIKVMHelperApp: App {
    @State private var engine = KVMHelperEngine()

    init() {
        guard NDIlib_initialize() else {
            fatalError("NDI initialization failed — unsupported CPU or missing library")
        }
    }

    var body: some Scene {
        // A plain, definitely-valid SF Symbol here — an invalid/uncertain
        // symbol name can make MenuBarExtra render an invisible icon while
        // the app keeps running with no visible way to reach it.
        MenuBarExtra {
            MenuBarContentView(engine: engine)
        } label: {
            Label("KVM", systemImage: "keyboard")
        }
    }
}
