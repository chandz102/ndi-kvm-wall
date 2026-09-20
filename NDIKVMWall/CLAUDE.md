# NDIKVMWall — Project Brief

macOS app (Apple Silicon) built with SwiftUI. An NDI video wall: shows 4–6 NDI sources as
equal-size tiles; click into a tile's video area to take live keyboard/mouse control of that
machine. Forked from `../NDIMultiviewer` (a broadcast mixer app) — shares the NDI
discovery/receive plumbing but drops all PVW/PGM/TAKE/OSC/tally/HDMI-output code.

---

## Build & Run

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -project NDIKVMWall.xcodeproj -scheme NDIKVMWall -configuration Debug build
```

**Deployment target:** macOS 26.5 · **Swift:** 6.3.2
**NDI SDK:** `/Library/NDI Advanced SDK for Apple/` (not the standard SDK — see below)

**Sandboxed** (`ENABLE_APP_SANDBOX = YES`) — this app never injects local input itself, it
only sends NDI network messages, so no Accessibility permission or sandbox exception is
needed here (unlike `../NDIKVMHelper`, which does inject input and is deliberately not
sandboxed).

---

## Two KVM transports

NDI's Advanced SDK has an official KVM feature (`NDIlib_recv_kvm_send_*`), but it's
**receive-only** — there's no public sender-side API or documented wire format, and NDI's own
macOS "Scan Converter" tool never implemented it (unlike Windows' "NDI Screen Capture", which
has it built in). So this app supports two paths, chosen automatically per tile
(`WallTileView.transport`):

1. **`.native`** — the connected source itself reports `NDIlib_recv_kvm_is_supported() ==
   true` (Windows NDI Screen Capture with KVM Control enabled). Calls
   `NDIlib_recv_kvm_send_keyboard_press` etc. directly via `KVM/NDIKVMSender.swift`, using
   X11 keysym values via `KVM/KeySymMapping.swift`.
2. **`.relay`** — no native support (all Mac sources), but a `../NDIKVMHelper` instance is
   paired via `WallSlot.controlChannel` (`KVM/NDIControlChannel.swift`, a metadata-only NDI
   receive connection). Commands are encoded with `KVM/KVMWireFormat.swift` — our own protocol,
   raw macOS virtual keycodes + modifier flags, no keysym translation needed since both ends
   are code we control — and sent via `NDIlib_recv_send_metadata`. NDIKVMHelper decodes the
   identical format (`KVMProtocol.swift`, kept in sync by hand between the two projects) and
   injects it locally.

---

## Project Layout

```
NDIKVMWall/
├── NDIKVMWallApp.swift        # @main — NDIlib_initialize()
├── ContentView.swift          # hosts WallGridView, drives NDI discovery
├── AppSettings.swift          # SlotCount (4/5/6), persisted
│
├── NDI/
│   ├── NDISource.swift            # unchanged from NDIMultiviewer
│   ├── NDIDiscoveryManager.swift  # unchanged from NDIMultiviewer
│   └── NDIVideoReceiver.swift     # video-only + kvmSupported flag + recvInstance exposed;
│                                   # pushes frames via `onFrame` closure, NOT an @Observable
│                                   # property — see note below
│
├── Wall/
│   └── WallLayout.swift       # WallSlot (video receiver + control channel + KVM state)
│                               # + WallLayout (slots array, activate/deactivateKVM, persistence)
│
├── KVM/
│   ├── NDIKVMSender.swift      # native transport: NDIlib_recv_kvm_* wrappers
│   ├── KeySymMapping.swift     # macOS NSEvent -> X11 keysym, for the native transport only
│   ├── NDIControlChannel.swift # relay transport: metadata-only NDI receive connection
│   └── KVMWireFormat.swift     # relay transport: our own protocol encoder
│
└── Views/
    ├── WallGridView.swift          # equal-size grid, sized from settings.slotCount
    ├── WallTileView.swift          # picks native vs relay transport, builds the context menu
    ├── KVMVideoView.swift          # NSViewRepresentable: displays video + captures input
    ├── KVMContextMenuBuilder.swift # native NSMenu — see note below
    └── SettingsView.swift          # just the slot-count picker + a KVM explainer
```

---

## Two non-obvious fixes baked into the current design

**Video frames bypass SwiftUI's `@Observable` entirely.** Early versions stored the current
frame as `@Observable var currentImage: CGImage?` and read it from the view body. At 30-60fps
that forced the whole tile's SwiftUI body — including its context menu — to re-evaluate that
often, which was enough to make the native NSMenu flicker open/closed and occasionally
misfire a click. Fixed by having `NDIVideoReceiver.onFrame` push frames directly to the
NSView's `CALayer` via a plain closure, never touching an `@Observable` property.

**The context menu is a native `NSMenu`, not SwiftUI's `.contextMenu`.** Even after the above
fix, a SwiftUI `.contextMenu` attached to the same view tree as the video-hosting
`NSViewRepresentable` intercepts right-clicks at the SwiftUI level and prevents them reaching
the embedded `NSView` — visible as "no menu ever opens" once a tile has a source assigned.
`WallTileView` only uses `.contextMenu` for the empty placeholder (no source assigned yet,
nothing redrawing underneath); once a tile has a receiver, `KVMSurfaceNSView.menu(for:)`
supplies the menu instead (`KVMContextMenuBuilder`).

---

## Known gaps / next steps

- Keyboard coverage on the relay (Mac) transport passes raw keycodes/modifiers faithfully
  (better than the native transport's X11-keysym "basic set"), but the native transport's
  `KeySymMapping` only covers letters/digits/punctuation/arrows/F-keys — no dead keys, no
  IME, no modifier-only combos beyond what a plain character carries.
- `SlotCount` tops out at 6.
- No drag-and-drop source assignment (unlike NDIMultiviewer) — right-click → Assign Source /
  Assign KVM Control only, kept deliberately minimal for this app's single job.
