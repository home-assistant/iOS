import SwiftUI

#if os(macOS)
/// Follows whether the system lays the bars out in a vertical column, as on an unfolded iPhone. A Mac
/// never does, so the binding is left as it is.
struct VerticalBarObserver: View {
    @Binding var hasVerticalBar: Bool

    var body: some View {
        Color.clear
    }
}
#else
/// Follows whether the system lays the bars out in a vertical column, as on an unfolded iPhone.
struct VerticalBarObserver: UIViewControllerRepresentable {
    @Binding var hasVerticalBar: Bool

    func makeUIViewController(context: Context) -> VerticalBarObserverViewController {
        VerticalBarObserverViewController()
    }

    func updateUIViewController(_ controller: VerticalBarObserverViewController, context: Context) {
        controller.onChange = { value in
            DispatchQueue.main.async {
                hasVerticalBar = value
            }
        }
    }
}
#endif

#Preview {
    Text("Follows the bar layout")
        .background(VerticalBarObserver(hasVerticalBar: .constant(false)))
}
