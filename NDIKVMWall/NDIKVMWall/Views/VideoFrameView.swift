import SwiftUI
import AppKit

struct VideoFrameView: NSViewRepresentable {
    let image: CGImage?

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        view.wantsLayer = true
        view.layer?.backgroundColor = CGColor(gray: 0.05, alpha: 1)
        view.layer?.contentsGravity = .resizeAspect
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        nsView.layer?.contents = image
    }
}
