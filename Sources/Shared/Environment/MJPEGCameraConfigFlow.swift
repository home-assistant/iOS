import Foundation

/// The shape of Home Assistant's "MJPEG IP Camera" config flow, so the app can create an entry
/// pointed at `CameraStreamServer` without the user retyping the URL and credentials.
///
/// Keys mirror the integration's `user` step schema. `still_image_url` is deliberately omitted:
/// the stream server answers every path with the multipart stream, so there is no still endpoint
/// to offer — and the flow validates any URL it is given.
public enum MJPEGCameraConfigFlow {
    /// The integration domain, used as the config flow handler.
    public static let handler = "mjpeg"

    /// Builds the `user` step input. `username`/`password` are only sent when the stream server
    /// actually requires authentication; the flow treats empty strings as "no credentials" anyway,
    /// but leaving them out keeps the created entry clean.
    public static func userInput(
        name: String,
        streamURL: String,
        username: String,
        password: String
    ) -> [String: Any] {
        var input: [String: Any] = [
            "name": name,
            "mjpeg_url": streamURL,
            "password": password,
            "verify_ssl": true,
        ]
        if username.isEmpty == false {
            input["username"] = username
        }
        return input
    }
}
