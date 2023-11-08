// swiftlint:disable all
// Generated using SwiftGen — https://github.com/SwiftGen/SwiftGen

import Foundation

// swiftlint:disable superfluous_disable_command
// swiftlint:disable file_length

// MARK: - Plist Files

// swiftlint:disable identifier_name line_length type_body_length
internal enum SharedPlistFiles {
  internal enum Info {
    private static let _document = PlistDocument(path: "Info.plist")
    internal static let cfBundleDevelopmentRegion: String = _document["CFBundleDevelopmentRegion"]
    internal static let cfBundleExecutable: String = _document["CFBundleExecutable"]
    internal static let cfBundleIdentifier: String = _document["CFBundleIdentifier"]
    internal static let cfBundleInfoDictionaryVersion: String = _document["CFBundleInfoDictionaryVersion"]
    internal static let cfBundleName: String = _document["CFBundleName"]
    internal static let cfBundlePackageType: String = _document["CFBundlePackageType"]
    internal static let cfBundleShortVersionString: String = _document["CFBundleShortVersionString"]
    internal static let cfBundleVersion: String = _document["CFBundleVersion"]
    internal static let nsPrincipalClass: String = _document["NSPrincipalClass"]
  }
}
// swiftlint:enable identifier_name line_length type_body_length

// MARK: - Implementation Details

private func arrayFromPlist<T>(at path: String) -> [T] {
  guard let url = BundleToken.bundle.url(forResource: path, withExtension: nil),
    let data = NSArray(contentsOf: url) as? [T] else {
    fatalError("Unable to load PLIST at path: \(path)")
  }
  return data
}

private struct PlistDocument {
  let data: [String: Any]

  init(path: String) {
    guard let url = BundleToken.bundle.url(forResource: path, withExtension: nil),
      let data = NSDictionary(contentsOf: url) as? [String: Any] else {
        fatalError("Unable to load PLIST at path: \(path)")
    }
    self.data = data
  }

  subscript<T>(key: String) -> T {
    guard let result = data[key] as? T else {
      fatalError("Property '\(key)' is not of type \(T.self)")
    }
    return result
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
