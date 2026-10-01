import SwiftUI

#if os(macOS)
/// Offers the items to the Mac's sharing services. The picker opens as soon as the view is on screen and
/// the presentation that showed this view is dismissed once the picker closes, so presenting it in a
/// sheet behaves like the share sheet does on iOS.
struct ShareActivityView: NSViewRepresentable {
    var activityItems: [Any]

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSView {
        let view = AnchorView()
        view.onMoveToWindow = { [activityItems, coordinator = context.coordinator] view in
            coordinator.showPicker(items: activityItems, from: view)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        let dismiss = context.environment.dismiss
        context.coordinator.onFinish = { dismiss() }
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView: NSView, context: Context) -> CGSize? {
        CGSize(width: 1, height: 1)
    }

    /// The view the picker is anchored to. It draws nothing.
    private final class AnchorView: NSView {
        var onMoveToWindow: ((NSView) -> Void)?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard window != nil else { return }
            onMoveToWindow?(self)
        }
    }

    final class Coordinator: NSObject, NSSharingServicePickerDelegate {
        var onFinish: (() -> Void)?
        private var picker: NSSharingServicePicker?

        func showPicker(items: [Any], from view: NSView) {
            guard picker == nil else { return }
            let picker = NSSharingServicePicker(items: items)
            picker.delegate = self
            self.picker = picker
            // The window is still being presented when the view joins it, so wait for the next pass of
            // the run loop before anchoring the picker to it.
            DispatchQueue.main.async { [weak view] in
                guard let view, view.window != nil else { return }
                picker.show(relativeTo: view.bounds, of: view, preferredEdge: .minY)
            }
        }

        func sharingServicePicker(
            _ sharingServicePicker: NSSharingServicePicker,
            didChoose service: NSSharingService?
        ) {
            // Called with nil when the picker closes without a choice; either way the picker is done.
            onFinish?()
        }
    }
}
#else
struct ShareActivityView: UIViewControllerRepresentable {
    var activityItems: [Any]
    var applicationActivities: [UIActivity]? = nil

    func makeUIViewController(context: UIViewControllerRepresentableContext<ShareActivityView>)
        -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: applicationActivities
        )
        return controller
    }

    func updateUIViewController(
        _ uiViewController: UIActivityViewController,
        context: UIViewControllerRepresentableContext<ShareActivityView>
    ) {}
}
#endif

#Preview {
    ShareActivityView(activityItems: ["Home Assistant"])
}
