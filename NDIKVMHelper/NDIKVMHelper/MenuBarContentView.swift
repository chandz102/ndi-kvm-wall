import SwiftUI

struct MenuBarContentView: View {
    var engine: KVMHelperEngine

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("NDI KVM Helper").font(.headline)
            Text(engine.sourceName)
                .font(.caption).foregroundStyle(.secondary)

            Divider()

            HStack(spacing: 6) {
                Circle().fill(engine.isTrusted ? Color.green : Color.red).frame(width: 8, height: 8)
                Text(engine.isTrusted ? "Accessibility granted" : "Accessibility not granted")
                    .font(.caption)
            }
            if !engine.isTrusted {
                Button("Grant Accessibility Access…") { engine.requestTrust() }
                Text("Required to inject keyboard/mouse input on this Mac. Relaunch after granting.")
                    .font(.caption2).foregroundStyle(.secondary)
            }

            Divider()

            Text(engine.isRunning
                 ? "\(engine.connectionCount) controller(s) connected"
                 : "Not running")
                .font(.caption).foregroundStyle(.secondary)

            Divider()

            Button("Quit NDI KVM Helper") { NSApplication.shared.terminate(nil) }
        }
        .padding(12)
        .frame(width: 280)
    }
}
