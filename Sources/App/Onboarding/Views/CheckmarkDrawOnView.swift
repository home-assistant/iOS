import SwiftUI

struct CheckmarkDrawOnView: View {
    @State private var isActive = true
    var body: some View {
        VStack {
            Spacer()
            Image(systemSymbol: .checkmarkCircle)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: .infinity)
                .frame(height: 150)
                .foregroundStyle(.haPrimary)
                .modify({ view in
                    if #available(iOS 26.0, *) {
                        view
                            .symbolEffect(.drawOn.individually, options: .speed(0.7), isActive: isActive)
                            .sensoryFeedback(.success, trigger: isActive)
                    } else {
                        view
                    }
                })
            Spacer()
        }
        .onAppear {
            isActive = false
        }
    }
}

#Preview {
    CheckmarkDrawOnView()
}
