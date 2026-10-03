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
                model.screen
                    .frame(width: model.size?.width, height: model.size?.height)
                    .environment(\.isPresentedInMacSheet, true)
                    .background(ViewControllerResolver(onResolve: onResolveContentController))
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
