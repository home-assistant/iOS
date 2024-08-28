#if os(iOS)
import GRDB
import RealmSwift
import UIKit
import XCGLogger
import ZIPFoundation

public extension XCGLogger {
    var exportTitle: String {
        if Current.isCatalyst {
            return L10n.Settings.Developer.ShowLogFiles.title
        } else {
            return L10n.Settings.Developer.ExportLogFiles.title
        }
    }

    func export(from source: UIViewController, sender: UIView, openURLHandler: (URL) -> Void) {
        Current.Log.verbose("Logs directory is: \(Shared.AppConstants.LogsDirectory)")

        guard !Current.isCatalyst else {
            // on Catalyst we can just open the directory to get to Finder
            openURLHandler(Shared.AppConstants.LogsDirectory)
            return
        }

        let fileManager = FileManager.default

        let fileName = DateFormatter(
            withFormat: "yyyy-MM-dd'_'HH'.'mm'.'ssZ'.logs.zip'",
            locale: "en_US_POSIX"
        ).string(from: Date())

        Current.Log.debug("Exporting logs as filename \(fileName)")

        let archiveURL = fileManager.temporaryDirectory.appendingPathComponent(fileName, isDirectory: false)
        let archive = Archive(url: archiveURL, accessMode: .create)!

        do {
            if let backupURL = Realm.backup() {
                try archive.addEntry(
                    with: backupURL.lastPathComponent,
                    relativeTo: backupURL.deletingLastPathComponent()
                )
            }

            // In case watch config does not exist it can safely fail
            do {
                try archive.addEntry(
                    with: AppConstants.watchGRDBFile.lastPathComponent,
                    fileURL: AppConstants.watchGRDBFile
                )
            } catch {
                Current.Log
                    .info("No watch config database file added to export logs, error: \(error.localizedDescription)")
            }

            for logFile in try fileManager.contentsOfDirectory(
                at: Shared.AppConstants.LogsDirectory,
                includingPropertiesForKeys: nil
            ) {
                try archive.addEntry(
                    with: logFile.lastPathComponent,
                    relativeTo: logFile.deletingLastPathComponent()
                )
            }

            let controller = UIActivityViewController(activityItems: [archiveURL], applicationActivities: nil)

            controller.completionWithItemsHandler = { type, completed, _, _ in
                let didCancelEntirely = type == nil && !completed
                let didCompleteEntirely = completed

                if didCancelEntirely || didCompleteEntirely {
                    try? fileManager.removeItem(at: archiveURL)
                }
            }

            with(controller.popoverPresentationController) {
                $0?.sourceView = sender
            }

            source.present(controller, animated: true, completion: nil)
        } catch {
            let alert = UIAlertController(title: nil, message: error.localizedDescription, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: L10n.okLabel, style: .cancel, handler: nil))
            source.present(alert, animated: true, completion: nil)
        }
    }
}
#endif
