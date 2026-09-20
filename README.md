# NDI KVM Wall

A macOS video wall for NDI sources where clicking into a tile gives you live
keyboard/mouse control of that machine — click a PC or Mac's tile, drive it
directly, click away (or press Esc) to let go.

Two apps:

- **[NDIKVMWall](NDIKVMWall)** — the controller. Shows 4–6 NDI sources as
  equal-size tiles. Click into a tile to take control of that machine.
- **[NDIKVMHelper](NDIKVMHelper)** — a tiny menu-bar-only app you run on any
  **Mac** you want to control. Only needed for Macs — Windows machines
  running NDI Screen Capture with its "KVM Control" option enabled work with
  NDIKVMWall directly, no helper required.

## Why two control paths?

NDI's Advanced SDK has a real, first-class KVM feature
(`NDIlib_recv_kvm_send_keyboard_press` and friends) — but it's
**receive-only**: NDI never published a corresponding sender-side API, and
their own macOS "NDI Scan Converter" tool never implemented it (unlike
Windows' "NDI Screen Capture", which has it built in). So:

- **Windows targets**: NDIKVMWall talks to NDI Screen Capture directly using
  NDI's own official KVM feature (Advanced SDK).
- **Mac targets**: since there's no official way to receive those commands,
  NDIKVMHelper *is* the missing sender side — a from-scratch implementation
  using our own compact wire protocol (carried over the free, standard SDK's
  `NDIlib_recv_send_metadata` / `NDIlib_send_capture`, nothing exotic), which
  injects the resulting keyboard/mouse events locally via `CGEvent`.

Video for Macs still comes from NDI's own free "NDI Scan Converter" —
NDIKVMHelper only supplies the missing control channel, advertised as a
second, lightweight NDI source alongside it.

## Requirements

Both apps need NDI's official SDKs, which are **not included in this repo**
(their license doesn't permit redistribution — see below) — download them
yourself, they're free:

| App | Needs | Get it from |
|---|---|---|
| NDIKVMWall | **NDI Advanced SDK** for Apple | [ndi.video/for-developers/ndi-advanced](https://ndi.video/for-developers/ndi-advanced/) — free for personal/development use; a paid commercial license is required only if you intend to redistribute a built copy of NDIKVMWall yourself |
| NDIKVMHelper | **NDI SDK** for Apple (standard, free) | [ndi.video/for-developers](https://ndi.video/for-developers/) |

Install both to their default location (`/Library/NDI SDK for Apple` and
`/Library/NDI Advanced SDK for Apple`) — the Xcode projects' header/library
search paths point there directly.

You'll also need Xcode (26+) and a Mac running macOS 26.5+.

## Building

```bash
# Controller app
cd NDIKVMWall
xcodebuild -project NDIKVMWall.xcodeproj -scheme NDIKVMWall -configuration Release build

# Helper app (build once, copy to every Mac you want to control)
cd ../NDIKVMHelper
xcodebuild -project NDIKVMHelper.xcodeproj -scheme NDIKVMHelper -configuration Release build
```

Or just open either `.xcodeproj` in Xcode and hit Run.

## Setting up a Mac as a KVM target

1. Run NDI Scan Converter on that Mac (for video) — free, from NDI Tools.
2. Copy `NDIKVMHelper.app` onto that Mac and launch it. It's a menu-bar-only
   app (no Dock icon) — look for the keyboard icon in the menu bar.
3. Click the icon → "Grant Accessibility Access…" → approve in System
   Settings → **quit and relaunch NDIKVMHelper** (it needs a fresh process
   after the grant takes effect).
4. Back in NDIKVMWall: right-click that Mac's tile → **Assign Source** (pick
   its Scan Converter feed) → **Assign KVM Control** (pick its
   `(KVM Helper)` source). Both are separate pairings — video and control
   are two independent NDI sources.

## Setting up a Windows PC as a KVM target

1. Run NDI Screen Capture on that PC (from NDI Tools) with its **KVM
   Control** option enabled.
2. In NDIKVMWall, right-click its tile → Assign Source. That's it — no
   helper, no separate control pairing. The cyan border and "click to
   drive it" behavior work immediately.

## License

The code in this repository is MIT-licensed — see [LICENSE](LICENSE).

**NDI®** is a registered trademark of Vizrt NDI AB. The NDI SDK and NDI
Advanced SDK are Vizrt's own software, under their own license terms, and
are not part of this repository — you obtain them directly from
[ndi.video](https://ndi.video). In particular, the NDI Advanced SDK's
license does not permit redistributing its binaries (including inside a
built copy of NDIKVMWall) without a separate commercial agreement with
Vizrt — build it yourself from source instead of distributing compiled
binaries of NDIKVMWall.
