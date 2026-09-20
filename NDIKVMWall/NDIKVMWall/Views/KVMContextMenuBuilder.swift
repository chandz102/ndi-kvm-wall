import AppKit

/// A native NSMenu is used for assigned tiles instead of SwiftUI's
/// .contextMenu, which was found to flicker open/closed repeatedly once a
/// tile's video starts updating ~30-60x/sec underneath it (SwiftUI seems to
/// treat each frame as invalidating the menu's host view). AppKit's own
/// menu(for:) mechanism doesn't depend on SwiftUI's diffing, so it's stable
/// under continuous redraws.
final class ClosureMenuItem: NSMenuItem {
    private var handler: () -> Void

    init(title: String, checked: Bool = false, handler: @escaping () -> Void) {
        self.handler = handler
        super.init(title: title, action: #selector(invoke), keyEquivalent: "")
        self.target = self
        self.state = checked ? .on : .off
    }

    required init(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    @objc private func invoke() { handler() }
}

enum KVMContextMenuBuilder {
    static func build(
        slot: WallSlot,
        availableSources: [NDISource],
        kvmNativeSupported: Bool,
        onAssign: @escaping (NDISource) -> Void,
        onClear: @escaping () -> Void,
        onAssignControl: @escaping (NDISource) -> Void,
        onClearControl: @escaping () -> Void,
        onRename: @escaping () -> Void
    ) -> NSMenu {
        let menu = NSMenu()

        if !availableSources.isEmpty {
            let assignItem = NSMenuItem(title: "Assign Source", action: nil, keyEquivalent: "")
            let submenu = NSMenu()
            for source in availableSources {
                submenu.addItem(ClosureMenuItem(title: source.name, checked: slot.source == source) {
                    onAssign(source)
                })
            }
            assignItem.submenu = submenu
            menu.addItem(assignItem)
        }

        if !kvmNativeSupported, !availableSources.isEmpty {
            let controlItem = NSMenuItem(title: "Assign KVM Control", action: nil, keyEquivalent: "")
            let submenu = NSMenu()
            for source in availableSources {
                submenu.addItem(ClosureMenuItem(title: source.name, checked: slot.controlSource == source) {
                    onAssignControl(source)
                })
            }
            controlItem.submenu = submenu
            menu.addItem(controlItem)
            if slot.controlSource != nil {
                menu.addItem(ClosureMenuItem(title: "Clear KVM Control") { onClearControl() })
            }
        }

        menu.addItem(ClosureMenuItem(title: "Rename…") { onRename() })

        if slot.source != nil {
            menu.addItem(.separator())
            menu.addItem(ClosureMenuItem(title: "Clear") { onClear() })
        }

        return menu
    }
}
