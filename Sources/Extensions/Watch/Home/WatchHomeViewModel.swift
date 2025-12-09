import ClockKit
import WidgetKit
import ClockKit
import Communicator
import Foundation
import GRDB
import NetworkExtension
import PromiseKit
import Shared

enum WatchHomeType {
    case undefined
    case empty
    case config(watchConfig: WatchConfig, magicItemsInfo: [MagicItem.Info])
    case error(message: String)
}

final class WatchHomeViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var showAssist = false
    @Published var showError = false
    @Published var errorMessage = ""
    @Published var currentSSID: String = ""
    @Published private(set) var homeType: WatchHomeType = .undefined

    @Published var watchConfig: WatchConfig = .init()
    @Published var magicItemsInfo: [MagicItem.Info] = []

    // If the watchConfig items are the same but it's customization properties
    // are different, the list won't refresh. This is a workaround to force a refresh
    @Published var refreshListID: UUID = .init()
    
    @Published var complicationCount: Int = 0
    
    private var complicationCountObservation: AnyDatabaseCancellable?
    
    init() {
        setupComplicationObservation()
    }

    @MainActor
    func fetchNetworkInfo() async {
        let networkInformation = await Current.networkInformation
        WatchUserDefaults.shared.set(networkInformation?.ssid, key: .watchSSID)
        currentSSID = networkInformation?.ssid ?? ""
    }
    
    @MainActor
    func fetchComplicationCount() {
        do {
            let count = try Current.database().read { db in
                try AppWatchComplication.fetchCount(db)
            }
            complicationCount = count
            Current.Log.verbose("Fetched complication count: \(count)")
        } catch {
            Current.Log.error("Failed to fetch complication count from GRDB: \(error.localizedDescription)")
            complicationCount = 0
        }
    }
    
    /// Sets up database observation for AppWatchComplication changes
    /// Automatically updates complicationCount when complications are added/removed
    private func setupComplicationObservation() {
        let observation = ValueObservation.tracking { db in
            try AppWatchComplication.fetchCount(db)
        }
        
        complicationCountObservation = observation.start(
            in: Current.database(),
            scheduling: .immediate,
            onError: { error in
                Current.Log.error("Error observing complication count: \(error.localizedDescription)")
            },
            onChange: { [weak self] count in
                Task { @MainActor [weak self] in
                    self?.complicationCount = count
                    Current.Log.verbose("Complication count updated via observation: \(count)")
                }
            }
        )
    }

    @MainActor
    func initialRoutine() {
        // First display whatever is in cache
        loadCache()
        // Complication count is now automatically observed via setupComplicationObservation()
        // Now fetch new data in the background (shows loading indicator only for this fetch)
        isLoading = true
        requestConfig()
    }

    @MainActor
    func requestConfig() {
        homeType = .undefined
        guard Communicator.shared.currentReachability != .notReachable else {
            Current.Log.error("iPhone reachability is not immediate reachable")
            loadCache()
            return
        }
        isLoading = true

        // Request watch config via interactive message
        Communicator.shared.send(.init(
            identifier: InteractiveImmediateMessages.watchConfig.rawValue,
            reply: { [weak self] message in
                self?.handleMessageResponse(message)
            }
        ))

        // Request complications sync from phone
        requestComplicationsSync()
    }

    func info(for magicItem: MagicItem) -> MagicItem.Info {
        magicItemsInfo.first(where: {
            $0.id == magicItem.serverUniqueId
        }) ?? .init(
            id: magicItem.id,
            name: magicItem.id,
            iconName: ""
        )
    }

    @MainActor
    private func handleMessageResponse(_ message: ImmediateMessage) {
        switch message.identifier {
        case InteractiveImmediateResponses.emptyWatchConfigResponse.rawValue:
            clearCacheAndLoad()
        case InteractiveImmediateResponses.watchConfigResponse.rawValue:
            setupConfig(message)
        default:
            Current.Log
                .error("Received unmapped response id for watch config request, id: \(message.identifier)")
            loadCache()
        }
        updateLoading(isLoading: false)
    }

    @MainActor
    private func setupConfig(_ message: ImmediateMessage) {
        guard let configData = message.content["config"] as? Data,
              let watchConfig = WatchConfig.decodeForWatch(configData) else {
            Current.Log.error("Failed to get config data from watch config response")
            return
        }

        guard let magicItemsInfo = message.content["magicItemsInfo"] as? [Data] else {
            Current.Log.error("Failed to get magicItemsInfo data array from watch config response")
            return
        }
        let itemsInfo = magicItemsInfo.map({ MagicItem.Info.decodeForWatch($0) })

        do {
            try Current.database().write { db in
                try watchConfig.insert(db, onConflict: .replace)
            }
            saveItemsInfoInCache(itemsInfo.compactMap({ $0 }))
        } catch {
            Current.Log
                .error(
                    "Failed to save watch config and/or magic item info in database on Apple watch, error: \(error.localizedDescription)"
                )
        }

        loadCache()
    }

    @MainActor
    func loadCache() {
        do {
            if let watchConfig = try Current.database().read({ db in
                try WatchConfig.fetchOne(db)
            }) {
                loadInformationCache(watchConfig: watchConfig)
            } else {
                updateConfig(config: .init(), magicItemsInfo: [])
            }
        } catch {
            Current.Log.error("Failed to fetch watch config from database, error: \(error.localizedDescription)")
            displayError(message: L10n.Watch.Config.Cache.Error.message)
            updateConfig(config: .init(), magicItemsInfo: [])
        }
    }

    @MainActor
    private func loadInformationCache(watchConfig: WatchConfig) {
        let magicItemsInfo = getItemsInfoFromCache()
        if !magicItemsInfo.isEmpty {
            updateConfig(config: watchConfig, magicItemsInfo: magicItemsInfo)
            resetError()
        } else {
            Current.Log.error("Failed to retrieve magic items cache")
            displayError(message: L10n.Watch.Config.Error.message("No information cached"))
        }
        updateLoading(isLoading: false)
    }

    @MainActor
    private func clearCacheAndLoad() {
        do {
            _ = try Current.database().write { db in
                try WatchConfig.deleteAll(db)
            }
        } catch {
            Current.Log
                .error(
                    "Failed to delete watch config and/or magic item info in database on Apple watch, error: \(error.localizedDescription)"
                )
        }

        deleteItemsInfoInCache()
        loadCache()
    }

    private func saveItemsInfoInCache(_ itemsInfo: [MagicItem.Info]) {
        do {
            let fileURL = AppConstants.watchMagicItemsInfo
            let jsonData = try JSONEncoder().encode(itemsInfo)
            try jsonData.write(to: fileURL)
            Current.Log
                .verbose("JSON saved successfully for watch magic items info, file URL: \(fileURL.absoluteString)")
        } catch {
            Current.Log.error("Error saving JSON for magic items info: \(error)")
        }
    }

    private func deleteItemsInfoInCache() {
        do {
            let fileURL = AppConstants.watchMagicItemsInfo
            try FileManager.default.removeItem(at: fileURL)
        } catch {
            Current.Log.error("Error deleting JSON for magic items info: \(error)")
        }
    }

    private func getItemsInfoFromCache() -> [MagicItem.Info] {
        let fileURL = AppConstants.watchMagicItemsInfo
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            Current.Log.error("Watch magic items info cache file doesn't exist at path: \(fileURL.absoluteString)")
            return []
        }

        let data = FileManager.default.contents(atPath: fileURL.path) ?? Data()

        do {
            let infos = try JSONDecoder().decode([MagicItem.Info].self, from: data)
            return infos
        } catch {
            Current.Log.error("Failed to decode watch magic item info data from cache, error: \(error)")
            return []
        }
    }

    private func updateConfig(config: WatchConfig, magicItemsInfo: [MagicItem.Info]) {
        DispatchQueue.main.async { [weak self] in
            self?.watchConfig = config
            self?.magicItemsInfo = magicItemsInfo

            if config.assist.showAssist,
               config.assist.serverId != nil,
               config.assist.pipelineId != nil {
                self?.showAssist = true
            } else {
                self?.showAssist = false
            }
            self?.refreshListID = UUID()
        }
    }

    private func updateLoading(isLoading: Bool) {
        DispatchQueue.main.async { [weak self] in
            self?.isLoading = isLoading
        }
    }

    private func displayError(message: String) {
        DispatchQueue.main.async { [weak self] in
            self?.errorMessage = message
            self?.showError = true
        }
    }

    private func resetError() {
        DispatchQueue.main.async { [weak self] in
            self?.errorMessage = ""
            self?.showError = false
        }
    }
}

// MARK: - Complication Sync

extension WatchHomeViewModel {
    /// Initiates the complication sync process from the phone
    /// This starts a paginated sync where complications are sent one at a time
    func requestComplicationsSync() {
        Current.Log.info("Requesting complications sync from phone (paginated approach)")
        requestNextComplication(index: 0)
    }

    /// Requests a single complication from the phone by index
    /// - Parameter index: The index of the complication to request (0-based)
    ///
    /// This implements a paginated sync protocol:
    /// 1. Watch sends interactive request with index
    /// 2. Phone responds with complication at that index + "hasMore" flag in reply
    /// 3. If hasMore is true, watch requests next index
    /// 4. Continues until hasMore is false or error occurs
    private func requestNextComplication(index: Int) {
        Current.Log.info("Requesting complication at index \(index)")

        Communicator.shared.send(.init(
            identifier: WatchComplicationSyncMessages.Identifier.syncComplication,
            content: [WatchComplicationSyncMessages.ContentKey.index: index],
            reply: { [weak self] replyMessage in
                self?.handleComplicationResponse(replyMessage, requestedIndex: index)
            }
        ), errorHandler: { error in
            Current.Log.error("Failed to send syncComplication request for index \(index): \(error)")
        })
    }

    /// Handles the response for a single complication request
    /// - Parameters:
    ///   - message: The reply message from the phone
    ///   - requestedIndex: The index that was requested
    private func handleComplicationResponse(_ message: ImmediateMessage, requestedIndex: Int) {
        // Check for error
        if let error = message.content[WatchComplicationSyncMessages.ContentKey.error] as? String {
            Current.Log.error("Received error for complication at index \(requestedIndex): \(error)")
            return
        }

        guard let complicationData = message
            .content[WatchComplicationSyncMessages.ContentKey.complicationData] as? Data,
            let hasMore = message.content[WatchComplicationSyncMessages.ContentKey.hasMore] as? Bool,
            let index = message.content[WatchComplicationSyncMessages.ContentKey.index] as? Int,
            let total = message.content[WatchComplicationSyncMessages.ContentKey.total] as? Int else {
            Current.Log.error("Invalid syncComplication response format")
            return
        }

        Current.Log.info("Received complication \(index + 1) of \(total) (hasMore: \(hasMore))")

        // Save the complication
        saveComplicationToDatabase(complicationData, index: index, total: total)

        // Request next complication if more are pending
        if hasMore {
            Current.Log.verbose("More complications pending, requesting index \(index + 1)")
            requestNextComplication(index: index + 1)
        } else {
            Current.Log.info("Complication sync complete! Received \(total) complications")
            // Trigger complication reload
            reloadComplications()
        }
    }

    /// Saves a single complication to the watch GRDB database
    /// - Parameters:
    ///   - complicationData: JSON data of the complication
    ///   - index: The index of this complication
    ///   - total: Total number of complications being synced
    private func saveComplicationToDatabase(_ complicationData: Data, index: Int, total: Int) {
        do {
            // Convert JSON data to AppWatchComplication
            let complication = try AppWatchComplication.from(jsonData: complicationData)
            
            Current.Log.verbose("Deserialized complication: \(complication.identifier)")

            // Save to GRDB database
            try Current.database().write { db in
                // On first complication, clear existing ones
                if index == 0 {
                    Current.Log.info("Clearing existing complications from watch GRDB database")
                    try AppWatchComplication.deleteAll(from: db)
                }
                
                // Insert or replace the complication
                try complication.insert(db, onConflict: .replace)
            }

            Current.Log.info("Saved complication \(index + 1) of \(total) to watch GRDB database")
        } catch {
            Current.Log.error("Failed to save complication at index \(index): \(error.localizedDescription)")
        }
    }

    /// Triggers a reload of all complications on the watch
    private func reloadComplications() {
        if #available(watchOS 9.0, *) {
            WidgetCenter.shared.reloadAllTimelines()
        }

        CLKComplicationServer.sharedInstance().reloadComplicationDescriptors()

        if let activeComplications = CLKComplicationServer.sharedInstance().activeComplications {
            Current.Log.info("Reloading \(activeComplications.count) active complications")
            for complication in activeComplications {
                CLKComplicationServer.sharedInstance().reloadTimeline(for: complication)
            }
        }
        
        // Complication count will be automatically updated via database observation
    }
}
