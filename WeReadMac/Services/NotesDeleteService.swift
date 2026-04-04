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
        let canDeleteOnServer = !highlightId.isEmpty && !highlightId.contains("_")

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
    // Uses the original (unpatched) fetch stored by intercept.js as __origFetch
    // to avoid our own interceptor re-processing these requests.
    // Uses relative URLs so the request goes to the page's own origin (weread.qq.com),
    // which avoids CORS issues with i.weread.qq.com.
    // bookmarkId/reviewId are sent as numbers to match WeRead's own format.

    private func sendServerDeleteHighlight(bookmarkId: String) {
        let id = Int(bookmarkId).map { String($0) } ?? "'\(bookmarkId)'"
        let js = """
        (function() {
            var f = window.__origFetch || fetch;
            return f.call(window, '/web/book/removeBookmark', {
                method: 'POST',
                credentials: 'include',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ bookmarkId: \(id) })
            }).then(function(r) { return r.status; }).catch(function() { return -1; });
        })();
        """
        evaluateJS(js, label: "deleteHighlight(\(bookmarkId))")
    }

    private func sendServerDeleteThought(reviewId: String) {
        let id = Int(reviewId).map { String($0) } ?? "'\(reviewId)'"
        let js = """
        (function() {
            var f = window.__origFetch || fetch;
            return f.call(window, '/web/review/delete', {
                method: 'POST',
                credentials: 'include',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ reviewId: \(id) })
            }).then(function(r) { return r.status; }).catch(function() { return -1; });
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
                } else {
                    self.logger.info("Server delete sent for \(label), status: \(String(describing: result))")
                }
            }
        }
    }
}
