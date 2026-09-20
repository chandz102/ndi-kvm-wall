import SwiftUI

struct SettingsView: View {
    var layout: WallLayout
    @State private var settings = AppSettings.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section("Grid") {
                    Picker("Number of sources", selection: Binding(
                        get: { settings.slotCount },
                        set: { settings.slotCount = $0; settings.save() }
                    )) {
                        ForEach(SlotCount.allCases, id: \.self) { c in
                            Text(c.label).tag(c)
                        }
                    }
                    .pickerStyle(.radioGroup)
                }

                Section("KVM Control") {
                    Text("Click into a tile to take control of that PC's mouse/keyboard. Its border turns cyan while active. Press Esc, or click a different tile, to release control.")
                        .font(.caption).foregroundStyle(.secondary)
                    Text("Requires that PC to be running NDI Screen Capture with \"KVM Control\" enabled. A tile shows \"KVM not available\" if the connected source doesn't support it.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)

            HStack {
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
                    .padding([.horizontal, .bottom])
            }
        }
        .frame(width: 420, height: 300)
        .onDisappear { settings.save() }
        .onExitCommand { dismiss() }
    }
}
