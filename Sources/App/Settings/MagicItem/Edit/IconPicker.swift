import SFSafeSymbols
import Shared
import SwiftUI

struct IconPicker: View {
    @State private var showList = false
    @State private var searchTerm = ""
    @Binding private var selectedIcon: MaterialDesignIcons?
    @Binding private var selectedColor: Color

    private var icons = MaterialDesignIcons.allCases.sorted(by: { lhs, rhs in
        lhs.name < rhs.name
    })

    init(
        selectedIcon: Binding<MaterialDesignIcons?>,
        selectedColor: Binding<Color>
    ) {
        self._selectedIcon = selectedIcon
        self._selectedColor = selectedColor
    }

    var body: some View {
        Button(action: {
            showList = true
        }, label: {
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
}

struct IconPickerRow: View {
    @State private var showIcon = false
    var icon: MaterialDesignIcons

    var body: some View {
        HStack(spacing: Spaces.two) {
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
