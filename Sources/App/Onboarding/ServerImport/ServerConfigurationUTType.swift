import Foundation
import UniformTypeIdentifiers

/// The uniform type the server-configuration document is recognized by, declared in `Info.plist` as a
/// type this app exports (`io.homeassistant.serverconfig`, extension `.hassconfig`, conforming to
/// `public.json`). It is the only document type the app registers to open from Files, Mail or AirDrop;
/// plain `.json` is accepted by the in-app picker only, so the app doesn't offer itself for every JSON
/// file on the device.
///
/// Resolving it by identifier returns the registered type when the Info.plist declaration is present;
/// the filename-extension and `.json` fallbacks keep the in-app file picker working even if the
/// system has not indexed the custom type yet.
enum ServerConfigurationUTType {
    static let identifier = ServerConfigurationImport.contentIdentifier
    static let filenameExtension = ServerConfigurationImport.primaryFileExtension

    /// The declared type, falling back to a filename-extension-derived type, then to `.json`.
    static var type: UTType {
        UTType(identifier)
            ?? UTType(filenameExtension: filenameExtension, conformingTo: .json)
            ?? .json
    }

    /// Content types the file picker should offer. `.json` is included because the file is accepted
    /// with a `.json` extension too, and a server-config file a user saved as plain `.json` would
    /// otherwise be unselectable.
    static var importableContentTypes: [UTType] {
        var types: [UTType] = [type]
        if !types.contains(.json) {
            types.append(.json)
        }
        return types
    }
}
