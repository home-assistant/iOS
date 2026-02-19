import SwiftUI

@available(iOS 26.0, *)
struct EditModeIndicatorModifier: ViewModifier {
    let isEditing: Bool
    let isDragging: Bool
    @State private var scale: CGFloat = 1.0

    func body(content: Content) -> some View {
        content
            .scaleEffect(isDragging ? 1.05 : scale)
            .opacity(isDragging ? 0.6 : 1.0)
            .shadow(
                color: isEditing ? .blue.opacity(0.3) : .clear,
                radius: isDragging ? 12 : 6,
                x: 0,
                y: isDragging ? 4 : 2
            )
            .overlay {
                if isEditing, !isDragging {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.blue.opacity(0.4), lineWidth: 2)
                        .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: scale)
                }
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isDragging)
            .onAppear {
                if isEditing {
                    withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                        scale = 1.02
                    }
                }
            }
            .onChange(of: isEditing) { _, newValue in
                if newValue {
                    withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                        scale = 1.02
                    }
                } else {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        scale = 1.0
                    }
                }
            }
    }
}
