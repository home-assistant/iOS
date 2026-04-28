import AVFoundation
import PromiseKit
import Shared
import SwiftUI
import UniformTypeIdentifiers

struct NotificationSoundsView: View {
    enum SoundCategory: Int, CaseIterable, Identifiable {
        case imported
        case bundled
        case system

        var id: Int { rawValue }

        var title: String {
            switch self {
            case .imported: return L10n.SettingsDetails.Notifications.Sounds.imported
            case .bundled: return L10n.SettingsDetails.Notifications.Sounds.bundled
            case .system: return L10n.SettingsDetails.Notifications.Sounds.system
            }
        }
    }

    @StateObject private var viewModel = NotificationSoundsViewModel()
    @EnvironmentObject private var viewControllerProvider: ViewControllerProvider

    @State private var selected: SoundCategory = .imported
    @State private var showImporter = false
    @State private var alert: AlertInfo?

    private struct AlertInfo: Identifiable {
        let id = UUID()
        let title: String
        let message: String
    }

    private var categories: [SoundCategory] {
        if Current.isCatalyst {
            return [.imported, .bundled]
        }
        return SoundCategory.allCases
    }

    var body: some View {
        List {
            Section {
                Picker("", selection: $selected) {
                    ForEach(categories) { category in
                        Text(category.title).tag(category)
                    }
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }

            switch selected {
            case .imported:
                importedSection
            case .bundled:
                bundledSection
            case .system:
                systemSection
            }
        }
        .navigationTitle(L10n.SettingsDetails.Notifications.Sounds.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    if let url = URL(string: "https://companion.home-assistant.io/app/ios/notifications-sounds") {
                        openURLInBrowser(url, viewControllerProvider.viewController)
                    }
                } label: {
                    Image(systemSymbol: .questionmarkCircle)
                }
            }
        }
        .overlay {
            if viewModel.isBusy {
                ProgressOverlay()
            }
        }
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: [.audio, .data],
            allowsMultipleSelection: true
        ) { result in
            handleImport(result: result)
        }
        .alert(item: $alert) { info in
            Alert(
                title: Text(info.title),
                message: Text(info.message),
                dismissButton: .default(Text(L10n.okLabel))
            )
        }
        .onAppear {
            viewModel.loadSounds()
        }
        .onDisappear {
            viewModel.stopPlayback()
        }
    }

    // MARK: - Sections

    private var importedSection: some View {
        Section {
            ForEach(viewModel.imported, id: \.self) { url in
                soundRow(url: url)
            }
            .onDelete { indexSet in
                // Iterate descending so each removal doesn't shift the indices we still
                // need to read out of the source array.
                for index in indexSet.sorted(by: >) {
                    guard index < viewModel.imported.count else { continue }
                    let url = viewModel.imported[index]
                    do {
                        try viewModel.deleteSound(url)
                    } catch {
                        presentError(error)
                    }
                }
            }

            if Current.isCatalyst {
                Text(L10n.SettingsDetails.Notifications.Sounds.importMacInstructions)
                    .foregroundColor(.secondary)
                Button(L10n.SettingsDetails.Notifications.Sounds.importMacOpenFolder) {
                    viewModel.openLibrarySoundsFolder()
                }
            } else {
                Button(L10n.SettingsDetails.Notifications.Sounds.importCustom) {
                    showImporter = true
                }
                Button(L10n.SettingsDetails.Notifications.Sounds.importFileSharing) {
                    Task {
                        do {
                            let count = try await viewModel.importFromFileSharing()
                            presentImported(count: count)
                        } catch {
                            presentError(error)
                        }
                    }
                }
            }
        } footer: {
            Text(L10n.SettingsDetails.Notifications.Sounds.footer)
        }
    }

    private var bundledSection: some View {
        Section {
            ForEach(viewModel.bundled, id: \.self) { url in
                soundRow(url: url)
            }
        }
    }

    private var systemSection: some View {
        Section {
            ForEach(viewModel.system, id: \.self) { url in
                soundRow(url: url)
            }
            .onDelete { indexSet in
                // Iterate descending so each removal doesn't shift the indices we still
                // need to read out of the source array.
                for index in indexSet.sorted(by: >) {
                    guard index < viewModel.system.count else { continue }
                    let url = viewModel.system[index]
                    do {
                        try viewModel.deleteSound(url)
                    } catch {
                        presentError(error)
                    }
                }
            }

            Button(L10n.SettingsDetails.Notifications.Sounds.importSystem) {
                Task {
                    do {
                        let count = try await viewModel.importSystemSounds()
                        presentImported(count: count)
                    } catch {
                        presentError(error)
                    }
                }
            }
        }
    }

    private func soundRow(url: URL) -> some View {
        Button {
            viewModel.play(url: url) { error in
                presentError(error)
            }
        } label: {
            HStack {
                Text(url.lastPathComponent)
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button {
                    UIPasteboard.general.string = url.lastPathComponent
                } label: {
                    Text(L10n.copyLabel)
                }
                .buttonStyle(.borderless)
            }
        }
    }

    // MARK: - Helpers

    // PromiseKit also exports a single-parameter `Result`, so qualify with `Swift.Result`.
    private func handleImport(result: Swift.Result<[URL], Error>) {
        switch result {
        case let .success(urls):
            Task { await viewModel.importPickedFiles(urls) { error in
                await MainActor.run { presentError(error) }
            } }
        case let .failure(error):
            presentError(error)
        }
    }

    private func presentError(_ error: Error) {
        alert = AlertInfo(title: L10n.errorLabel, message: error.localizedDescription)
    }

    private func presentImported(count: Int) {
        alert = AlertInfo(
            title: L10n.SettingsDetails.Notifications.Sounds.ImportedAlert.title,
            message: L10n.SettingsDetails.Notifications.Sounds.ImportedAlert.message(count)
        )
    }
}

// MARK: - Progress Overlay

private struct ProgressOverlay: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            ProgressView()
                .progressViewStyle(.circular)
                .padding(24)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
    }
}

// MARK: - View Model

@MainActor
final class NotificationSoundsViewModel: ObservableObject {
    @Published var imported: [URL] = []
    @Published var bundled: [URL] = []
    @Published var system: [URL] = []
    @Published var isBusy = false

    private var audioPlayer: AVAudioPlayer?

    func loadSounds() {
        imported = (try? importedFilesWithSuffix(".wav")) ?? []
        if Current.isCatalyst {
            imported = []
        }
        imported.sort(by: { $0.lastPathComponent < $1.lastPathComponent })

        bundled = (Bundle.main.urls(forResourcesWithExtension: "wav", subdirectory: nil) ?? [])
            .sorted(by: { $0.lastPathComponent < $1.lastPathComponent })

        system = ((try? importedFilesWithSuffix(".caf")) ?? [])
            .sorted(by: { $0.lastPathComponent < $1.lastPathComponent })
    }

    func play(url: URL, onError: (Error) -> Void) {
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.play()
        } catch {
            Current.Log.error("Error when playing sound \(url.lastPathComponent): \(error)")
            onError(error)
        }
    }

    func stopPlayback() {
        audioPlayer?.stop()
        audioPlayer = nil
    }

    func deleteSound(_ url: URL) throws {
        Current.Log.verbose("Deleting sound at \(url)")
        do {
            try FileManager.default.removeItem(at: url)
        } catch {
            throw SoundError(soundURL: nil, kind: .deleteError, underlying: error)
        }
        imported.removeAll { $0 == url }
        system.removeAll { $0 == url }
    }

    func openLibrarySoundsFolder() {
        do {
            let url = try librarySoundsURL()
            URLOpener.shared.open(url, options: [:], completionHandler: nil)
        } catch {
            Current.Log.error("couldn't open folder: \(error)")
        }
    }

    func importFromFileSharing() async throws -> Int {
        isBusy = true
        defer { isBusy = false }

        let sharingURL = try fileSharingPath()
        let sounds = soundsInDirectory(sharingURL) ?? []
        let copied = try await copySounds(sounds, category: .imported)
        return copied.count
    }

    func importSystemSounds() async throws -> Int {
        isBusy = true
        defer { isBusy = false }

        let soundsPath = URL(fileURLWithPath: "/System/Library/Audio/UISounds", isDirectory: true)
        let systemSounds = await Task.detached(priority: .userInitiated) { () -> [URL] in
            Self.enumerateSounds(path: soundsPath) ?? []
        }.value
        let copied = try await copySounds(systemSounds, category: .system)
        return copied.count
    }

    // Pure file-system work — opt out of the surrounding `@MainActor` isolation so
    // it can be called from `Task.detached` for off-main enumeration.
    private nonisolated static func enumerateSounds(path: URL) -> [URL]? {
        guard let enu = FileManager.default.enumerator(at: path, includingPropertiesForKeys: [.isDirectoryKey]) else {
            Current.Log.error("Unable to get enumerator!")
            return nil
        }

        var foundURLs: [URL] = []

        while let fileURL = enu.nextObject() as? URL {
            if FileManager.default.isDirectory(fileURL) == false, ensureDurationStatic(fileURL) {
                foundURLs.append(fileURL)
            }
        }

        return foundURLs
    }

    private nonisolated static func ensureDurationStatic(_ soundURL: URL) -> Bool {
        let duration = Double(CMTimeGetSeconds(AVURLAsset(url: soundURL).duration))
        return duration > 0.0 && duration <= 30.0
    }

    func importPickedFiles(_ urls: [URL], onError: @escaping (Error) async -> Void) async {
        isBusy = true
        defer { isBusy = false }

        let destinationURL: URL
        do {
            destinationURL = try librarySoundsURL()
        } catch {
            await onError(error)
            return
        }

        for pickedURL in urls {
            var options = AKConverter.Options()
            options.format = "wav"
            options.sampleRate = 48000
            options.bitDepth = 32
            options.eraseFile = true

            let fileName = pickedURL.deletingPathExtension().lastPathComponent
            let newSoundPath = destinationURL.appendingPathComponent("\(fileName).wav")

            let didStart = pickedURL.startAccessingSecurityScopedResource()
            defer {
                if didStart { pickedURL.stopAccessingSecurityScopedResource() }
            }

            await withCheckedContinuation { continuation in
                AKConverter(inputURL: pickedURL, outputURL: newSoundPath, options: options).start { error in
                    Task { @MainActor in
                        if let error {
                            let sError = SoundError(
                                soundURL: newSoundPath,
                                kind: .conversionFailed,
                                underlying: error
                            )
                            Current.Log.error("Experienced error during convert \(sError) (\(error))")
                            await onError(sError)
                        } else {
                            if !self.imported.contains(newSoundPath) {
                                self.imported.append(newSoundPath)
                                self.imported.sort(by: { $0.lastPathComponent < $1.lastPathComponent })
                            }
                        }
                        continuation.resume()
                    }
                }
            }
        }
    }

    // MARK: - File helpers

    func librarySoundsURL() throws -> URL {
        do {
            let librarySoundsPath = try FileManager.default.url(
                for: .libraryDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: false
            ).appendingPathComponent("Sounds")

            if !Current.isCatalyst {
                Current.Log.verbose("Creating sounds directory at \(librarySoundsPath)")
                try FileManager.default.createDirectory(
                    at: librarySoundsPath,
                    withIntermediateDirectories: true,
                    attributes: nil
                )
            }

            return librarySoundsPath
        } catch {
            throw SoundError(soundURL: nil, kind: .cantBuildLibrarySoundsPath, underlying: error)
        }
    }

    private func importedFilesWithSuffix(_ suffix: String) throws -> [URL] {
        do {
            let files = try FileManager.default.contentsOfDirectory(
                at: librarySoundsURL(),
                includingPropertiesForKeys: nil
            )
            return files.filter { $0.lastPathComponent.hasSuffix(suffix) }
        } catch {
            throw SoundError(soundURL: nil, kind: .cantGetDirectoryContents, underlying: error)
        }
    }

    private func fileSharingPath() throws -> URL {
        do {
            return try FileManager.default.url(
                for: .documentDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: false
            )
        } catch {
            throw SoundError(soundURL: nil, kind: .cantGetFileSharingPath, underlying: error)
        }
    }

    private func soundsInDirectory(_ path: URL) -> [URL]? {
        guard let enu = FileManager.default.enumerator(at: path, includingPropertiesForKeys: [.isDirectoryKey]) else {
            Current.Log.error("Unable to get enumerator!")
            return nil
        }

        var foundURLs: [URL] = []

        while let fileURL = enu.nextObject() as? URL {
            if FileManager.default.isDirectory(fileURL) == false, ensureDuration(fileURL) {
                foundURLs.append(fileURL)
            }
        }

        return foundURLs
    }

    private func ensureDuration(_ soundURL: URL) -> Bool {
        let duration = Double(CMTimeGetSeconds(AVURLAsset(url: soundURL).duration))
        return duration > 0.0 && duration <= 30.0
    }

    private func copySounds(_ soundURLs: [URL], category: NotificationSoundsView.SoundCategory) async throws -> [URL] {
        guard !soundURLs.isEmpty else { return [] }

        let destination = try librarySoundsURL()
        var copied: [URL] = []

        for soundURL in soundURLs {
            let soundName = soundURL.lastPathComponent
            let newURL = destination.appendingPathComponent(soundName)

            Current.Log.verbose("Copying sound \(soundName) from \(soundURL) to \(newURL)")

            if FileManager.default.fileExists(atPath: newURL.path) {
                Current.Log.verbose("Sound \(soundName) already exists in ~/Library/Sounds, removing")
                do {
                    try FileManager.default.removeItem(at: newURL)
                } catch {
                    throw SoundError(soundURL: nil, kind: .deleteError, underlying: error)
                }
            }

            do {
                try FileManager.default.copyItem(at: soundURL, to: newURL)
            } catch {
                throw SoundError(soundURL: nil, kind: .copyError, underlying: error)
            }

            copied.append(newURL)

            switch category {
            case .imported:
                if !imported.contains(newURL) {
                    imported.append(newURL)
                }
            case .system:
                if !system.contains(newURL) {
                    system.append(newURL)
                }
            case .bundled:
                break
            }
        }

        imported.sort(by: { $0.lastPathComponent < $1.lastPathComponent })
        system.sort(by: { $0.lastPathComponent < $1.lastPathComponent })

        return copied
    }
}

// MARK: - File Manager helper

private extension FileManager {
    func isDirectory(_ url: URL) -> Bool? {
        var isDir = ObjCBool(false)
        if fileExists(atPath: url.path, isDirectory: &isDir) {
            return isDir.boolValue
        }
        return nil
    }
}

// MARK: - Error type

private struct SoundError: LocalizedError {
    enum ErrorKind {
        case cantBuildLibrarySoundsPath
        case cantGetFileSharingPath
        case cantGetDirectoryContents
        case conversionFailed
        case copyError
        case deleteError
    }

    let soundURL: URL?
    let kind: ErrorKind
    let underlying: Error

    var errorDescription: String? {
        let description = underlying.localizedDescription
        switch kind {
        case .cantBuildLibrarySoundsPath:
            return L10n.SettingsDetails.Notifications.Sounds.Error.cantBuildLibrarySoundsPath(description)
        case .cantGetFileSharingPath:
            return L10n.SettingsDetails.Notifications.Sounds.Error.cantGetFileSharingPath(description)
        case .cantGetDirectoryContents:
            return L10n.SettingsDetails.Notifications.Sounds.Error.cantGetDirectoryContents(description)
        case .conversionFailed:
            return L10n.SettingsDetails.Notifications.Sounds.Error.conversionFailed(description)
        case .copyError:
            return L10n.SettingsDetails.Notifications.Sounds.Error.copyError(description)
        case .deleteError:
            return L10n.SettingsDetails.Notifications.Sounds.Error.deleteError(description)
        }
    }
}
