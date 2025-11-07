import Shared
import UIKit

enum StatusBarButtonsConfigurator {
    // MARK: - Debug Toggle

    #if DEBUG
    /// Styling mode for debugging purposes
    enum StylingMode {
        case automatic // Use system version detection
        case forceMacOS26 // Force macOS 26 glass effect styling
        case forceLegacy // Force legacy solid styling
    }

    /// Set styling mode for debugging (only available in DEBUG builds)
    static var debugStylingMode: StylingMode = .automatic
    #endif

    // MARK: - Constants

    private enum Constants {
        static let buttonSize: CGFloat = 14
        static let containerSize: CGFloat = 20
        static let cornerRadius: CGFloat = 10
        static let containerPadding: CGFloat = 4
        static let pillButtonSpacing: CGFloat = 4

        enum Styling {
            static let shadowOpacity: Float = 0.1
            static let shadowRadius: CGFloat = 2
            static let shadowOffset = CGSize(width: 0, height: 1)
            static let borderWidth: CGFloat = 0.5
        }

        enum Positioning {
            static let macOS26LeftOffset: CGFloat = 78
            static let macOS26Height: CGFloat = 30
            static let macOSLegacyLeftOffset: CGFloat = 68
            static let macOSLegacyHeight: CGFloat = 27
        }
    }

    struct Actions {
        let refresh: () -> Void
        let openServer: (Server) -> Void
        let openInSafari: () -> Void
        let goBack: () -> Void
        let goForward: () -> Void
        let copy: () -> Void
        let paste: () -> Void
    }

    struct Configuration {
        let server: Server
        let servers: [Server]
        let actions: Actions
    }

    // MARK: - Public

    /// Sets up status bar buttons and returns the main stack view to be stored
    static func setupButtons(in statusBarView: UIView, configuration: Configuration) -> UIStackView {
        let picker = createServerPicker(configuration: configuration)

        let arrangedSubviews: [UIView] = configuration.servers.count > 1 ? [picker] : []

        let stackView = UIStackView(arrangedSubviews: arrangedSubviews)
        stackView.axis = .horizontal
        stackView.spacing = DesignSystem.Spaces.one

        statusBarView.addSubview(stackView)
        stackView.translatesAutoresizingMaskIntoConstraints = false

        let leftButtonStack = createLeftNavigationButtons(configuration: configuration)
        statusBarView.addSubview(leftButtonStack)

        let rightButtonStack = createRightButtons(configuration: configuration)
        statusBarView.addSubview(rightButtonStack)

        setupConstraints(
            stackView: stackView,
            leftButtonStack: leftButtonStack,
            rightButtonStack: rightButtonStack,
            statusBarView: statusBarView
        )

        return stackView
    }

    // MARK: - Private

    private static func createServerPicker(configuration: Configuration) -> UIView {
        let serverPickerButton = UIButton(type: .system)
        serverPickerButton.setTitle(configuration.server.info.name, for: .normal)
        serverPickerButton.translatesAutoresizingMaskIntoConstraints = false

        // Remove default button background styling
        serverPickerButton.backgroundColor = .clear

        let serverMenuActions = configuration.servers.map { server in
            UIAction(title: server.info.name, handler: { _ in
                configuration.actions.openServer(server)
            })
        }

        // Using UIMenu since UIPickerView is not available on Catalyst
        serverPickerButton.menu = UIMenu(title: L10n.WebView.ServerSelection.title, children: serverMenuActions)
        serverPickerButton.showsMenuAsPrimaryAction = true

        // Match navigation arrows color
        let backButton = WebViewControllerButtons.backButton
        serverPickerButton.tintColor = backButton.tintColor

        serverPickerButton.configuration = {
            var buttonConfiguration = UIButton.Configuration.plain()
            buttonConfiguration.background.backgroundColor = .clear
            buttonConfiguration.baseForegroundColor = backButton.tintColor
            return buttonConfiguration
        }()

        // Wrap picker in a container with glass effect
        let serverPickerContainer = UIView()
        serverPickerContainer.backgroundColor = containerBackgroundColor()
        serverPickerContainer.layer.cornerRadius = Constants.cornerRadius
        serverPickerContainer.translatesAutoresizingMaskIntoConstraints = false

        applyGlassEffect(to: serverPickerContainer)

        serverPickerContainer.addSubview(serverPickerButton)
        serverPickerButton.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            serverPickerContainer.heightAnchor.constraint(equalToConstant: Constants.containerSize),
            serverPickerButton.leadingAnchor.constraint(
                equalTo: serverPickerContainer.leadingAnchor,
                constant: Constants.containerPadding * 2
            ),
            serverPickerButton.trailingAnchor.constraint(
                equalTo: serverPickerContainer.trailingAnchor,
                constant: -Constants.containerPadding * 2
            ),
            serverPickerButton.centerYAnchor.constraint(equalTo: serverPickerContainer.centerYAnchor),
        ])

        return serverPickerContainer
    }

    private static func createLeftNavigationButtons(configuration: Configuration) -> UIStackView {
        let openInSafariButton = WebViewControllerButtons.openInSafariButton
        openInSafariButton.addAction(UIAction { _ in
            configuration.actions.openInSafari()
        }, for: .touchUpInside)
        let openInSafariContainer = wrapButtonInCircle(openInSafariButton)

        let backButton = WebViewControllerButtons.backButton
        backButton.addAction(UIAction { _ in
            configuration.actions.goBack()
        }, for: .touchUpInside)

        let forwardButton = WebViewControllerButtons.forwardButton
        forwardButton.addAction(UIAction { _ in
            configuration.actions.goForward()
        }, for: .touchUpInside)

        let navigationPillContainer = wrapNavigationButtonsInPill(backButton: backButton, forwardButton: forwardButton)

        let reloadButton = UIButton(type: .custom)
        reloadButton.setImage(UIImage(systemSymbol: .arrowClockwise), for: .normal)
        reloadButton.tintColor = backButton.tintColor
        reloadButton.addAction(UIAction { _ in
            configuration.actions.refresh()
        }, for: .touchUpInside)
        let reloadContainer = wrapButtonInCircle(reloadButton)

        let buttonStack = UIStackView(arrangedSubviews: [
            openInSafariContainer,
            navigationPillContainer,
            reloadContainer,
        ])
        buttonStack.axis = .horizontal
        buttonStack.spacing = DesignSystem.Spaces.one
        buttonStack.translatesAutoresizingMaskIntoConstraints = false
        buttonStack.alignment = .center

        return buttonStack
    }

    private static func createRightButtons(configuration: Configuration) -> UIStackView {
        let copyButton = WebViewControllerButtons.copyButton
        copyButton.addAction(UIAction { _ in
            configuration.actions.copy()
        }, for: .touchUpInside)
        let copyContainer = wrapButtonInCircle(copyButton)

        let pasteButton = WebViewControllerButtons.pasteButton
        pasteButton.addAction(UIAction { _ in
            configuration.actions.paste()
        }, for: .touchUpInside)
        let pasteContainer = wrapButtonInCircle(pasteButton)

        let buttonStack = UIStackView(arrangedSubviews: [
            copyContainer,
            pasteContainer,
        ])
        buttonStack.axis = .horizontal
        buttonStack.spacing = DesignSystem.Spaces.one
        buttonStack.translatesAutoresizingMaskIntoConstraints = false
        buttonStack.alignment = .center

        return buttonStack
    }

    /// Wraps back and forward buttons in a pill-shaped container
    private static func wrapNavigationButtonsInPill(backButton: UIButton, forwardButton: UIButton) -> UIView {
        let navigationPillContainer = UIView()
        navigationPillContainer.backgroundColor = containerBackgroundColor()
        navigationPillContainer.layer.cornerRadius = Constants.cornerRadius
        navigationPillContainer.translatesAutoresizingMaskIntoConstraints = false

        applyGlassEffect(to: navigationPillContainer)

        backButton.translatesAutoresizingMaskIntoConstraints = false
        forwardButton.translatesAutoresizingMaskIntoConstraints = false

        navigationPillContainer.addSubview(backButton)
        navigationPillContainer.addSubview(forwardButton)

        NSLayoutConstraint.activate([
            navigationPillContainer.heightAnchor.constraint(equalToConstant: Constants.containerSize),

            backButton.leadingAnchor.constraint(
                equalTo: navigationPillContainer.leadingAnchor,
                constant: Constants.containerPadding
            ),
            backButton.centerYAnchor.constraint(equalTo: navigationPillContainer.centerYAnchor),
            backButton.widthAnchor.constraint(equalToConstant: Constants.buttonSize),
            backButton.heightAnchor.constraint(equalToConstant: Constants.buttonSize),

            forwardButton.leadingAnchor.constraint(
                equalTo: backButton.trailingAnchor,
                constant: Constants.pillButtonSpacing
            ),
            forwardButton.trailingAnchor.constraint(
                equalTo: navigationPillContainer.trailingAnchor,
                constant: -Constants.containerPadding
            ),
            forwardButton.centerYAnchor.constraint(equalTo: navigationPillContainer.centerYAnchor),
            forwardButton.widthAnchor.constraint(equalToConstant: Constants.buttonSize),
            forwardButton.heightAnchor.constraint(equalToConstant: Constants.buttonSize),
        ])

        return navigationPillContainer
    }

    /// Wraps a button in a circular container with consistent size
    private static func wrapButtonInCircle(_ button: UIButton) -> UIView {
        let buttonCircleContainer = UIView()
        buttonCircleContainer.backgroundColor = containerBackgroundColor()
        buttonCircleContainer.layer.cornerRadius = Constants.cornerRadius
        buttonCircleContainer.translatesAutoresizingMaskIntoConstraints = false

        applyGlassEffect(to: buttonCircleContainer)

        buttonCircleContainer.addSubview(button)
        button.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            buttonCircleContainer.widthAnchor.constraint(equalToConstant: Constants.containerSize),
            buttonCircleContainer.heightAnchor.constraint(equalToConstant: Constants.containerSize),
            button.centerXAnchor.constraint(equalTo: buttonCircleContainer.centerXAnchor),
            button.centerYAnchor.constraint(equalTo: buttonCircleContainer.centerYAnchor),
            button.widthAnchor.constraint(equalToConstant: Constants.buttonSize),
            button.heightAnchor.constraint(equalToConstant: Constants.buttonSize),
        ])

        return buttonCircleContainer
    }

    // MARK: - Styling Helpers

    /// Determines if macOS 26 styling should be used (respects debug toggle in DEBUG builds)
    private static func shouldUseMacOS26Styling() -> Bool {
        #if DEBUG
        switch debugStylingMode {
        case .automatic:
            break // Fall through to system detection
        case .forceMacOS26:
            return true
        case .forceLegacy:
            return false
        }
        #endif

        if #available(macOS 26.0, *) {
            return true
        } else {
            return false
        }
    }

    /// Returns the appropriate background color based on macOS version
    private static func containerBackgroundColor() -> UIColor {
        if shouldUseMacOS26Styling() {
            // Semi-transparent background for glass effect
            return UIColor.systemGray5.withAlphaComponent(0.3)
        } else {
            return UIColor.systemGray5
        }
    }

    /// Applies glass effect styling to a container view for macOS 26.0+
    private static func applyGlassEffect(to view: UIView) {
        if shouldUseMacOS26Styling() {
            // Add blur effect
            let blurEffect = UIBlurEffect(style: .systemMaterial)
            let glassBlurView = UIVisualEffectView(effect: blurEffect)
            glassBlurView.frame = view.bounds
            glassBlurView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            glassBlurView.layer.cornerRadius = Constants.cornerRadius
            glassBlurView.clipsToBounds = true
            view.insertSubview(glassBlurView, at: 0)

            // Add subtle border
            view.layer.borderWidth = Constants.Styling.borderWidth
            view.layer.borderColor = UIColor.white.withAlphaComponent(0.2).cgColor

            // Add subtle shadow for depth
            view.layer.shadowColor = UIColor.black.cgColor
            view.layer.shadowOpacity = Constants.Styling.shadowOpacity
            view.layer.shadowOffset = Constants.Styling.shadowOffset
            view.layer.shadowRadius = Constants.Styling.shadowRadius
            view.layer.masksToBounds = false
        } else {
            // Legacy styling - simple solid background
            // Background color already set, no additional effects needed
        }
    }

    private static func setupConstraints(
        stackView: UIStackView,
        leftButtonStack: UIStackView,
        rightButtonStack: UIStackView,
        statusBarView: UIView
    ) {
        // Position server picker and reload button on the far right
        NSLayoutConstraint.activate([
            stackView.rightAnchor.constraint(equalTo: statusBarView.rightAnchor, constant: -DesignSystem.Spaces.half),
            stackView.topAnchor.constraint(equalTo: statusBarView.topAnchor, constant: DesignSystem.Spaces.half),
        ])

        // Position copy/paste buttons to the left of server picker
        NSLayoutConstraint.activate([
            rightButtonStack.rightAnchor.constraint(equalTo: stackView.leftAnchor, constant: -DesignSystem.Spaces.one),
            rightButtonStack.topAnchor.constraint(equalTo: statusBarView.topAnchor),
        ])

        // Position navigation buttons on the left side
        if shouldUseMacOS26Styling() {
            NSLayoutConstraint.activate([
                leftButtonStack.leftAnchor.constraint(
                    equalTo: statusBarView.leftAnchor,
                    constant: Constants.Positioning.macOS26LeftOffset
                ),
                leftButtonStack.topAnchor.constraint(equalTo: statusBarView.topAnchor),
                leftButtonStack.heightAnchor.constraint(equalToConstant: Constants.Positioning.macOS26Height),
                rightButtonStack.heightAnchor.constraint(equalToConstant: Constants.Positioning.macOS26Height),
            ])
        } else {
            NSLayoutConstraint.activate([
                leftButtonStack.leftAnchor.constraint(
                    equalTo: statusBarView.leftAnchor,
                    constant: Constants.Positioning.macOSLegacyLeftOffset
                ),
                leftButtonStack.topAnchor.constraint(equalTo: statusBarView.topAnchor),
                leftButtonStack.heightAnchor.constraint(equalToConstant: Constants.Positioning.macOSLegacyHeight),
                rightButtonStack.heightAnchor.constraint(equalToConstant: Constants.Positioning.macOSLegacyHeight),
            ])
        }
    }
}
