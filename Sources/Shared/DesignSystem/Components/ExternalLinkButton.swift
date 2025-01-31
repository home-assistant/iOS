import SwiftUI

public struct ExternalLinkButton: View {
    let icon: Image
    let title: String
    let url: URL
    let tint: Color

    public init(icon: Image, title: String, url: URL, tint: Color) {
        self.icon = icon
        self.title = title
        self.url = url
        self.tint = tint
    }

    public var body: some View {
        Link(destination: url) {
            HStack(spacing: Spaces.two) {
                icon
                    .frame(width: 30, height: 30)
                    .font(.title2)
                    .tint(tint)
                Text(title)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .multilineTextAlignment(.leading)
                    .tint(Color(uiColor: .label))
                    .font(.body.bold())
            }
        }
        .frame(maxWidth: 600)
        .padding()
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

public struct ActionLinkButton: View {
    let icon: Image
    let title: String
    let tint: Color
    let action: () -> Void

    public init(icon: Image, title: String, tint: Color, action: @escaping () -> Void) {
        self.icon = icon
        self.title = title
        self.tint = tint
        self.action = action
    }

    public var body: some View {
        Button(action: {
            action()
        }, label: {
            HStack(spacing: Spaces.two) {
                icon
                    .frame(width: 30, height: 30)
                    .font(.title2)
                    .tint(tint)
                Text(title)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .multilineTextAlignment(.leading)
                    .tint(Color(uiColor: .label))
                    .font(.body.bold())
            }
        })
        .frame(maxWidth: 600)
        .padding()
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    VStack {}
        .sheet(isPresented: .constant(true)) {
            VStack {
                ExternalLinkButton(
                    icon: Image(systemName: "xmark"),
                    title: "Go there",
                    url: URL(string: "https://google.com")!,
                    tint: .blue
                )
                ExternalLinkButton(
                    icon: Image(systemName: "xmark"),
                    title: "Go there",
                    url: URL(string: "https://google.com")!,
                    tint: .blue
                )
                .preferredColorScheme(.dark)
            }
        }
}
