import SFSafeSymbols
import Shared
import SwiftUI

@available(iOS 16.0, *)
struct CameraSectionReorderView: View {
    @ObservedObject var viewModel: CameraListViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var sections: [String] = []

    var body: some View {
        NavigationView {
            List {
                ForEach(sections, id: \.self) { section in
                    HStack(spacing: DesignSystem.Spaces.two) {
                        Image(systemSymbol: .squareFill)
                            .font(.title3)
                            .foregroundStyle(.haPrimary)
                        Text(section)
                            .font(.body)
                    }
                    .padding(.vertical, DesignSystem.Spaces.half)
                }
                .onMove { source, destination in
                    sections.move(fromOffsets: source, toOffset: destination)
                }
            }
            .navigationTitle(L10n.CameraList.Reorder.Section.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    CloseButton {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L10n.saveLabel) {
                        viewModel.saveSectionOrder(sections)
                        dismiss()
                    }
                }
            }
            .environment(\.editMode, .constant(.active))
            .onAppear {
                sections = viewModel.groupedCameras.map(\.area)
            }
        }
    }
}
