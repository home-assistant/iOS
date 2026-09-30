import SwiftUI
import UIKit

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

#Preview {
    Text("Follows the bar layout")
        .background(VerticalBarObserver(hasVerticalBar: .constant(false)))
}
