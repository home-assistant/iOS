import AVFoundation
import Eureka
import MBProgressHUD
import MobileCoreServices
import PromiseKit
import Shared
import UIKit

private var buttonAssociatedString: String = ""

class NotificationSoundsViewController: HAFormViewController, UIDocumentPickerDelegate {
    public var onDismissCallback: ((UIViewController) -> Void)?

    var audioPlayer: AVAudioPlayer?

    override func viewDidLoad() {
        super.viewDidLoad()

        title = L10n.SettingsDetails.Notifications.Sounds.title

        navigationItem.rightBarButtonItems = [
            with(Constants.helpBarButtonItem) {
                $0.action = #selector(help)
                $0.target = self
            },
        ]

        var importedFileSharingSounds: [URL] = []

        do {
            if Current.isCatalyst {
                importedFileSharingSounds = []
            } else {
                importedFileSharingSounds = try importedFilesWithSuffix(".wav")
            }
        } catch {
            Current.Log.error("Error while getting imported file sharing sounds \(error)")
        }

        var importedSystemSounds: [URL] = []

        do {
            importedSystemSounds = try importedFilesWithSuffix(".caf")
        } catch {
            Current.Log.error("Error while getting imported system sounds \(error)")
        }

        form +++ SegmentedRow<String>("soundListChooser") {
            var options = [String]()

            options.append(L10n.SettingsDetails.Notifications.Sounds.imported)
            options.append(L10n.SettingsDetails.Notifications.Sounds.bundled)

            if !Current.isCatalyst {
                options.append(L10n.SettingsDetails.Notifications.Sounds.system)
            }

            $0.options = options
            $0.value = L10n.SettingsDetails.Notifications.Sounds.imported
        }

        form.append(getSoundsSection(
            "imported",
            L10n.SettingsDetails.Notifications.Sounds.imported,
            fileURLs: importedFileSharingSounds
        ))

        if let urls = Bundle.main.urls(forResourcesWithExtension: "wav", subdirectory: nil) {
            form.append(getSoundsSection(
                "bundled",
                L10n.SettingsDetails.Notifications.Sounds.bundled,
                fileURLs: urls
            ))
        }

        form.append(getSoundsSection(
            "system",
            L10n.SettingsDetails.Notifications.Sounds.system,
            fileURLs: importedSystemSounds
        ))
    }

    func getSoundsSection(_ tag: String, _ header: String, fileURLs: [URL]) -> Section {
        let sortedURLs = fileURLs.sorted(by: { $0.lastPathComponent < $1.lastPathComponent })
        let section = Section()
        section.tag = tag
        section.hidden = Condition.predicate(NSPredicate(format: "$soundListChooser != %@", header))

        let isImportedSection = header == L10n.SettingsDetails.Notifications.Sounds.imported

        for sound in sortedURLs {
            section.append(getSoundRow(sound, isImportedSection))
        }

        if isImportedSection, Current.isCatalyst {
            section <<< InfoLabelRow {
                $0.title = L10n.SettingsDetails.Notifications.Sounds.importMacInstructions
            }
                <<< ButtonRow {
                    $0.title = L10n.SettingsDetails.Notifications.Sounds.importMacOpenFolder
                    $0.onCellSelection { _, _ in
                        do {
                            UIApplication.shared.open(try self.librarySoundsURL(), options: [:], completionHandler: nil)
                        } catch {
                            Current.Log.error("couldn't open folder: \(error)")
                        }
                    }
                }
        } else if isImportedSection {
            section
                <<< ButtonRow {
                    $0.tag = "import_custom_sound"
                    $0.title = L10n.SettingsDetails.Notifications.Sounds.importCustom
                }.onCellSelection { _, _ in
                    self.importTapped()
                }
                <<< ButtonRow {
                    $0.title = L10n.SettingsDetails.Notifications.Sounds.importFileSharing
                }.onCellSelection { cell, _ in
                    MBProgressHUD.showAdded(to: self.view, animated: true)

                    firstly {
                        self.fileSharingPath()
                    }.then { path -> Promise<[URL]> in
                        let sounds: [URL] = self.soundsInDirectory(path) ?? []
                        return self.copySounds(sounds, "imported")
                    }.done { copied in
                        let title = L10n.SettingsDetails.Notifications.Sounds.ImportedAlert.title
                        let message = L10n.SettingsDetails.Notifications.Sounds.ImportedAlert.message(copied.count)
                        self.showAlert(message, title, popoverView: cell.contentView)
                    }.catch { error in
                        self.showAlert(error.localizedDescription, nil, popoverView: cell.contentView)
                    }.finally {
                        MBProgressHUD.hide(for: self.view, animated: true)
                    }
                }
        }

        if header == L10n.SettingsDetails.Notifications.Sounds.system {
            section
                <<< ButtonRow {
                    $0.title = L10n.SettingsDetails.Notifications.Sounds.importSystem
                }.onCellSelection { cell, _ in
                    MBProgressHUD.showAdded(to: self.view, animated: true)

                    DispatchQueue.global(qos: .userInitiated).async {
                        let soundsPath = URL(fileURLWithPath: "/System/Library/Audio/UISounds", isDirectory: true)
                        let systemSounds: [URL] = self.soundsInDirectory(soundsPath) ?? []
                        self.copySounds(systemSounds, "system").done { copied in
                            let title = L10n.SettingsDetails.Notifications.Sounds.ImportedAlert.title
                            let message = L10n.SettingsDetails.Notifications.Sounds.ImportedAlert.message(copied.count)
                            self.showAlert(message, title, popoverView: cell.contentView)
                        }.catch { error in
                            self.showAlert(error.localizedDescription, nil, popoverView: cell.contentView)
                        }.finally {
                            MBProgressHUD.hide(for: self.view, animated: true)
                        }
                    }
                }
        }

        return section
    }

    @objc private func copyButtonTapped(_ button: UIButton) {
        guard let string = objc_getAssociatedObject(button, &buttonAssociatedString) as? String else {
            Current.Log.info("failed to copy from button \(button)")
            return
        }

        UIPasteboard.general.string = string
    }

    func getSoundRow(_ fileURL: URL, _ enableDelete: Bool = false) -> ButtonRowOf<URL> {
        let copyButton = with(UIButton(type: .system)) {
            $0.setTitle(L10n.copyLabel, for: .normal)
            $0.sizeToFit()
            $0.addTarget(self, action: #selector(copyButtonTapped(_:)), for: .touchUpInside)
            objc_setAssociatedObject($0, &buttonAssociatedString, fileURL.lastPathComponent, .OBJC_ASSOCIATION_COPY)
        }

        return ButtonRowOf<URL> {
            $0.value = fileURL
            $0.tag = fileURL.lastPathComponent
            $0.title = fileURL.lastPathComponent
            if enableDelete {
                $0.trailingSwipe.actions = [SwipeAction(
                    style: .destructive,
                    title: L10n.delete,
                    handler: self.handleSwipeDelete
                )]
                $0.trailingSwipe.performsFirstActionWithFullSwipe = true
            }
        }.cellSetup { cell, _ in
            cell.accessoryView = copyButton
        }.cellUpdate { cell, _ in
            cell.textLabel?.numberOfLines = 0
            cell.textLabel?.textAlignment = .natural
            cell.textLabel?.textColor = nil
        }.onCellSelection { cell, _ in
            do {
                self.audioPlayer = try AVAudioPlayer(contentsOf: fileURL)
                self.audioPlayer?.play()
            } catch {
                Current.Log.error("Error when playing sound \(fileURL.lastPathComponent): \(error)")
                self.showAlert(error.localizedDescription, nil, popoverView: cell.contentView)
            }
        }
    }

    func handleSwipeDelete(action: SwipeAction, row: BaseRow, completionHandler: ((Bool) -> Void)?) {
        guard let urlRow = row as? ButtonRowOf<URL>, let url = urlRow.value else { completionHandler?(false); return }

        do {
            try deleteSound(url)
        } catch {
            Current.Log.error("Error when deleting sound \(url): \(error)")
            showAlert(error.localizedDescription, nil, popoverView: row.baseCell.contentView)
            completionHandler?(false)
            return
        }

        if let section = row.section, let indexPath = row.indexPath {
            section.remove(at: indexPath.row)
        }

        completionHandler?(true)
    }

    @objc func importTapped() {
        let picker = UIDocumentPickerViewController(documentTypes: [
            String(kUTTypeAudio),
            String(kUTTypeData),
        ], in: .import)
        picker.delegate = self
        picker.modalPresentationStyle = .fullScreen
        picker.allowsMultipleSelection = true
        present(picker, animated: true, completion: nil)
    }

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        Current.Log.verbose("Did pick sounds at \(urls)")
        for pickedURL in urls {
            Current.Log.verbose("Processing picked sound at \(pickedURL)")
            var options = AKConverter.Options()
            options.format = "wav"
            options.sampleRate = 48000
            options.bitDepth = 32
            options.eraseFile = true

            let librarySoundsURL: URL
            do {
                librarySoundsURL = try self.librarySoundsURL()
            } catch {
                Current.Log.error("Error when getting library sounds URL \(error)")
                showAlert(error.localizedDescription)
                return
            }

            let fileName = pickedURL.deletingPathExtension().lastPathComponent
            let newSoundPath = librarySoundsURL.appendingPathComponent("\(fileName).wav")

            Current.Log.verbose("New sound path is \(newSoundPath)")

            AKConverter(inputURL: pickedURL, outputURL: newSoundPath, options: options).start { error in
                if let error = error {
                    let sError = SoundError(soundURL: newSoundPath, kind: .conversionFailed, underlying: error)
                    Current.Log.error("Experienced error during convert \(sError) (\(error))")
                    self.showAlert(sError.localizedDescription)
                    return
                }

                if self.form.rowBy(tag: newSoundPath.lastPathComponent) == nil,
                   var section = self.form.sectionBy(tag: "imported") {
                    section.insert(self.getSoundRow(newSoundPath, true), at: section.count - 1)
                }
            }
        }
    }

    func librarySoundsURL() throws -> URL {
        do {
            let librarySoundsPath = try FileManager.default.url(
                for: .libraryDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: false
            ).appendingPathComponent("Sounds")

            if !Current.isCatalyst {
                // on Catalyst the sounds folder is a symlink to the global one, we don't want to mess with it
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

    func importedFilesWithSuffix(_ suffix: String) throws -> [URL] {
        do {
            let files = try FileManager.default.contentsOfDirectory(
                at: try librarySoundsURL(),
                includingPropertiesForKeys: nil,
                options: []
            )
            return files.filter({ $0.lastPathComponent.hasSuffix(suffix) })
        } catch {
            throw SoundError(soundURL: nil, kind: .cantGetDirectoryContents, underlying: error)
        }
    }

    func soundsInDirectory(_ path: URL) -> [URL]? {
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

    func fileSharingPath() -> Promise<URL> {
        Promise { seal in
            do {
                seal.fulfill(try FileManager.default.url(
                    for: .documentDirectory,
                    in: .userDomainMask,
                    appropriateFor: nil,
                    create: false
                ))
            } catch {
                seal.reject(SoundError(soundURL: nil, kind: .cantGetFileSharingPath, underlying: error))
            }
        }
    }

    // Thanks to http://stackoverflow.com/a/35624018/486182
    // Must reboot device after installing new push sounds (http://stackoverflow.com/q/34998278/486182)
    func copySounds(_ soundURLs: [URL], _ formSectionTag: String) throws -> [URL] {
        guard !soundURLs.isEmpty else { return [URL]() }

        let librarySoundsURL = try self.librarySoundsURL()

        var copiedSounds: [URL] = []

        for soundURL in soundURLs {
            let soundName = soundURL.lastPathComponent

            let newURL = librarySoundsURL.appendingPathComponent(soundName)

            Current.Log.verbose("Copying sound \(soundName) from \(soundURL) to \(newURL)")

            if FileManager.default.fileExists(atPath: newURL.path) {
                Current.Log.verbose("Sound \(soundName) already exists in ~/Library/Sounds, removing")
                try deleteSound(newURL)
            }

            do {
                try FileManager.default.copyItem(at: soundURL, to: newURL)
            } catch {
                throw SoundError(soundURL: nil, kind: .copyError, underlying: error)
            }

            copiedSounds.append(newURL)

            if form.rowBy(tag: newURL.lastPathComponent) == nil,
               var section = form.sectionBy(tag: formSectionTag) {
                section.insert(
                    getSoundRow(newURL),
                    at: formSectionTag == "system" ? section.count - 1 : section.count
                )
            }
        }

        return copiedSounds
    }

    func deleteSound(_ soundURL: URL) throws {
        Current.Log.verbose("Deleting sound at \(soundURL)")
        do {
            try FileManager.default.removeItem(at: soundURL)
        } catch {
            throw SoundError(soundURL: nil, kind: .deleteError, underlying: error)
        }
    }

    func copySounds(_ soundURLs: [URL], _ formSectionTag: String) -> Promise<[URL]> {
        guard !soundURLs.isEmpty else { return Promise.value([URL]()) }

        do {
            let librarySoundsURL = try self.librarySoundsURL()

            let promises: [Promise<URL>] = soundURLs.map { self.copySound(librarySoundsURL, $0, formSectionTag) }

            return when(fulfilled: promises)
        } catch {
            return Promise(error: error)
        }
    }

    func copySound(_ librarySoundsURL: URL, _ soundURL: URL, _ formSectionTag: String) -> Promise<URL> {
        Promise { seal in
            let soundName = soundURL.lastPathComponent

            let newURL = librarySoundsURL.appendingPathComponent(soundName)

            Current.Log.verbose("Copying sound \(soundName) from \(soundURL) to \(newURL)")

            if FileManager.default.fileExists(atPath: newURL.path) {
                Current.Log.verbose("Sound \(soundName) already exists in ~/Library/Sounds, removing")
                do {
                    try FileManager.default.removeItem(at: newURL)
                } catch {
                    seal.reject(SoundError(soundURL: nil, kind: .deleteError, underlying: error))
                }
            }

            do {
                try FileManager.default.copyItem(at: soundURL, to: newURL)
            } catch {
                seal.reject(SoundError(soundURL: nil, kind: .copyError, underlying: error))
            }

            DispatchQueue.main.async {
                if self.form.rowBy(tag: newURL.lastPathComponent) === nil,
                   let section = self.form.sectionBy(tag: formSectionTag) {
                    section.append(self.getSoundRow(newURL))
                }
            }

            seal.fulfill(newURL)
        }
    }

    func ensureDuration(_ soundURL: URL) -> Bool {
        let duration = Double(CMTimeGetSeconds(AVURLAsset(url: soundURL).duration))
        return duration > 0.0 && duration <= 30.0
    }

    func showAlert(_ message: String, _ title: String? = L10n.errorLabel, popoverView: UIView? = nil) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: L10n.okLabel, style: .default, handler: nil))
        present(alert, animated: true, completion: nil)
        if let view = popoverView {
            alert.popoverPresentationController?.sourceView = view
        }
    }

    @objc private func help() {
        openURLInBrowser(
            URL(string: "https://companion.home-assistant.io/app/ios/notifications-sounds")!,
            self
        )
    }
}

extension FileManager {
    func isDirectory(_ url: URL) -> Bool? {
        var isDir = ObjCBool(false)
        if fileExists(atPath: url.path, isDirectory: &isDir) {
            return isDir.boolValue
        }
        return nil
    }
}

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

    public var errorDescription: String? {
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
