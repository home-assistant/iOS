#if !os(watchOS)
import HAIconic
import SFSafeSymbols
import SwiftUI

/// A button that opens a URL outside the app, marked with an open-in-new glyph.
///
/// Frontend counterpart: none as a single element — the frontend writes an `ha-button` with
/// `mdiOpenInNew` at each call site. This is that composition, named.
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
            HStack(spacing: DesignSystem.Spaces.two) {
                icon
                    .frame(width: 30, height: 30)
                    .font(.title2)
                    .foregroundStyle(tint)
                Text(title)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .multilineTextAlignment(.leading)
                    .foregroundStyle(Color(uiColor: .label))
                    .font(.body.bold())
            }
        }
        // The row draws its own background below; without this Mac Catalyst adds the bordered
        // button style's background on top of it, so every row shows two stacked backgrounds.
        .buttonStyle(.plain)
        .frame(maxWidth: 600)
        .padding()
        .background(background)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.oneAndHalf))
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
            HStack(spacing: DesignSystem.Spaces.two) {
                icon
                    .frame(width: 30, height: 30)
                    .font(.title2)
                    .foregroundStyle(tint)
                Text(title)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .multilineTextAlignment(.leading)
                    .foregroundStyle(Color(uiColor: .label))
                    .font(.body.bold())
            }
        })
        // The row draws its own background below; without this Mac Catalyst adds the bordered
        // button style's background on top of it, so every row shows two stacked backgrounds.
        .buttonStyle(.plain)
        .frame(maxWidth: 600)
        .padding()
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.oneAndHalf))
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
#endif
