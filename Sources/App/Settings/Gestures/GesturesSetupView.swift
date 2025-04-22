import Shared
import SwiftUI

struct GesturesSetupView: View {
    @StateObject private var viewModel = GesturesSetupViewModel()
    @State private var swipeRightState = HAGestureAction.showSidebar
    var body: some View {
        List {
            AppleLikeListTopRowHeader(
                image: .gestureIcon,
                title: L10n.Gestures.Screen.title,
                subtitle: L10n.Gestures.Screen.body
            )
            Section {
                ForEach(
                    AppGesture.allCases.sorted(by: { $0.setupScreenOrder < $1.setupScreenOrder }),
                    id: \.self
                ) { gesture in
                    let selection = viewModel.selection(for: gesture)
                    ListPicker(
                        title: gesture.localizedString,
                        selection: .init(get: {
                            .init(id: selection.rawValue, title: selection.localizedString)
                        }, set: { selectedItem in
                            guard let newValue = HAGestureAction(rawValue: selectedItem.id) else {
                                return
                            }
                            viewModel.setSelection(for: gesture, newValue: newValue)
                        }),
                        content: gestureActionsPickerContent
                    )
                }
            }
        }
        .removeListsPaddingWithAppleLikeHeader()
    }

    private var gestureActionsPickerContent: ListPickerContent {
        var sections: [ListPickerContent.Section] = []
        for category in HAGestureActionCategory.allCases {
            let items = HAGestureAction.allCases.filter({ $0.category == category }).map { action in
                ListPickerContent.Item(id: action.rawValue, title: action.localizedString)
            }
            sections.append(.init(id: category.rawValue, title: category.localizedString, items: items))
        }
        return .init(sections: sections)
    }

    private func makeRow(gestureAction: HAGestureAction) -> some View {
        Text(gestureAction.localizedString).tag(gestureAction)
    }
}

#Preview {
    NavigationView {
        GesturesSetupView()
    }
}
