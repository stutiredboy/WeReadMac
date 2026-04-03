import CoreData
import os

final class NotesCaptureService {
    private let store: NotesStore
    private let logger = Logger(subsystem: "com.wereadmac.app", category: "NotesCaptureService")
    private let syncingBooks = NSMutableSet() // bookIds currently being synced
    private let syncLock = NSLock()

    init(store: NotesStore = .shared) {
        self.store = store
    }

    // MARK: - Highlight Capture

    func processHighlight(payload: [String: Any], rawMessage: [String: Any]) {
        let context = store.newBackgroundContext()
        context.perform {
            guard let markText = payload["markText"] as? String, !markText.isEmpty else {
                self.logger.warning("Highlight payload missing markText")
                return
            }

            let bookId = self.extractBookId(from: payload)
            guard let bookId else {
                self.logger.warning("Highlight payload missing bookId")
                return
            }

            let book = self.fetchOrCreateBook(bookId: bookId, payload: payload, context: context)
            book.updatedAt = Date()

            let highlight = Highlight(context: context)
            highlight.highlightId = self.extractHighlightId(from: payload)
            highlight.text = self.decodeBase64IfNeeded(markText)
            highlight.highlightType = self.mapHighlightStyle(payload["style"])
            highlight.chapterUid = self.stringValue(payload["chapterUid"])
            highlight.chapterTitle = payload["chapterTitle"] as? String
            highlight.range = payload["range"] as? String
            highlight.createdAt = self.extractDate(from: rawMessage) ?? Date()
            highlight.capturedAt = Date()
            highlight.rawPayload = self.jsonString(from: payload)
            highlight.serverDeleted = false
            highlight.book = book

            self.store.saveContext(context)
            self.logger.info("Captured highlight: \(highlight.highlightId ?? "unknown")")
        }
    }

    func processDeleteHighlight(payload: [String: Any]) {
        let context = store.newBackgroundContext()
        context.perform {
            let highlightId = self.extractHighlightId(from: payload, forDelete: true)
            guard !highlightId.isEmpty else { return }

            let request: NSFetchRequest<Highlight> = Highlight.fetchRequest()
            request.predicate = NSPredicate(format: "highlightId == %@", highlightId)

            if let highlight = try? context.fetch(request).first {
                context.delete(highlight)
                self.store.saveContext(context)
                self.logger.info("Deleted highlight: \(highlightId)")
            }
        }
    }

    // MARK: - Thought Capture

    func processThought(payload: [String: Any], rawMessage: [String: Any]) {
        let context = store.newBackgroundContext()
        context.perform {
            guard let content = payload["content"] as? String, !content.isEmpty else {
                self.logger.warning("Thought payload missing content")
                return
            }

            let bookId = self.extractBookId(from: payload)
            guard let bookId else {
                self.logger.warning("Thought payload missing bookId")
                return
            }

            let book = self.fetchOrCreateBook(bookId: bookId, payload: payload, context: context)
            book.updatedAt = Date()

            let thought = Thought(context: context)
            thought.thoughtId = self.extractThoughtId(from: payload)
            thought.thoughtText = self.decodeBase64IfNeeded(content)
            thought.passageText = (payload["abstract"] as? String).map { self.decodeBase64IfNeeded($0) }
            thought.chapterUid = self.stringValue(payload["chapterUid"])
            thought.chapterTitle = payload["chapterTitle"] as? String
            thought.range = payload["range"] as? String
            thought.createdAt = self.extractDate(from: rawMessage) ?? Date()
            thought.capturedAt = Date()
            thought.rawPayload = self.jsonString(from: payload)
            thought.serverDeleted = false
            thought.book = book

            self.store.saveContext(context)
            self.logger.info("Captured thought: \(thought.thoughtId ?? "unknown")")
        }
    }

    func processThoughtReviewId(payload: [String: Any]) {
        let context = store.newBackgroundContext()
        context.perform {
            guard let reviewId = payload["reviewId"] as? String, !reviewId.isEmpty else { return }
            guard let bookId = self.extractBookId(from: payload) else {
                self.logger.warning("thoughtReviewId payload missing bookId")
                return
            }

            let content = payload["content"] as? String

            // Find the most recently captured thought for this book that has no reviewId yet
            let request: NSFetchRequest<Thought> = Thought.fetchRequest()
            var predicates = [
                NSPredicate(format: "book.bookId == %@", bookId),
                NSPredicate(format: "reviewId == nil")
            ]
            if let content, !content.isEmpty {
                predicates.append(NSPredicate(format: "thoughtText == %@", self.decodeBase64IfNeeded(content)))
            }
            request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
            request.sortDescriptors = [NSSortDescriptor(key: "capturedAt", ascending: false)]
            request.fetchLimit = 1

            if let thought = try? context.fetch(request).first {
                thought.reviewId = reviewId
                self.store.saveContext(context)
                self.logger.info("Assigned reviewId \(reviewId) to thought: \(thought.thoughtId ?? "unknown")")
            } else {
                self.logger.info("No matching thought found for reviewId: \(reviewId)")
            }
        }
    }

    func processThoughtUpdate(payload: [String: Any], rawMessage: [String: Any]) {
        let context = store.newBackgroundContext()
        context.perform {
            guard let reviewId = payload["reviewId"] as? String else { return }

            let request: NSFetchRequest<Thought> = Thought.fetchRequest()
            request.predicate = NSPredicate(format: "reviewId == %@", reviewId)

            if let thought = try? context.fetch(request).first {
                if let content = payload["content"] as? String {
                    thought.thoughtText = self.decodeBase64IfNeeded(content)
                }
                if let abstract = payload["abstract"] as? String {
                    thought.passageText = self.decodeBase64IfNeeded(abstract)
                }
                thought.updatedAt = Date()
                thought.rawPayload = self.jsonString(from: payload)
                self.store.saveContext(context)
                self.logger.info("Updated thought: \(reviewId)")
            }
        }
    }

    func processDeleteThought(payload: [String: Any]) {
        let context = store.newBackgroundContext()
        context.perform {
            guard let reviewId = payload["reviewId"] as? String else { return }

            let request: NSFetchRequest<Thought> = Thought.fetchRequest()
            request.predicate = NSPredicate(format: "reviewId == %@", reviewId)

            if let thought = try? context.fetch(request).first {
                context.delete(thought)
                self.store.saveContext(context)
                self.logger.info("Deleted thought: \(reviewId)")
            }
        }
    }

    // MARK: - Book Info

    func processBookInfo(payload: [String: Any]) {
        let context = store.newBackgroundContext()
        context.perform {
            guard let bookId = self.extractBookId(from: payload) else { return }

            let request: NSFetchRequest<Book> = Book.fetchRequest()
            request.predicate = NSPredicate(format: "bookId == %@", bookId)

            guard let book = try? context.fetch(request).first else {
                self.logger.info("Book not found for info update: \(bookId)")
                return
            }

            var updated = false
            if let title = payload["title"] as? String, !title.isEmpty,
               (book.title == nil || book.title!.isEmpty) {
                book.title = title
                updated = true
            }
            if let author = payload["author"] as? String, !author.isEmpty,
               (book.author == nil || book.author!.isEmpty) {
                book.author = author
                updated = true
            }
            if let cover = payload["cover"] as? String, !cover.isEmpty,
               (book.coverURL == nil || book.coverURL!.isEmpty) {
                book.coverURL = cover
                updated = true
            }

            if updated {
                book.updatedAt = Date()
                self.store.saveContext(context)
                self.logger.info("Updated book info: \(bookId) → \(book.title ?? "")")
            }
        }
    }

    // MARK: - Chapter Info

    func processChapterInfos(payload: [String: Any]) {
        let context = store.newBackgroundContext()
        context.perform {
            guard let bookId = self.extractBookId(from: payload),
                  let chapters = payload["chapters"] as? [String: String] else { return }

            // Update highlights with missing chapterTitle
            let hRequest: NSFetchRequest<Highlight> = Highlight.fetchRequest()
            hRequest.predicate = NSPredicate(
                format: "book.bookId == %@ AND (chapterTitle == nil OR chapterTitle == '')",
                bookId
            )
            if let highlights = try? context.fetch(hRequest) {
                for h in highlights {
                    if let uid = h.chapterUid, let title = chapters[uid] {
                        h.chapterTitle = title
                    }
                }
            }

            // Update thoughts with missing chapterTitle
            let tRequest: NSFetchRequest<Thought> = Thought.fetchRequest()
            tRequest.predicate = NSPredicate(
                format: "book.bookId == %@ AND (chapterTitle == nil OR chapterTitle == '')",
                bookId
            )
            if let thoughts = try? context.fetch(tRequest) {
                for t in thoughts {
                    if let uid = t.chapterUid, let title = chapters[uid] {
                        t.chapterTitle = title
                    }
                }
            }

            self.store.saveContext(context)
            self.logger.info("Updated chapter titles for book: \(bookId), \(chapters.count) chapters available")
        }
    }

    // MARK: - Bookmark List Sync

    func processBookmarkList(payload: [String: Any]) {
        guard let updated = payload["updated"] as? [[String: Any]], !updated.isEmpty else {
            return
        }

        // Determine bookId for dedup guard
        let bookId = updated.first.flatMap({ extractBookId(from: $0) })

        // Skip if a sync is already in progress for this book
        if let bookId {
            syncLock.lock()
            if syncingBooks.contains(bookId) {
                syncLock.unlock()
                logger.info("Skipping bookmarkList sync (already in progress): \(bookId)")
                return
            }
            syncingBooks.add(bookId)
            syncLock.unlock()
        }

        let context = store.newBackgroundContext()
        context.perform {
            defer {
                if let bookId {
                    self.syncLock.lock()
                    self.syncingBooks.remove(bookId)
                    self.syncLock.unlock()
                }
            }

            // Collect all bookmarkIds from the response
            let incomingIds = updated.compactMap { $0["bookmarkId"] as? String }
            guard !incomingIds.isEmpty else { return }

            // Batch fetch existing highlights by ID
            let fetchRequest: NSFetchRequest<Highlight> = Highlight.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "highlightId IN %@", incomingIds)
            let existingHighlights = (try? context.fetch(fetchRequest)) ?? []
            let existingIds = Set(existingHighlights.compactMap { $0.highlightId })

            var insertedCount = 0

            for entry in updated {
                guard let bookmarkId = entry["bookmarkId"] as? String,
                      let markText = entry["markText"] as? String, !markText.isEmpty else {
                    self.logger.warning("Skipping malformed bookmark entry: missing bookmarkId or markText")
                    continue
                }

                // Skip if already exists locally
                if existingIds.contains(bookmarkId) { continue }

                guard let entryBookId = self.extractBookId(from: entry) else {
                    self.logger.warning("Skipping bookmark entry: missing bookId")
                    continue
                }

                let book = self.fetchOrCreateBook(bookId: entryBookId, payload: entry, context: context)
                book.updatedAt = Date()

                let highlight = Highlight(context: context)
                highlight.highlightId = bookmarkId
                highlight.text = markText // plaintext, no base64 decoding
                highlight.highlightType = self.mapHighlightStyle(entry["style"])
                highlight.chapterUid = self.stringValue(entry["chapterUid"])
                highlight.chapterTitle = entry["chapterName"] as? String // note: chapterName, not chapterTitle
                highlight.range = entry["range"] as? String
                // createTime is in seconds (not milliseconds)
                if let createTime = entry["createTime"] as? Double {
                    highlight.createdAt = Date(timeIntervalSince1970: createTime)
                } else if let createTime = entry["createTime"] as? Int {
                    highlight.createdAt = Date(timeIntervalSince1970: Double(createTime))
                } else {
                    highlight.createdAt = Date()
                }
                highlight.capturedAt = Date()
                highlight.rawPayload = self.jsonString(from: entry)
                highlight.serverDeleted = false
                highlight.book = book

                insertedCount += 1
            }

            if insertedCount > 0 {
                self.store.saveContext(context)
                self.logger.info("Synced \(insertedCount) bookmarks from bookmarklist")
            }
        }
    }

    // MARK: - Helpers

    private func fetchOrCreateBook(bookId: String, payload: [String: Any], context: NSManagedObjectContext) -> Book {
        let request: NSFetchRequest<Book> = Book.fetchRequest()
        request.predicate = NSPredicate(format: "bookId == %@", bookId)

        if let existing = try? context.fetch(request).first {
            // Enrich metadata if we now have better data
            if let title = payload["bookTitle"] as? String, !title.isEmpty, existing.title?.isEmpty != false {
                existing.title = title
            }
            if let author = payload["bookAuthor"] as? String, !author.isEmpty, existing.author?.isEmpty != false {
                existing.author = author
            }
            return existing
        }

        let book = Book(context: context)
        book.bookId = bookId
        book.title = payload["bookTitle"] as? String ?? ""
        book.author = payload["bookAuthor"] as? String ?? ""
        book.coverURL = payload["coverURL"] as? String
        book.createdAt = Date()
        book.updatedAt = Date()
        return book
    }

    private func extractBookId(from payload: [String: Any]) -> String? {
        if let bookId = payload["bookId"] as? String {
            return bookId
        }
        if let bookId = payload["bookId"] as? Int {
            return String(bookId)
        }
        return nil
    }

    private func extractHighlightId(from payload: [String: Any], forDelete: Bool = false) -> String {
        // For delete requests, bookmarkId is provided directly
        if let id = payload["bookmarkId"] as? String { return id }
        if let id = payload["bookmarkId"] as? Int { return String(id) }
        // For create requests, compose from bookId + chapterUid + range
        if !forDelete,
           let bookId = extractBookId(from: payload),
           let chapterUid = stringValue(payload["chapterUid"]),
           let range = payload["range"] as? String {
            return "\(bookId)_\(chapterUid)_\(range)"
        }
        return forDelete ? "" : UUID().uuidString
    }

    private func extractThoughtId(from payload: [String: Any]) -> String {
        if let id = payload["reviewId"] as? String { return id }
        if let id = payload["reviewId"] as? Int { return String(id) }
        return UUID().uuidString
    }

    private func mapHighlightStyle(_ style: Any?) -> String {
        guard let styleValue = style as? Int else { return "straight" }
        switch styleValue {
        case 0: return "straight"
        case 1: return "marker"
        case 2: return "wavy"
        default: return "straight"
        }
    }

    private func stringValue(_ value: Any?) -> String? {
        if let str = value as? String { return str }
        if let num = value as? Int { return String(num) }
        return nil
    }

    private func extractDate(from message: [String: Any]) -> Date? {
        guard let timestamp = message["timestamp"] as? Double else { return nil }
        return Date(timeIntervalSince1970: timestamp / 1000.0)
    }

    private func decodeBase64IfNeeded(_ value: String) -> String {
        // Check if value looks like base64 encoded text
        guard value.count >= 8,
              value.range(of: "^[A-Za-z0-9+/]+=*$", options: .regularExpression) != nil,
              let data = Data(base64Encoded: value),
              let decoded = String(data: data, encoding: .utf8) else {
            return value
        }
        return decoded
    }

    private func jsonString(from dict: [String: Any]) -> String? {
        guard let data = try? JSONSerialization.data(withJSONObject: dict),
              let str = String(data: data, encoding: .utf8) else { return nil }
        return str
    }
}
