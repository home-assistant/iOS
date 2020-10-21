// swiftlint:disable all
// Generated using SwiftGen — https://github.com/SwiftGen/SwiftGen

// swiftlint:disable sorted_imports
import Foundation
import UIKit

// swiftlint:disable superfluous_disable_command
// swiftlint:disable file_length implicit_return

// MARK: - Storyboard Scenes

// swiftlint:disable explicit_type_interface identifier_name line_length type_body_length type_name
internal enum StoryboardScene {
  internal enum ClientEvents: StoryboardType {
    internal static let storyboardName = "ClientEvents"

    internal static let clientEventsList = SceneType<HomeAssistant.ClientEventTableViewController>(storyboard: ClientEvents.self, identifier: "clientEventsList")
  }
  internal enum Onboarding: StoryboardType {
    internal static let storyboardName = "Onboarding"

    internal static let initialScene = InitialSceneType<HomeAssistant.OnboardingNavigationViewController>(storyboard: Onboarding.self)

    internal static let discoverInstances = SceneType<HomeAssistant.DiscoverInstancesViewController>(storyboard: Onboarding.self, identifier: "discoverInstances")

    internal static let manualSetup = SceneType<HomeAssistant.ManualSetupViewController>(storyboard: Onboarding.self, identifier: "manualSetup")

    internal static let navController = SceneType<HomeAssistant.OnboardingNavigationViewController>(storyboard: Onboarding.self, identifier: "navController")

    internal static let permissions = SceneType<HomeAssistant.PermissionsViewController>(storyboard: Onboarding.self, identifier: "permissions")

    internal static let welcome = SceneType<HomeAssistant.WelcomeViewController>(storyboard: Onboarding.self, identifier: "welcome")
  }
}
// swiftlint:enable explicit_type_interface identifier_name line_length type_body_length type_name

// MARK: - Implementation Details

internal protocol StoryboardType {
  static var storyboardName: String { get }
}

internal extension StoryboardType {
  static var storyboard: UIStoryboard {
    let name = self.storyboardName
    return UIStoryboard(name: name, bundle: BundleToken.bundle)
  }
}

internal struct SceneType<T: UIViewController> {
  internal let storyboard: StoryboardType.Type
  internal let identifier: String

  internal func instantiate() -> T {
    let identifier = self.identifier
    guard let controller = storyboard.storyboard.instantiateViewController(withIdentifier: identifier) as? T else {
      fatalError("ViewController '\(identifier)' is not of the expected class \(T.self).")
    }
    return controller
  }

  @available(iOS 13.0, tvOS 13.0, *)
  internal func instantiate(creator block: @escaping (NSCoder) -> T?) -> T {
    return storyboard.storyboard.instantiateViewController(identifier: identifier, creator: block)
  }
}

internal struct InitialSceneType<T: UIViewController> {
  internal let storyboard: StoryboardType.Type

  internal func instantiate() -> T {
    guard let controller = storyboard.storyboard.instantiateInitialViewController() as? T else {
      fatalError("ViewController is not of the expected class \(T.self).")
    }
    return controller
  }

  @available(iOS 13.0, tvOS 13.0, *)
  internal func instantiate(creator block: @escaping (NSCoder) -> T?) -> T {
    guard let controller = storyboard.storyboard.instantiateInitialViewController(creator: block) else {
      fatalError("Storyboard \(storyboard.storyboardName) does not have an initial scene.")
    }
    return controller
  }
}

// swiftlint:disable convenience_type
private final class BundleToken {
  static let bundle: Bundle = {
    #if SWIFT_PACKAGE
    return Bundle.module
    #else
    return Bundle(for: BundleToken.self)
    #endif
  }()
}
// swiftlint:enable convenience_type
