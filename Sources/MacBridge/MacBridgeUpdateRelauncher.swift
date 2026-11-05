import AppKit
import Darwin
import Foundation
import os.log

final class MacBridgeUpdateRelauncher {
    static let shared = MacBridgeUpdateRelauncher()

    enum WindowState: String {
        case foreground
        case background
    }

    static let relaunchModeArgument = "--ha-relaunch-mode"
    static let stateFileName = "update-relauncher-state"
    static let ownerFileName = "update-relauncher-owner"
    static let logFileName = "update-relauncher.log"

    static let watcherScript = """
    bundle="$1"; original="$2"; state_file="$3"; owner_file="$4"
    marker=$(cat)
    if [ "$marker" = "quit" ]; then
        echo "app quit normally; not relaunching"
        exit 0
    fi
    echo "app ended without quitting; waiting for $bundle to change from version $original"
    attempts=0
    while [ "$attempts" -lt 120 ]; do
        current=$(/usr/bin/plutil -extract CFBundleVersion raw -o - "$bundle/Contents/Info.plist" 2>/dev/null)
        if [ -n "$current" ] && [ "$current" != "$original" ]; then
            sleep 5
            state=$(cat "$state_file" 2>/dev/null)
            echo "updated to version $current; relaunching in ${state:-foreground}"
            retries=0
            while [ "$retries" -lt 6 ]; do
                if [ "$(cat "$owner_file" 2>/dev/null)" != "$$" ]; then
                    echo "superseded by a newer watcher; not relaunching"
                    exit 0
                fi
                if [ "$state" = "background" ]; then
                    /usr/bin/open -g "$bundle" --args --ha-relaunch-mode background && exit 0
                else
                    /usr/bin/open "$bundle" --args --ha-relaunch-mode foreground && exit 0
                fi
                sleep 5
                retries=$((retries + 1))
            done
            echo "could not relaunch"
            exit 1
        fi
        sleep 5
        attempts=$((attempts + 1))
    done
    echo "no update seen; not relaunching"
    """

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "MacBridge",
        category: "update-relauncher"
    )

    static var isBackgroundRelaunch: Bool {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: relaunchModeArgument),
              arguments.indices.contains(index + 1) else {
            return false
        }
        return arguments[index + 1] == WindowState.background.rawValue
    }

    var isKeepingAppInBackground: Bool {
        Self.isBackgroundRelaunch && !hasVisibleWindows
    }

    private var writeDescriptor: Int32 = -1
    private var stateFileURL: URL?
    private var lastWrittenState: WindowState?
    private var stateWriteScheduled = false

    @discardableResult
    func start() -> Bool {
        guard !Bundle.main.isRunningInExtension, !Self.isDebuggerAttached else {
            return false
        }
        guard let version = Bundle.main.infoDictionary?["CFBundleVersion"] as? String,
              let directory = try? FileManager.default.url(
                  for: .applicationSupportDirectory,
                  in: .userDomainMask,
                  appropriateFor: nil,
                  create: true
              ) else {
            return false
        }
        return start(bundleURL: Bundle.main.bundleURL, version: version, stateDirectory: directory)
    }

    @discardableResult
    func start(bundleURL: URL, version: String, stateDirectory: URL) -> Bool {
        guard writeDescriptor < 0 else { return true }

        stateFileURL = stateDirectory.appendingPathComponent(Self.stateFileName)
        writeStateIfChanged()

        guard let watcherPid = spawnWatcher(
            bundlePath: bundleURL.path,
            version: version,
            stateFilePath: stateDirectory.appendingPathComponent(Self.stateFileName).path,
            ownerFilePath: stateDirectory.appendingPathComponent(Self.ownerFileName).path,
            logFilePath: stateDirectory.appendingPathComponent(Self.logFileName).path
        ) else {
            return false
        }

        do {
            try String(watcherPid).write(
                to: stateDirectory.appendingPathComponent(Self.ownerFileName),
                atomically: true,
                encoding: .utf8
            )
        } catch {
            logger.error("writing watcher owner failed: \(error.localizedDescription)")
        }

        observeWindowVisibility()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationWillTerminate),
            name: NSApplication.willTerminateNotification,
            object: nil
        )
        return true
    }

    var hasVisibleWindows: Bool {
        !NSApplication.shared.isHidden && NSApplication.shared.windows.contains { window in
            window.level == .normal && window.canBecomeKey && window.isVisible && !window.isMiniaturized
        }
    }

    private func spawnWatcher(
        bundlePath: String,
        version: String,
        stateFilePath: String,
        ownerFilePath: String,
        logFilePath: String
    ) -> pid_t? {
        var descriptors: [Int32] = [-1, -1]
        guard pipe(&descriptors) == 0 else {
            logger.error("pipe failed: \(errno)")
            return nil
        }
        let readEnd = descriptors[0]
        let writeEnd = descriptors[1]
        _ = fcntl(writeEnd, F_SETFD, FD_CLOEXEC)
        _ = fcntl(writeEnd, F_SETNOSIGPIPE, 1)

        var fileActions: posix_spawn_file_actions_t?
        posix_spawn_file_actions_init(&fileActions)
        defer { posix_spawn_file_actions_destroy(&fileActions) }
        posix_spawn_file_actions_adddup2(&fileActions, readEnd, STDIN_FILENO)
        posix_spawn_file_actions_addopen(&fileActions, STDOUT_FILENO, logFilePath, O_WRONLY | O_CREAT | O_TRUNC, 0o644)
        posix_spawn_file_actions_adddup2(&fileActions, STDOUT_FILENO, STDERR_FILENO)

        var attributes: posix_spawnattr_t?
        posix_spawnattr_init(&attributes)
        defer { posix_spawnattr_destroy(&attributes) }
        posix_spawnattr_setflags(&attributes, Int16(POSIX_SPAWN_SETSID | POSIX_SPAWN_CLOEXEC_DEFAULT))

        let arguments = [
            "/bin/sh", "-c", Self.watcherScript, "update-relauncher", bundlePath, version, stateFilePath, ownerFilePath,
        ]
        var argv: [UnsafeMutablePointer<CChar>?] = arguments.map { strdup($0) }
        argv.append(nil)
        defer { argv.forEach { free($0) } }

        var envp: [UnsafeMutablePointer<CChar>?] = ProcessInfo.processInfo.environment.map { key, value in
            strdup("\(key)=\(value)")
        }
        envp.append(nil)
        defer { envp.forEach { free($0) } }

        var pid: pid_t = 0
        let status = posix_spawn(&pid, "/bin/sh", &fileActions, &attributes, argv, envp)
        close(readEnd)
        guard status == 0 else {
            close(writeEnd)
            logger.error("posix_spawn failed: \(status)")
            return nil
        }

        writeDescriptor = writeEnd
        logger.info("watcher pid \(pid) for \(bundlePath) version \(version)")
        return pid
    }

    private func observeWindowVisibility() {
        let names: [Notification.Name] = [
            NSWindow.didBecomeKeyNotification,
            NSWindow.didResignKeyNotification,
            NSWindow.willCloseNotification,
            NSWindow.didMiniaturizeNotification,
            NSWindow.didDeminiaturizeNotification,
            NSApplication.didHideNotification,
            NSApplication.didUnhideNotification,
            NSApplication.didBecomeActiveNotification,
            NSApplication.didResignActiveNotification,
            NSApplication.didFinishRestoringWindowsNotification,
        ]
        for name in names {
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(windowVisibilityMayHaveChanged),
                name: name,
                object: nil
            )
        }
    }

    @objc private func windowVisibilityMayHaveChanged() {
        guard !stateWriteScheduled else { return }
        stateWriteScheduled = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [self] in
            stateWriteScheduled = false
            writeStateIfChanged()
        }
    }

    private func writeStateIfChanged() {
        guard let stateFileURL else { return }
        let state: WindowState = hasVisibleWindows ? .foreground : .background
        guard state != lastWrittenState else { return }
        do {
            try state.rawValue.write(to: stateFileURL, atomically: true, encoding: .utf8)
            lastWrittenState = state
        } catch {
            logger.error("writing window state failed: \(error.localizedDescription)")
        }
    }

    @objc private func applicationWillTerminate() {
        guard writeDescriptor >= 0 else { return }
        _ = "quit".withCString { write(writeDescriptor, $0, strlen($0)) }
        close(writeDescriptor)
        writeDescriptor = -1
    }

    private static var isDebuggerAttached: Bool {
        var info = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.stride
        var name: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()]
        guard sysctl(&name, UInt32(name.count), &info, &size, nil, 0) == 0 else { return false }
        return (info.kp_proc.p_flag & P_TRACED) != 0
    }
}
