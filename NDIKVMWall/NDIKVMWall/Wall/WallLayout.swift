import Foundation

// MARK: - WallSlot

@Observable @MainActor
final class WallSlot: Identifiable {
    let id: Int
    var label: String
    var customName: String?
    var source: NDISource?
    var receiver: NDIVideoReceiver?

    /// A separate NDI source (an NDIKVMHelper instance) used purely as a
    /// control channel for Macs, whose "Scan Converter"-style video sender
    /// has no native NDI KVM support. Independent of `source`/`receiver`.
    var controlSource: NDISource?
    var controlChannel: NDIControlChannel?

    var displayName: String { customName ?? label }

    init(id: Int) {
        self.id    = id
        self.label = "Slot \(id + 1)"
    }

    func assign(_ source: NDISource) {
        if self.source == source, receiver?.isConnected == true { return }
        receiver?.disconnect()
        self.source = source
        self.label  = source.name
        let r = NDIVideoReceiver()
        r.connect(to: source.name)
        self.receiver = r
    }

    func assignControl(_ source: NDISource) {
        controlChannel?.disconnect()
        controlSource = source
        let c = NDIControlChannel()
        c.connect(to: source.name)
        controlChannel = c
    }

    func clearControl() {
        controlChannel?.disconnect()
        controlChannel = nil
        controlSource = nil
    }

    func clear() {
        receiver?.disconnect()
        receiver   = nil
        source     = nil
        customName = nil
        label      = "Slot \(id + 1)"
        clearControl()
    }
}

// MARK: - Persistence

private struct SlotState: Codable {
    var id: Int
    var sourceName: String?
    var customName: String?
    var controlSourceName: String?
}

// MARK: - WallLayout

@Observable @MainActor
final class WallLayout {
    let slots: [WallSlot] = (0..<6).map { WallSlot(id: $0) }

    /// Which slot is currently receiving live mouse/keyboard forwarding.
    /// Not persisted — resets to nil on relaunch.
    var kvmActiveSlotID: Int? = nil

    func assign(source: NDISource, to slot: WallSlot) {
        slot.assign(source)
        saveAssignments()
    }

    func clear(slot: WallSlot) {
        slot.clear()
        saveAssignments()
    }

    func assignControl(source: NDISource, to slot: WallSlot) {
        slot.assignControl(source)
        saveAssignments()
    }

    func clearControl(slot: WallSlot) {
        slot.clearControl()
        saveAssignments()
    }

    func activateKVM(slot: WallSlot) {
        kvmActiveSlotID = slot.id
    }

    /// Only clears the active slot if it still points at `slot` — guards
    /// against a stale resignFirstResponder callback (from switching away
    /// to activate a different slot) clobbering a newer activation.
    func deactivateKVM(slot: WallSlot) {
        if kvmActiveSlotID == slot.id { kvmActiveSlotID = nil }
    }

    // MARK: - Persistence

    func saveAssignments() {
        let states = slots.map {
            SlotState(id: $0.id, sourceName: $0.source?.name, customName: $0.customName,
                      controlSourceName: $0.controlSource?.name)
        }
        if let data = try? JSONEncoder().encode(states) {
            UserDefaults.standard.set(data, forKey: "wallAssignments_v1")
        }
    }

    private var hasRestoredAssignments = false

    func restoreAssignmentsIfNeeded(from sources: [NDISource]) {
        guard !hasRestoredAssignments, !sources.isEmpty else { return }
        hasRestoredAssignments = true

        guard let data   = UserDefaults.standard.data(forKey: "wallAssignments_v1"),
              let states = try? JSONDecoder().decode([SlotState].self, from: data) else { return }

        for state in states {
            guard let slot = slots.first(where: { $0.id == state.id }) else { continue }
            slot.customName = state.customName
            if let name = state.sourceName,
               let source = sources.first(where: { $0.name == name }) {
                slot.assign(source)
            }
            if let controlName = state.controlSourceName,
               let controlSource = sources.first(where: { $0.name == controlName }) {
                slot.assignControl(controlSource)
            }
        }
    }
}
