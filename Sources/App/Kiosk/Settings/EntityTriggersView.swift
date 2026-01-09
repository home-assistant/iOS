import Shared
import SwiftUI

// MARK: - Entity Triggers View

/// View for configuring HA entity triggers for wake/sleep and actions
public struct EntityTriggersView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var wakeEntities: [EntityTrigger]
    @Binding var sleepEntities: [EntityTrigger]
    @Binding var actionTriggers: [EntityActionTrigger]

    @State private var showAddWake = false
    @State private var showAddSleep = false
    @State private var showAddAction = false

    public init(
        wakeEntities: Binding<[EntityTrigger]>,
        sleepEntities: Binding<[EntityTrigger]>,
        actionTriggers: Binding<[EntityActionTrigger]>
    ) {
        _wakeEntities = wakeEntities
        _sleepEntities = sleepEntities
        _actionTriggers = actionTriggers
    }

    public var body: some View {
        NavigationView {
            Form {
                wakeSection
                sleepSection
                actionSection
            }
            .navigationTitle("Entity Triggers")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showAddWake) {
                EntityTriggerEditView(
                    title: "Add Wake Trigger",
                    onSave: { trigger in
                        wakeEntities.append(trigger)
                    }
                )
            }
            .sheet(isPresented: $showAddSleep) {
                EntityTriggerEditView(
                    title: "Add Sleep Trigger",
                    onSave: { trigger in
                        sleepEntities.append(trigger)
                    }
                )
            }
            .sheet(isPresented: $showAddAction) {
                EntityActionTriggerEditView(
                    onSave: { trigger in
                        actionTriggers.append(trigger)
                    }
                )
            }
        }
    }

    // MARK: - Wake Section

    private var wakeSection: some View {
        Section {
            ForEach($wakeEntities) { $trigger in
                EntityTriggerRow(trigger: $trigger)
            }
            .onDelete { offsets in
                wakeEntities.remove(atOffsets: offsets)
            }

            Button {
                showAddWake = true
            } label: {
                Label("Add Wake Trigger", systemImage: "plus.circle")
            }
        } header: {
            Text("Wake Triggers")
        } footer: {
            Text("Entities that will wake the display when their state changes to the trigger value.")
        }
    }

    // MARK: - Sleep Section

    private var sleepSection: some View {
        Section {
            ForEach($sleepEntities) { $trigger in
                EntityTriggerRow(trigger: $trigger)
            }
            .onDelete { offsets in
                sleepEntities.remove(atOffsets: offsets)
            }

            Button {
                showAddSleep = true
            } label: {
                Label("Add Sleep Trigger", systemImage: "plus.circle")
            }
        } header: {
            Text("Sleep Triggers")
        } footer: {
            Text("Entities that will activate the screensaver when their state changes to the trigger value.")
        }
    }

    // MARK: - Action Section

    private var actionSection: some View {
        Section {
            ForEach($actionTriggers) { $trigger in
                EntityActionTriggerRow(trigger: $trigger)
            }
            .onDelete { offsets in
                actionTriggers.remove(atOffsets: offsets)
            }

            Button {
                showAddAction = true
            } label: {
                Label("Add Action Trigger", systemImage: "plus.circle")
            }
        } header: {
            Text("Action Triggers")
        } footer: {
            Text("Entities that trigger specific actions like navigation or brightness changes.")
        }
    }
}

// MARK: - Entity Trigger Row

struct EntityTriggerRow: View {
    @Binding var trigger: EntityTrigger

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(trigger.entityId)
                .font(.headline)

            HStack {
                Text("State:")
                    .foregroundColor(.secondary)
                Text(trigger.triggerState)
                    .foregroundColor(.accentColor)
            }
            .font(.caption)
        }
    }
}

// MARK: - Entity Action Trigger Row

struct EntityActionTriggerRow: View {
    @Binding var trigger: EntityActionTrigger

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(trigger.entityId)
                .font(.headline)

            HStack {
                Text("State:")
                    .foregroundColor(.secondary)
                Text(trigger.triggerState)

                Spacer()

                Text("Action:")
                    .foregroundColor(.secondary)
                Text(trigger.action.displayName)
            }
            .font(.caption)
        }
    }
}

// MARK: - Entity Trigger Edit View

struct EntityTriggerEditView: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    let onSave: (EntityTrigger) -> Void

    @State private var entityId = ""
    @State private var triggerState = "on"

    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("Entity ID", text: $entityId)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()

                    TextField("Trigger State", text: $triggerState)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                } footer: {
                    Text("Enter the entity ID (e.g., binary_sensor.motion) and the state that triggers the action (e.g., on, off, home).")
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let trigger = EntityTrigger(
                            entityId: entityId,
                            triggerState: triggerState
                        )
                        onSave(trigger)
                        dismiss()
                    }
                    .disabled(entityId.isEmpty)
                }
            }
        }
    }
}

// MARK: - Entity Action Trigger Edit View

struct EntityActionTriggerEditView: View {
    @Environment(\.dismiss) private var dismiss
    let onSave: (EntityActionTrigger) -> Void

    @State private var entityId = ""
    @State private var triggerState = "on"
    @State private var selectedActionType = ActionType.navigate
    @State private var urlValue = ""
    @State private var brightnessValue: Float = 1.0
    @State private var messageValue = ""

    enum ActionType: String, CaseIterable {
        case navigate = "Navigate"
        case setBrightness = "Set Brightness"
        case startScreensaver = "Start Screensaver"
        case stopScreensaver = "Stop Screensaver"
        case refresh = "Refresh"
        case playSound = "Play Sound"
        case tts = "TTS"
    }

    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("Entity ID", text: $entityId)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()

                    TextField("Trigger State", text: $triggerState)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                } header: {
                    Text("Trigger")
                }

                Section {
                    Picker("Action Type", selection: $selectedActionType) {
                        ForEach(ActionType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }

                    switch selectedActionType {
                    case .navigate:
                        TextField("URL", text: $urlValue)
                            .autocapitalization(.none)
                            .autocorrectionDisabled()
                    case .setBrightness:
                        VStack(alignment: .leading) {
                            Text("Brightness: \(Int(brightnessValue * 100))%")
                            Slider(value: $brightnessValue, in: 0...1)
                        }
                    case .playSound:
                        TextField("Sound URL", text: $urlValue)
                            .autocapitalization(.none)
                            .autocorrectionDisabled()
                    case .tts:
                        TextField("Message", text: $messageValue)
                    default:
                        EmptyView()
                    }
                } header: {
                    Text("Action")
                }
            }
            .navigationTitle("Add Action Trigger")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let action = buildAction()
                        let trigger = EntityActionTrigger(
                            entityId: entityId,
                            triggerState: triggerState,
                            action: action
                        )
                        onSave(trigger)
                        dismiss()
                    }
                    .disabled(entityId.isEmpty)
                }
            }
        }
    }

    private func buildAction() -> TriggerAction {
        switch selectedActionType {
        case .navigate:
            return .navigate(url: urlValue)
        case .setBrightness:
            return .setBrightness(level: brightnessValue)
        case .startScreensaver:
            return .startScreensaver(mode: nil)
        case .stopScreensaver:
            return .stopScreensaver
        case .refresh:
            return .refresh
        case .playSound:
            return .playSound(url: urlValue)
        case .tts:
            return .tts(message: messageValue)
        }
    }
}

// MARK: - TriggerAction Extensions

extension TriggerAction {
    var displayName: String {
        switch self {
        case .navigate: return "Navigate"
        case .setBrightness: return "Set Brightness"
        case .startScreensaver: return "Start Screensaver"
        case .stopScreensaver: return "Stop Screensaver"
        case .refresh: return "Refresh"
        case .playSound: return "Play Sound"
        case .tts: return "TTS"
        }
    }
}

// MARK: - Preview

@available(iOS 17.0, *)
#Preview {
    EntityTriggersView(
        wakeEntities: .constant([
            EntityTrigger(entityId: "binary_sensor.motion", triggerState: "on")
        ]),
        sleepEntities: .constant([]),
        actionTriggers: .constant([])
    )
}
