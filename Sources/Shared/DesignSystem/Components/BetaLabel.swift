import SwiftUI

public struct BetaLabel: View {
    @Environment(\.openURL) private var openURL
    @State private var showInfo = false
    private let info: String?

    public init(info: String? = nil) {
        self.info = info
    }

    public var body: some View {
        HStack(spacing: .zero) {
            Text("BETA")
                .font(.caption2.bold())
                .padding(.horizontal, DesignSystem.Spaces.one)
            if info != nil {
                Image(systemSymbol: .infoCircle)
                    .resizable()
                    .frame(width: 15, height: 15, alignment: .trailing)
                    .padding(.trailing, DesignSystem.Spaces.half)
            }
        }
        .foregroundColor(.white)
        .padding(.vertical, DesignSystem.Spaces.half)
        .background(Color.orange)
        .clipShape(Capsule())
        .onTapGesture {
            guard info != nil else { return }
            showInfo = true
        }
        .sheet(isPresented: $showInfo) {
            if #available(iOS 16.0, *) {
                infoSheet
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            } else {
                infoSheet
            }
        }
    }

    private var infoSheet: some View {
        NavigationView {
            ScrollView {
                VStack {
                    Text(info ?? "")
                        .padding(DesignSystem.Spaces.two)
                    Spacer()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle("BETA")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                Button(action: {
                    openURL(AppConstants.WebURLs.issues)
                }, label: {
                    Text(L10n.Experimental.Badge.ReportIssueButton.title)
                })
                .buttonStyle(.primaryButton)
                .padding(.horizontal)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    CloseButton {
                        showInfo = false
                    }
                }
            }
        }
    }
}

#Preview("Without info") {
    BetaLabel()
}

#Preview("Info") {
    BetaLabel(
        info: "This is an information that can be linked to a beta label to describe what are the limitations and or the current state of the feature."
    )
}
