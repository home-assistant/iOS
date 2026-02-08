import HAKit
import SFSafeSymbols
import Shared
import SwiftUI

@available(iOS 26.0, *)
struct EditRoomEntitiesView: View {
    let visibleEntities: [HAEntity]
    let hiddenEntities: [HAEntity]
    let onHideEntity: (String) -> Void
    let onUnhideEntity: (String) -> Void
    let onReorderEntities: ([String]) -> Void
    let onDismiss: () -> Void

    @State private var reorderedVisibleEntities: [HAEntity] = []
    @State private var hasReordered = false

    var body: some View {
        NavigationStack {
            List {
                if !reorderedVisibleEntities.isEmpty {
                    Section {
                        ForEach(reorderedVisibleEntities, id: \.entityId) { entity in
                            entityRow(entity: entity, isHidden: false)
                        }
                        .onMove { fromOffsets, toOffset in
                            reorderedVisibleEntities.move(fromOffsets: fromOffsets, toOffset: toOffset)
                            hasReordered = true
                        }
                    } header: {
                        HStack {
                            Text("Visible Entities")
                            Spacer()
                            Text("Drag to reorder")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } footer: {
                        if hasReordered {
                            Text("Changes will be saved when you tap Done")
                                .font(.caption)
                                .foregroundStyle(.blue)
                        }
                    }
                }

                if !hiddenEntities.isEmpty {
                    Section {
                        ForEach(hiddenEntities, id: \.entityId) { entity in
                            entityRow(entity: entity, isHidden: true)
                        }
                    } header: {
                        Text("Hidden Entities")
                    }
                }
            }
            .navigationTitle("Edit Entities")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    EditButton()
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        if hasReordered {
                            onReorderEntities(reorderedVisibleEntities.map(\.entityId))
                        }
                        onDismiss()
                    }
                }
            }
            .onAppear {
                reorderedVisibleEntities = visibleEntities
            }
            .onChange(of: visibleEntities) { _, newValue in
                // Update the reordered list if the source changes
                if !hasReordered {
                    reorderedVisibleEntities = newValue
                }
            }
        }
    }

    @ViewBuilder
    private func entityRow(entity: HAEntity, isHidden: Bool) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: DesignSystem.Spaces.half) {
                Text(entity.attributes.friendlyName ?? entity.entityId)
                    .font(.body)
                Text(entity.entityId)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                if isHidden {
                    onUnhideEntity(entity.entityId)
                } else {
                    onHideEntity(entity.entityId)
                }
            } label: {
                Image(systemSymbol: isHidden ? .eye : .eyeSlash)
                    .foregroundStyle(isHidden ? .blue : .secondary)
                    .font(.title3)
            }
            .buttonStyle(.plain)
        }
        .opacity(isHidden ? 0.6 : 1.0)
    }
}

@available(iOS 26.0, *)
#Preview {
    EditRoomEntitiesView(
        visibleEntities: [],
        hiddenEntities: [],
        onHideEntity: { _ in },
        onUnhideEntity: { _ in },
        onReorderEntities: { _ in },
        onDismiss: {}
    )
}
