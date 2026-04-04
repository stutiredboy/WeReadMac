import CoreData
import WebKit
import os

final class NotesDeleteService {
    static let shared = NotesDeleteService()

    private let store: NotesStore
    private let logger = Logger(subsystem: "com.wereadmac.app", category: "NotesDelete")

    init(store: NotesStore = NotesStore.shared) {
        self.store = store
    }

    // MARK: - Delete Highlight

    func deleteHighlight(_ highlight: Highlight, completion: (() -> Void)? = nil) {
        let highlightId = highlight.highlightId ?? ""
        let canDeleteOnServer = !highlightId.isEmpty && highlightId.hasPrefix("CB_")

        let context = store.newBackgroundContext()
        context.perform {
            let request: NSFetchRequest<Highlight> = Highlight.fetchRequest()
            request.predicate = NSPredicate(format: "highlightId == %@", highlightId)

            if let local = try? context.fetch(request).first {
                context.delete(local)
                self.store.saveContext(context)
                self.logger.info("Deleted highlight locally: \(highlightId)")
            }
            DispatchQueue.main.async { completion?() }
        }

        if canDeleteOnServer {
            sendServerDeleteHighlight(bookmarkId: highlightId)
        }
    }

    // MARK: - Delete Thought

    func deleteThought(_ thought: Thought, completion: (() -> Void)? = nil) {
        let reviewId = thought.reviewId
        let thoughtId = thought.thoughtId ?? ""

        let context = store.newBackgroundContext()
        context.perform {
            let request: NSFetchRequest<Thought> = Thought.fetchRequest()
            request.predicate = NSPredicate(format: "thoughtId == %@", thoughtId)

            if let local = try? context.fetch(request).first {
                context.delete(local)
                self.store.saveContext(context)
                self.logger.info("Deleted thought locally: \(thoughtId)")
            }
            DispatchQueue.main.async { completion?() }
        }

        if let reviewId, !reviewId.isEmpty {
            sendServerDeleteThought(reviewId: reviewId)
        }
    }

    // MARK: - Server Deletion
    //
    // Uses window.fetch (NOT __origFetch) so the request goes through WeRead's
    // own fetch wrapper which adds required headers like x-wrpa-0 (request signature).
    // Our intercept.js is injected at documentStart (before WeRead's JS), so
    // __origFetch is the raw browser fetch without WeRead's headers — that won't work.
    // Using window.fetch chains: WeRead wrapper → our interceptor → native fetch.
    // Our interceptor seeing the delete is harmless (local record already deleted).
    //
    // Uses relative URLs so the request goes to the page's own origin (weread.qq.com),
    // which avoids CORS issues with i.weread.qq.com.
    // bookmarkId/reviewId are sent as strings to match WeRead's own format.

    private func sendServerDeleteHighlight(bookmarkId: String) {
        let js = """
        (function() {
            return fetch('/web/book/removeBookmark', {
                method: 'POST',
                credentials: 'include',
                headers: { 'Content-Type': 'application/json;charset=UTF-8' },
                body: JSON.stringify({ bookmarkId: '\(bookmarkId)' })
            }).then(function(r) {
                return r.clone().text().then(function(body) {
                    return { status: r.status, body: body };
                });
            }).catch(function(e) { return { status: -1, body: e.message || 'fetch error' }; });
        })();
        """
        evaluateJS(js, label: "deleteHighlight(\(bookmarkId))")
    }

    private func sendServerDeleteThought(reviewId: String) {
        let js = """
        (function() {
            return fetch('/web/review/delete', {
                method: 'POST',
                credentials: 'include',
                headers: { 'Content-Type': 'application/json;charset=UTF-8' },
                body: JSON.stringify({ reviewId: '\(reviewId)' })
            }).then(function(r) {
                return r.clone().text().then(function(body) {
                    return { status: r.status, body: body };
                });
            }).catch(function(e) { return { status: -1, body: e.message || 'fetch error' }; });
        })();
        """
        evaluateJS(js, label: "deleteThought(\(reviewId))")
    }

    private func evaluateJS(_ js: String, label: String) {
        DispatchQueue.main.async {
            guard let webView = WebViewHolder.shared.webView else {
                self.logger.info("WebView unavailable, skipping server delete for \(label)")
                return
            }
            webView.evaluateJavaScript(js) { result, error in
                if let error {
                    self.logger.warning("Server delete failed for \(label): \(error.localizedDescription)")
                } else if let dict = result as? [String: Any] {
                    let status = dict["status"] ?? "?"
                    let body = dict["body"] ?? ""
                    self.logger.info("Server delete for \(label): status=\(String(describing: status)) body=\(String(describing: body))")
                } else {
                    self.logger.info("Server delete sent for \(label), result: \(String(describing: result))")
                }
            }
        }
    }
}
