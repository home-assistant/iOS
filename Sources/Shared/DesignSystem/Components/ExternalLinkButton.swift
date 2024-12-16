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
                    .tint(Color(uiColor: .label))
                    .font(.body.bold())
            }
        }
        .frame(maxWidth: 600)
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    ExternalLinkButton(
        icon: Image(systemName: "xmark"),
        title: "Go there",
        url: URL(string: "https://google.com")!,
        tint: .blue
    )
}
