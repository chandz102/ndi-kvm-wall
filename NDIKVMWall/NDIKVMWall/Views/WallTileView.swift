import SwiftUI
import AppKit

struct WallTileView: View {
    var slot: WallSlot
    var isKVMActive: Bool = false
    var availableSources: [NDISource] = []
    var onAssign: ((NDISource) -> Void)? = nil
    var onClear:  (() -> Void)? = nil
    var onAssignControl: ((NDISource) -> Void)? = nil
    var onClearControl:  (() -> Void)? = nil
    var onActivateKVM:   (() -> Void)? = nil
    var onDeactivateKVM: (() -> Void)? = nil

    @State private var isEditing  = false
    @State private var editText   = ""
    @FocusState private var fieldFocused: Bool

    /// Prefer native NDI KVM (works on the video source itself, e.g.
    /// Windows NDI Screen Capture); fall back to a paired NDIKVMHelper relay
    /// (for Macs, whose NDI Scan Converter has no native KVM support).
    private var transport: KVMTransport? {
        if let recv = slot.receiver?.recvInstance, slot.receiver?.kvmSupported == true {
            return .native(recv)
        }
        if let channel = slot.controlChannel, channel.isConnected {
            return .relay(channel)
        }
        return nil
    }
    private var kvmSupported: Bool { transport != nil }
    private var borderColor: Color { isKVMActive ? .cyan : Color(white: 0.2) }
    private var borderWidth: CGFloat { isKVMActive ? 4 : 1 }

    var body: some View {
        Group {
            if slot.receiver == nil {
                // Static placeholder — SwiftUI's .contextMenu is fine here,
                // nothing underneath is redrawing.
                tileBody
                    .contextMenu { contextMenuItems }
            } else {
                // Live-updating video — SwiftUI's .contextMenu modifier,
                // even attached conditionally, intercepts the right-click
                // itself and never lets it reach the embedded NSView, so it
                // must be entirely absent from this branch. KVMVideoView
                // supplies a native NSMenu instead (KVMContextMenuBuilder).
                tileBody
            }
        }
    }

    private var tileBody: some View {
        VStack(spacing: 0) {
            videoArea
            nameStrip
        }
        .overlay(Rectangle().strokeBorder(borderColor, lineWidth: borderWidth))
    }

    // ── Video area ─────────────────────────────────────────────────────────
    private var videoArea: some View {
        ZStack {
            if slot.receiver != nil {
                KVMVideoView(
                    receiver: slot.receiver,
                    transport: transport,
                    isActive: isKVMActive,
                    onRequestActivate: { if kvmSupported { onActivateKVM?() } },
                    onDeactivate: { onDeactivateKVM?() },
                    buildMenu: { makeContextMenu() }
                )
            } else {
                Color.black
                VStack(spacing: 6) {
                    Image(systemName: "plus.circle")
                        .font(.system(size: 20))
                        .foregroundStyle(.secondary)
                    Text("Right-click to assign")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            if slot.receiver != nil && !kvmSupported {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Text(slot.controlSource == nil
                             ? "KVM not available — right-click to pair a KVM Helper"
                             : "KVM Helper not connected")
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                            .padding(4)
                            .background(Color.black.opacity(0.6))
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                            .padding(4)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }

    // ── Name strip ─────────────────────────────────────────────────────────
    private var nameStrip: some View {
        ZStack {
            Color(white: 0.1)
            HStack(spacing: 4) {
                if isEditing {
                    TextField("", text: $editText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .focused($fieldFocused)
                        .onSubmit { commitEdit() }
                        .onExitCommand { cancelEdit() }
                } else {
                    Text(slot.displayName)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 6)
                        .onTapGesture(count: 2) { startEditing() }
                }
                if isKVMActive {
                    Image(systemName: "keyboard.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.cyan)
                        .padding(.trailing, 6)
                }
            }
        }
        .frame(height: 20)
        .onChange(of: fieldFocused) { _, focused in
            if !focused && isEditing { commitEdit() }
        }
    }

    // ── Context menu ───────────────────────────────────────────────────────
    @ViewBuilder
    private var contextMenuItems: some View {
        if !availableSources.isEmpty {
            Menu("Assign Source") {
                ForEach(availableSources) { source in
                    Button {
                        onAssign?(source)
                    } label: {
                        if slot.source == source {
                            Label(source.name, systemImage: "checkmark")
                        } else {
                            Text(source.name)
                        }
                    }
                }
            }
        }

        if slot.receiver?.kvmSupported == false, !availableSources.isEmpty {
            Menu("Assign KVM Control") {
                ForEach(availableSources) { source in
                    Button {
                        onAssignControl?(source)
                    } label: {
                        if slot.controlSource == source {
                            Label(source.name, systemImage: "checkmark")
                        } else {
                            Text(source.name)
                        }
                    }
                }
            }
            .help("Pair with an NDIKVMHelper source running on this Mac, since its video source has no native NDI KVM support.")
            if slot.controlSource != nil {
                Button("Clear KVM Control") { onClearControl?() }
            }
        }

        Button("Rename…") { startEditing() }

        if slot.source != nil {
            Divider()
            Button("Clear", role: .destructive) { onClear?() }
        }
    }

    // ── Native menu (used once a source is assigned) ────────────────────────
    private func makeContextMenu() -> NSMenu {
        KVMContextMenuBuilder.build(
            slot: slot,
            availableSources: availableSources,
            kvmNativeSupported: slot.receiver?.kvmSupported ?? false,
            onAssign: { source in onAssign?(source) },
            onClear: { onClear?() },
            onAssignControl: { source in onAssignControl?(source) },
            onClearControl: { onClearControl?() },
            onRename: { startEditing() }
        )
    }

    // ── Helpers ────────────────────────────────────────────────────────────
    private func startEditing() {
        editText     = slot.displayName
        isEditing    = true
        fieldFocused = true
    }

    private func commitEdit() {
        let trimmed = editText.trimmingCharacters(in: .whitespaces)
        slot.customName = trimmed.isEmpty ? nil : trimmed
        isEditing    = false
        fieldFocused = false
    }

    private func cancelEdit() {
        isEditing    = false
        fieldFocused = false
    }
}
