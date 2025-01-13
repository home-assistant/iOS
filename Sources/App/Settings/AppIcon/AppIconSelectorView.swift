import SFSafeSymbols
import Shared
import SwiftUI

struct AppIconSelectorView: View {
    static var controller = UIHostingController(rootView: AppIconSelectorView())
    struct IconImage {
        let id: String
        let icon: Image
    }

    @State private var selectedIcon: String = ""
    @State private var tintedIconPreviewColor: Color = .green
    @State private var timer: Timer?

    var body: some View {
        List {
            Text(L10n.SettingsDetails.General.AppIcon.Explanation.title)
                .font(.footnote)
            ForEach(AppIcon.allCases, id: \.self) { icon in
                makeRow(name: sectionNameForIcon(icon), icons: [
                    .init(id: UUID().uuidString, icon: .init("icon-\(icon.rawValue)")),
                    .init(id: UUID().uuidString, icon: .init(icon.darkIcon)),
                ], tag: icon.rawValue)
            }
        }
        .onAppear {
            selectedIcon = AppIcon.Release.rawValue
            if let altIconName = UIApplication.shared.alternateIconName,
               let icon = AppIcon(rawValue: altIconName) {
                selectedIcon = icon.rawValue
            }
            timerToReplaceTintedPeviewColorByRandomColor()
        }
        .navigationTitle("App Icon")
    }

    private func sectionNameForIcon(_ icon: AppIcon) -> String {
        var name = icon.title
        if icon.rawValue == selectedIcon {
            name += " \(L10n.SettingsDetails.General.AppIcon.CurrentSelected.title)"
        }
        return name
    }

    private func makeRow(name: String, icons: [IconImage], tag: String) -> some View {
        Section(name) {
            Button(action: {
                selectedIcon = tag
                UIApplication.shared.setAlternateIconName(tag) { error in
                    Current.Log
                        .info("set icon to \(String(describing: tag)) error: \(String(describing: error))")
                }
            }) {
                HStack {
                    Group {
                        ForEach(icons, id: \.id) { icon in
                            icon.icon
                                .resizable()
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        tintedIcon
                    }
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .frame(height: 64)
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
        }
    }

    private var tintedIcon: some View {
        ZStack {
            Rectangle()
                .foregroundStyle(tintedIconPreviewColor)
                .animation(.easeInOut, value: tintedIconPreviewColor)
            Image("icon-tinted-preview")
                .resizable()
        }
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func timerToReplaceTintedPeviewColorByRandomColor() {
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { _ in
            tintedIconPreviewColor = generateRandomColor()
        }
    }

    private func generateRandomColor() -> Color {
        let red = Double.random(in: 0 ... 1)
        let green = Double.random(in: 0 ... 1)
        let blue = Double.random(in: 0 ... 1)
        return Color(red: red, green: green, blue: blue)
    }
}

#Preview {
    NavigationView {
        AppIconSelectorView()
    }
}
