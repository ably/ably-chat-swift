import SwiftUI

// UIKit blur view for SwiftUI
#if os(iOS)
    struct BlurView: UIViewRepresentable {
        let style: UIBlurEffect.Style
        func makeUIView(context _: Context) -> UIVisualEffectView {
            UIVisualEffectView(effect: UIBlurEffect(style: style))
        }

        func updateUIView(_: UIVisualEffectView, context _: Context) {}
    }

#elseif os(macOS)
    struct BlurView: NSViewRepresentable {
        let material: NSVisualEffectView.Material
        let blendingMode: NSVisualEffectView.BlendingMode

        func makeNSView(context _: Context) -> NSVisualEffectView {
            let view = NSVisualEffectView()
            view.material = material
            view.blendingMode = blendingMode
            view.state = .active
            return view
        }

        func updateNSView(_: NSVisualEffectView, context _: Context) {}
    }
#endif
