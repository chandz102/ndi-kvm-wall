import SwiftUI

struct ContentView: View {
    @State private var discovery = NDIDiscoveryManager()
    @State private var layout    = WallLayout()

    var body: some View {
        WallGridView(layout: layout, availableSources: discovery.sources)
            .onAppear { discovery.start() }
            .onDisappear { discovery.stop() }
            .onChange(of: discovery.sources) { _, sources in
                layout.restoreAssignmentsIfNeeded(from: sources)
            }
    }
}
