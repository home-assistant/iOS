import SwiftUI
import Shared

struct ExperimentalBadge: View {
    @State private var showExplanation = false
    var body: some View {
        Button(action: {
            showExplanation = true
        }, label: {
            HStack {
                Text(L10n.Experimental.Badge.title)
                    .font(.caption.bold())
                Image(systemSymbol: .questionmarkCircle)
                    .font(.caption)
            }
            .foregroundStyle(.white)
            .padding(.vertical, DesignSystem.Spaces.one)
            .padding(.horizontal, DesignSystem.Spaces.oneAndHalf)
            .background(.yellow)
            .clipShape(.capsule)
        })
        .buttonStyle(.plain)
        .sheet(isPresented: $showExplanation) {
            NavigationView {
                VStack(spacing: DesignSystem.Spaces.two) {
                    Spacer()
                    Image(systemSymbol: .testtube2)
                        .resizable()
                        .frame(width: 100, height: 100)
                        .aspectRatio(contentMode: .fit)
                        .foregroundStyle(.yellow)
                    Text(L10n.Experimental.Badge.body)
                        .padding()
                        .multilineTextAlignment(.center)
                    Spacer()
                }
                .navigationTitle(L10n.Experimental.Badge.title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        CloseButton {
                            showExplanation = false
                        }
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button(action: {
                    URLOpener.shared.open(AppConstants.WebURLs.issues, options: [:], completionHandler: nil)
                }, label: {
                    Text(L10n.Experimental.Badge.ReportIssueButton.title)
                })
                .buttonStyle(.primaryButton)
                .padding(.horizontal)
            }
            .modify { view in
                if #available(iOS 16.0, *) {
                    view
                        .presentationDetents([.medium, .large])
                } else {
                    view
                }
            }
        }
    }
}

#Preview {
    NavigationView {
        List {
            ExperimentalBadge()
        }
    }
}
