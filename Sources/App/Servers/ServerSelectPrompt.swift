/// The explanation shown above the servers in `ServerSelectionListView`, for the flows that need the user to
/// pick a server before something can happen (a server-less deep link, a notification URL).
///
/// `link` travels separately from `message` so the picker can render it as its own pill instead of
/// interpolating a raw URL into a sentence.
struct ServerSelectPrompt {
    let message: String
    let link: String?

    init(message: String, link: String? = nil) {
        self.message = message
        self.link = link
    }
}
