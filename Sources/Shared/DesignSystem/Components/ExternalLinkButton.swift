import SFSafeSymbols
import SwiftUI

public struct ExternalLinkButton: View {
    let icon: Image
    let title: String
    let url: URL
    let tint: Color
    let background: Color

    public init(
        icon: Image = Image(uiImage: MaterialDesignIcons.openInNewIcon.image(
            ofSize: .init(width: 30, height: 30),
            color: nil
        )),
        title: String,
        url: URL,
        tint: Color? = nil,
        background: Color = Color(uiColor: .secondarySystemBackground)
    ) {
        self.icon = icon
        self.title = title
        self.url = url
        self.tint = tint ?? .haPrimary
        self.background = background
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
        .background(background)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadiusSizes.oneAndHalf))
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
        .clipShape(RoundedRectangle(cornerRadius: CornerRadiusSizes.oneAndHalf))
    }
}

#Preview {
    VStack {}
        .sheet(isPresented: .constant(true)) {
            VStack {
                ExternalLinkButton(
                    icon: Image(systemSymbol: .xmark),
                    title: "Go there",
                    url: URL(string: "https://google.com")!,
                    tint: .blue
                )
                ExternalLinkButton(
                    icon: Image(systemSymbol: .xmark),
                    title: "Go there",
                    url: URL(string: "https://google.com")!,
                    tint: .blue
                )
                .preferredColorScheme(.dark)
            }
        }
}
