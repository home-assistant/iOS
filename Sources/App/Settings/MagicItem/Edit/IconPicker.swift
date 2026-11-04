import SFSafeSymbols
import Shared
import SwiftUI

struct IconPicker: View {
    /// How the trigger renders in its host view: the original standalone circle badge, or a plain
    /// form row (title left, current icon + chevron right) for hosts that are a `Form`/`List`.
    enum Style {
        case circle
        case row(title: String)
    }

    @State private var showList = false
    @State private var searchTerm = ""
    @Binding private var selectedIcon: MaterialDesignIcons?
    @Binding private var selectedColor: Color
    private let style: Style

    private var icons = MaterialDesignIcons.allCases.sorted(by: { lhs, rhs in
        lhs.name < rhs.name
    })

    init(
        selectedIcon: Binding<MaterialDesignIcons?>,
        selectedColor: Binding<Color>,
        style: Style = .circle
    ) {
        self._selectedIcon = selectedIcon
        self._selectedColor = selectedColor
        self.style = style
    }

    var body: some View {
        Button(action: {
            showList = true
        }, label: {
            switch style {
            case .circle:
                circleLabel
            case let .row(title):
                rowLabel(title: title)
            }
        })
        .buttonStyle(.plain)
        .sheet(isPresented: $showList) {
            NavigationView {
                List {
                    ForEach(icons.filter({ icon in
                        if searchTerm.count < 2 {
                            return true
                        } else {
                            return icon.name.lowercased().contains(searchTerm.lowercased())
                        }
                    }), id: \.self) { icon in
                        Button(action: {
                            selectedIcon = icon
                            showList = false
                        }, label: {
                            IconPickerRow(icon: icon)
                        })
                        .tint(.accentColor)
                    }
                }
                .searchable(text: $searchTerm)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        CloseButton {
                            showList = false
                        }
                    }
                }
            }
        }
    }

    private var circleLabel: some View {
        ZStack(alignment: .bottomTrailing) {
            ZStack {
                Circle()
                    .frame(width: 50, height: 50)
                    .foregroundStyle(selectedColor.opacity(0.3))
                Image(uiImage: (selectedIcon ?? .gridIcon).image(
                    ofSize: .init(width: 30, height: 30),
                    color: UIColor(selectedColor)
                ))
            }
            Image(systemSymbol: .arrow2Squarepath)
                .resizable()
                .foregroundColor(Color(uiColor: .label))
                .aspectRatio(contentMode: .fit)
                .frame(width: 13, height: 13)
                .padding(4)
                .background(Color(uiColor: .systemBackground).opacity(0.9))
                .clipShape(Circle())
                .shadow(radius: 10)
        }
    }

    private func rowLabel(title: String) -> some View {
        HStack(spacing: DesignSystem.Spaces.two) {
            Text(verbatim: title)
                .foregroundStyle(Color(uiColor: .label))
            Spacer()
            Image(uiImage: (selectedIcon ?? .gridIcon).image(
                ofSize: .init(width: 24, height: 24),
                color: UIColor(selectedColor)
            ))
            Image(systemSymbol: .chevronRight)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
    }
}

struct IconPickerRow: View {
    @State private var showIcon = false
    var icon: MaterialDesignIcons

    var body: some View {
        HStack(spacing: DesignSystem.Spaces.two) {
            HStack {
                if showIcon {
                    Image(uiImage: icon.image(
                        ofSize: .init(width: 30, height: 30),
                        color: .haPrimary
                    ))
                    .frame(alignment: .leading)
                }
            }
            .frame(width: 30, height: 30)
            Text(icon.name)
                .foregroundStyle(Color(uiColor: .label))
        }
        .onAppear {
            showIcon = true
        }
    }
}

#Preview {
    IconPicker(selectedIcon: .constant(.abTestingIcon), selectedColor: .constant(.red))
}

#Preview("Row style") {
    List {
        IconPicker(
            selectedIcon: .constant(.abTestingIcon),
            selectedColor: .constant(.red),
            style: .row(title: "Icon")
        )
    }
}
