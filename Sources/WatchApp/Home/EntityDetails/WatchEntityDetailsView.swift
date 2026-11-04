import HAKit
import SFSafeSymbols
import Shared
import SwiftUI

/// Read-only screen a sensor row opens when tapped: the current value, when the server last touched
/// it, and its attributes. Nothing here executes anything — sensors have no action to run.
struct WatchEntityDetailsView: View {
    @StateObject private var viewModel: WatchEntityDetailsViewModel
    @Environment(\.dismiss) private var dismiss

    init(viewModel: WatchEntityDetailsViewModel) {
        self._viewModel = .init(wrappedValue: viewModel)
    }

    var body: some View {
        NavigationView {
            List {
                Section {
                    VStack(spacing: DesignSystem.Spaces.half) {
                        Image(uiImage: viewModel.icon.image(
                            ofSize: .init(width: 24, height: 24),
                            color: viewModel.iconColor
                        ))
                        .watchRowIconContainer(color: viewModel.iconColor)
                        if let details = viewModel.details {
                            Text(verbatim: details.state)
                                .font(.title3.bold())
                                .multilineTextAlignment(.center)
                                .minimumScaleFactor(0.6)
                            if let deviceClass = details.deviceClass {
                                Text(verbatim: deviceClass)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        } else {
                            ProgressView()
                                .progressViewStyle(.circular)
                            Text(verbatim: L10n.Watch.EntityDetails.loading)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
                }
                if viewModel.isStale {
                    Label {
                        Text(verbatim: L10n.Watch.EntityDetails.stale)
                            .font(.caption2)
                    } icon: {
                        Image(systemSymbol: .exclamationmarkCircleFill)
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.black, .orange)
                    }
                }
                if let details = viewModel.details {
                    Section {
                        HStack {
                            Text(verbatim: L10n.Watch.EntityDetails.lastChanged)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text(details.lastChanged, style: .relative)
                                .foregroundStyle(.secondary)
                        }
                        HStack {
                            Text(verbatim: L10n.Watch.EntityDetails.lastUpdated)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text(details.lastUpdated, style: .relative)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .font(.caption)
                    if !details.attributes.isEmpty {
                        Section {
                            ForEach(details.attributes) { attribute in
                                VStack(alignment: .leading, spacing: .zero) {
                                    Text(verbatim: attribute.name)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                    Text(verbatim: attribute.value)
                                        .font(.caption)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        } header: {
                            Text(verbatim: L10n.Watch.EntityDetails.attributes)
                        } footer: {
                            Text(verbatim: details.entityId)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle(Text(verbatim: viewModel.name))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemSymbol: .xmark)
                    }
                }
            }
        }
        .onAppear {
            viewModel.startStateUpdates()
        }
        .onDisappear {
            viewModel.stopStateUpdates()
        }
    }
}

#Preview {
    MaterialDesignIcons.register()
    let item = MagicItem(id: "sensor.living_room_temperature", serverId: "1", type: .entity)
    let info = MagicItem.Info(
        id: "1-sensor.living_room_temperature",
        name: "Living room temperature",
        iconName: "mdi:thermometer"
    )
    let entity = try? HAEntity(
        entityId: "sensor.living_room_temperature",
        state: "21.4",
        lastChanged: Date(timeIntervalSinceNow: -600),
        lastUpdated: Date(timeIntervalSinceNow: -60),
        attributes: [
            "friendly_name": "Living room temperature",
            "unit_of_measurement": "°C",
            "device_class": "temperature",
            "state_class": "measurement",
        ],
        context: .init(id: "", userId: "", parentId: "")
    )
    return WatchEntityDetailsView(viewModel: .init(item: item, itemInfo: info, initialEntity: entity))
}
