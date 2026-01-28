import Shared
import SwiftUI

struct GesturesSetupView: View {
    @StateObject private var viewModel = GesturesSetupViewModel()
    @State private var swipeRightState = HAGestureAction.showSidebar
    @State private var showResetConfirmation = false

    @State var directions: [UISwipeGestureRecognizer.Direction] = [
        .left, .right, .up,
    ]

    var body: some View {
        List {
            AppleLikeListTopRowHeader(
                image: .gestureIcon,
                title: L10n.Gestures.Screen.title,
                subtitle: L10n.Gestures.Screen.body
            )

            Section {
                ForEach(
                    AppGesture.allCases.filter({ $0.direction == nil })
                        .sorted(by: { $0.setupScreenOrder < $1.setupScreenOrder }),
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

            ForEach(directions, id: \.rawValue) { direction in
                Section(title(for: direction)) {
                    ForEach(
                        AppGesture.allCases.filter({ $0.direction == direction })
                            .sorted(by: { $0.setupScreenOrder < $1.setupScreenOrder }),
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
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(role: .destructive) {
                    showResetConfirmation = true
                } label: {
                    Text(L10n.Gestures.Reset.title)
                }
                .confirmationDialog(
                    L10n.Gestures.Reset.Confirmation.title,
                    isPresented: $showResetConfirmation,
                    titleVisibility: .visible
                ) {
                    Button(L10n.yesLabel, role: .destructive) {
                        viewModel.resetGestures()
                    }
                    Button(L10n.noLabel, role: .cancel) {}
                } message: {
                    Text(L10n.Gestures.Reset.Confirmation.message)
                }
            }
        }
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

    private func title(for direction: UISwipeGestureRecognizer.Direction) -> String {
        switch direction {
        case .up:
            return L10n.Gestures.Swipe.Up.header
        case .down:
            return L10n.Gestures.Swipe.Down.header
        case .left:
            return L10n.Gestures.Swipe.Left.header
        case .right:
            return L10n.Gestures.Swipe.Right.header
        default:
            return ""
        }
    }
}

#Preview {
    NavigationView {
        GesturesSetupView()
    }
}
