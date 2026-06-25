import Combine
import Shared
import SwiftUI
import UIKit

struct KioskScreensaverView: View {
    let settings: KioskScreensaverSettings
    let onWake: () -> Void

    var body: some View {
        ZStack {
            Color.black
                .opacity(settings.mode == .dim ? (1 - clampedDimLevel) : 1)

            PixelShiftContainer(enabled: settings.pixelShiftEnabled) {
                content
            }
        }
        .ignoresSafeArea()
        .contentShape(Rectangle())
        .onTapGesture(perform: onWake)
    }

    @ViewBuilder
    private var content: some View {
        if settings.mode == .clock {
            clockView
        }
    }

    private var clampedDimLevel: Double {
        min(max(settings.dimLevel, 0), 1)
    }

    @ViewBuilder
    private var clockView: some View {
        if settings.showSeconds {
            TimelineView(.periodic(from: Date(), by: 1)) { context in
                clockContent(for: context.date)
            }
        } else {
            TimelineView(.everyMinute) { context in
                clockContent(for: context.date)
            }
        }
    }

    private func clockContent(for date: Date) -> some View {
        VStack(spacing: clockFontSize * 0.1) {
            Text(date.formatted(date: .omitted, time: settings.showSeconds ? .standard : .shortened))
                .font(.system(size: clockFontSize, weight: .thin, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.5)

            if settings.showDate {
                Text(date.formatted(date: .complete, time: .omitted))
                    .font(.system(size: clockFontSize * 0.22, weight: .regular, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
        }
        .foregroundStyle(.white)
        .padding(DesignSystem.Spaces.three)
    }

    private var clockFontSize: CGFloat {
        switch settings.clockStyle {
        case .large: return 120
        case .medium: return 84
        case .small: return 56
        }
    }
}

// MARK: - Pixel shift

private struct PixelShiftContainer<Content: View>: View {
    let enabled: Bool
    @ViewBuilder var content: () -> Content

    private static var interval: TimeInterval { 60 }

    var body: some View {
        if enabled {
            TimelineView(.periodic(from: Date(), by: Self.interval)) { context in
                let shift = Self.offset(for: context.date)
                content()
                    .offset(x: shift.width, y: shift.height)
                    .animation(.easeInOut(duration: 2), value: shift)
            }
        } else {
            content()
        }
    }

    private static func offset(for date: Date) -> CGSize {
        let boxPositions = positions
        let step = Int(date.timeIntervalSinceReferenceDate / interval)
        let index = ((step % boxPositions.count) + boxPositions.count) % boxPositions.count
        return boxPositions[index]
    }

    private static let positions: [CGSize] = {
        let distance: CGFloat = 12
        return [
            CGSize(width: 0, height: -distance),
            CGSize(width: distance, height: -distance),
            CGSize(width: distance, height: 0),
            CGSize(width: distance, height: distance),
            CGSize(width: 0, height: distance),
            CGSize(width: -distance, height: distance),
            CGSize(width: -distance, height: 0),
            CGSize(width: -distance, height: -distance),
        ]
    }()
}

// MARK: - Idle controller

/// Drives the screensaver: starts an inactivity timer (per `timeToStart`) and toggles `isActive`. Activity
/// reported via `recordActivity()` resets the timer; `wake()` dismisses an active screensaver.
final class KioskScreensaverController: ObservableObject {
    @Published private(set) var isActive = false
    @Published private(set) var screensaver = KioskScreensaverSettings()

    private var isEnabled = false
    private var isCameraOverlayVisible = false
    private var brightnessBeforeDimming: CGFloat?
    private var idleTimer: Timer?
    private var cancellables = Set<AnyCancellable>()

    init() {
        Current.kiosk.settingsPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.apply($0) }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                self?.restartIdleTimer()
                self?.updateBrightness()
            }
            .store(in: &cancellables)
        NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)
            .sink { [weak self] _ in
                self?.idleTimer?.invalidate()
                self?.restoreBrightness()
            }
            .store(in: &cancellables)

        Current.kiosk.cameraOverlayVisiblePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] visible in
                self?.isCameraOverlayVisible = visible
                self?.updateBrightness()
            }
            .store(in: &cancellables)

        Current.kiosk.screensaverCommandPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] command in
                switch command {
                case .show: self?.show()
                case .hide: self?.wake()
                }
            }
            .store(in: &cancellables)
    }

    deinit {
        idleTimer?.invalidate()
        restoreBrightness()
    }

    func recordActivity() {
        guard !isActive else { return }
        restartIdleTimer()
    }

    func show() {
        guard isEnabled else { return }
        idleTimer?.invalidate()
        idleTimer = nil
        isActive = true
        updateBrightness()
    }

    func wake() {
        isActive = false
        updateBrightness()
        restartIdleTimer()
    }

    private func apply(_ settings: KioskSettings) {
        screensaver = settings.screensaver
        isEnabled = settings.enabled && settings.screensaver.enabled
        if !isEnabled {
            isActive = false
        }
        restartIdleTimer()
        updateBrightness()
    }

    private func restartIdleTimer() {
        idleTimer?.invalidate()
        idleTimer = nil
        guard isEnabled, !isActive, let interval = screensaver.timeToStart.timeInterval else { return }
        idleTimer = Timer.scheduledTimer(
            withTimeInterval: interval,
            repeats: false
        ) { [weak self] _ in
            guard let self, isEnabled else { return }
            isActive = true
            updateBrightness()
        }
    }

    private func updateBrightness() {
        #if os(iOS) && !targetEnvironment(macCatalyst)
        guard shouldDimBrightness else {
            restoreBrightness()
            return
        }

        if brightnessBeforeDimming == nil {
            brightnessBeforeDimming = UIScreen.main.brightness
        }

        UIScreen.main.brightness = CGFloat(min(max(screensaver.dimLevel, 0), 1))
        #endif
    }

    private var shouldDimBrightness: Bool {
        #if os(iOS) && !targetEnvironment(macCatalyst)
        UIApplication.shared.applicationState == .active &&
            isEnabled &&
            isActive &&
            screensaver.dimEnabled &&
            !isCameraOverlayVisible
        #else
        false
        #endif
    }

    private func restoreBrightness() {
        #if os(iOS) && !targetEnvironment(macCatalyst)
        guard let brightnessBeforeDimming else { return }
        UIScreen.main.brightness = brightnessBeforeDimming
        self.brightnessBeforeDimming = nil
        #endif
    }
}

struct KioskActivityDetector: UIViewRepresentable {
    let onActivity: () -> Void

    func makeUIView(context: Context) -> UIView {
        let view = ActivityDetectingView()
        view.onActivity = onActivity
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        (uiView as? ActivityDetectingView)?.onActivity = onActivity
    }
}

private final class ActivityDetectingView: UIView, UIGestureRecognizerDelegate {
    var onActivity: (() -> Void)?
    private weak var recognizer: AnyTouchRecognizer?

    override func didMoveToWindow() {
        super.didMoveToWindow()

        if let recognizer {
            recognizer.view?.removeGestureRecognizer(recognizer)
            self.recognizer = nil
        }

        guard let window else { return }
        let recognizer = AnyTouchRecognizer()
        recognizer.onTouch = { [weak self] in self?.onActivity?() }
        recognizer.cancelsTouchesInView = false
        recognizer.delaysTouchesBegan = false
        recognizer.delaysTouchesEnded = false
        recognizer.delegate = self
        window.addGestureRecognizer(recognizer)
        self.recognizer = recognizer
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        true
    }
}

private final class AnyTouchRecognizer: UIGestureRecognizer {
    var onTouch: (() -> Void)?

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesBegan(touches, with: event)
        onTouch?()
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesMoved(touches, with: event)
        onTouch?()
    }
}
