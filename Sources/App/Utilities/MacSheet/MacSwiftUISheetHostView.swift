#if os(macOS)
import Shared
import SwiftUI

/// An invisible view whose only job is to present a screen in a SwiftUI sheet on the window it sits in.
struct MacSwiftUISheetHostView: View {
    @ObservedObject var model: MacSwiftUISheetModel
    /// Reports the controller SwiftUI hosts the screen in, which is the one further sheets belong on.
    let onResolveContentController: (NSViewController) -> Void

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .sheet(isPresented: $model.isPresented, onDismiss: { model.onDismiss?() }) {
                sizedScreen
                    .environment(\.isPresentedInMacSheet, true)
                    .background(ViewControllerResolver(onResolve: onResolveContentController))
            }
    }

    @ViewBuilder
    private var sizedScreen: some View {
        if let size = model.size {
            model.screen
                .frame(width: size.width, height: size.height)
        } else {
            model.screen
        }
    }
}

#Preview {
    MacSwiftUISheetHostView(
        model: .init(screen: AnyView(Text(verbatim: "Screen")), size: .init(width: 320, height: 200)),
        onResolveContentController: { _ in }
    )
}
#endif
