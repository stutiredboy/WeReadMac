import Foundation

@MainActor
final class ReaderState: ObservableObject {
    @Published private(set) var isReaderView: Bool = false

    func update(from url: URL?) {
        let host = url?.host?.lowercased() ?? ""
        let next = (host == "weread.qq.com" || host.hasSuffix(".weread.qq.com"))
            && (url?.path.hasPrefix("/web/reader/") ?? false)
        if next != isReaderView {
            isReaderView = next
        }
    }
}
