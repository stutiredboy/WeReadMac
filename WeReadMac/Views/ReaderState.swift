import Foundation

@MainActor
final class ReaderState: ObservableObject {
    @Published private(set) var isReaderView: Bool = false

    func update(from url: URL?) {
        let next: Bool
        if let url,
           let host = url.host?.lowercased(),
           (host == "weread.qq.com" || host.hasSuffix(".weread.qq.com")),
           url.path.hasPrefix("/web/reader/") {
            next = true
        } else {
            next = false
        }
        if next != isReaderView {
            isReaderView = next
        }
    }
}
