import SwiftUI

struct WallGridView: View {
    var layout: WallLayout
    var availableSources: [NDISource]

    @State private var showSettings = false

    private var settings: AppSettings { AppSettings.shared }

    private var activeSlots: [WallSlot] {
        Array(layout.slots.prefix(settings.slotCount.rawValue))
    }

    var body: some View {
        wallGrid
            .background(Color.black)
            .sheet(isPresented: $showSettings) {
                SettingsView(layout: layout)
            }
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    Button { showSettings = true } label: {
                        Image(systemName: "gearshape")
                    }
                    .help("Settings")
                }
            }
    }

    @ViewBuilder
    private var wallGrid: some View {
        let cols    = settings.slotCount.columns
        let all     = activeSlots
        let rows    = (all.count + cols - 1) / cols

        VStack(spacing: 2) {
            ForEach(0..<rows, id: \.self) { row in
                HStack(spacing: 2) {
                    let start = row * cols
                    let end   = min(start + cols, all.count)
                    ForEach(all[start..<end]) { tile($0) }
                }
            }
        }
    }

    @ViewBuilder
    private func tile(_ slot: WallSlot) -> some View {
        WallTileView(
            slot: slot,
            isKVMActive: layout.kvmActiveSlotID == slot.id,
            availableSources: availableSources,
            onAssign:          { src in layout.assign(source: src, to: slot) },
            onClear:           { layout.clear(slot: slot) },
            onAssignControl:   { src in layout.assignControl(source: src, to: slot) },
            onClearControl:    { layout.clearControl(slot: slot) },
            onActivateKVM:     { layout.activateKVM(slot: slot) },
            onDeactivateKVM:   { layout.deactivateKVM(slot: slot) }
        )
    }
}
