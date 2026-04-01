import XCTest
import CoreData
@testable import WeReadMac

final class NotesCaptureServiceTests: XCTestCase {
    var store: NotesStore!
    var service: NotesCaptureService!

    override func setUp() {
        super.setUp()
        store = NotesStore(inMemory: true)
        service = NotesCaptureService(store: store)
    }

    override func tearDown() {
        service = nil
        store = nil
        super.tearDown()
    }

    // MARK: - Highlight Tests (US1)

    func testProcessHighlightCreatesHighlightAndBook() {
        let expectation = expectation(description: "Highlight saved")
        let payload: [String: Any] = [
            "bookId": "book1",
            "markText": "This is highlighted text",
            "style": 0,
            "chapterUid": 5,
            "chapterTitle": "Chapter Five",
            "range": "0-100",
            "bookTitle": "Test Book",
            "bookAuthor": "Test Author"
        ]
        let rawMessage: [String: Any] = [
            "type": "highlight",
            "url": "https://i.weread.qq.com/book/bookmark",
            "method": "POST",
            "timestamp": 1775193600000.0,
            "body": payload
        ]

        service.processHighlight(payload: payload, rawMessage: rawMessage)

        // Give background context time to save and merge
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            let request: NSFetchRequest<Highlight> = Highlight.fetchRequest()
            let highlights = try? self.store.viewContext.fetch(request)
            XCTAssertEqual(highlights?.count, 1)

            let h = highlights?.first
            XCTAssertEqual(h?.text, "This is highlighted text")
            XCTAssertEqual(h?.highlightType, "straight") // style 0 = straight
            XCTAssertEqual(h?.chapterUid, "5")
            XCTAssertEqual(h?.chapterTitle, "Chapter Five")
            XCTAssertEqual(h?.range, "0-100")
            XCTAssertEqual(h?.highlightId, "book1_5_0-100")
            XCTAssertNotNil(h?.rawPayload)
            XCTAssertEqual(h?.serverDeleted, false)

            // Verify book was created
            XCTAssertEqual(h?.book?.bookId, "book1")
            XCTAssertEqual(h?.book?.title, "Test Book")
            XCTAssertEqual(h?.book?.author, "Test Author")

            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 3.0)
    }

    func testHighlightStyleMapping() {
        let expectation = expectation(description: "Styles mapped")
        let styles: [(Int, String)] = [(0, "straight"), (1, "marker"), (2, "wavy"), (99, "straight")]

        for (index, (style, expected)) in styles.enumerated() {
            let payload: [String: Any] = [
                "bookId": "book-style-\(index)",
                "markText": "text \(index)",
                "style": style
            ]
            let rawMessage: [String: Any] = ["type": "highlight", "timestamp": 1775193600000.0, "body": payload]
            service.processHighlight(payload: payload, rawMessage: rawMessage)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            for (index, (_, expected)) in styles.enumerated() {
                let request: NSFetchRequest<Highlight> = Highlight.fetchRequest()
                request.predicate = NSPredicate(format: "book.bookId == %@", "book-style-\(index)")
                let results = try? self.store.viewContext.fetch(request)
                XCTAssertEqual(results?.first?.highlightType, expected, "Style \(index) should map to \(expected)")
            }
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 3.0)
    }

    func testHighlightMissingMarkTextIsIgnored() {
        let expectation = expectation(description: "No highlight saved")
        let payload: [String: Any] = ["bookId": "book1"]
        let rawMessage: [String: Any] = ["type": "highlight", "timestamp": 1775193600000.0, "body": payload]

        service.processHighlight(payload: payload, rawMessage: rawMessage)

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            let request: NSFetchRequest<Highlight> = Highlight.fetchRequest()
            let highlights = try? self.store.viewContext.fetch(request)
            XCTAssertEqual(highlights?.count, 0)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 3.0)
    }

    func testHighlightMissingBookIdIsIgnored() {
        let expectation = expectation(description: "No highlight saved")
        let payload: [String: Any] = ["markText": "some text"]
        let rawMessage: [String: Any] = ["type": "highlight", "timestamp": 1775193600000.0, "body": payload]

        service.processHighlight(payload: payload, rawMessage: rawMessage)

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            let request: NSFetchRequest<Highlight> = Highlight.fetchRequest()
            let highlights = try? self.store.viewContext.fetch(request)
            XCTAssertEqual(highlights?.count, 0)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 3.0)
    }

    func testDuplicateHighlightsAreStoredSeparately() {
        let expectation = expectation(description: "Duplicates stored")
        let payload: [String: Any] = [
            "bookId": "book1",
            "markText": "same text",
            "style": 0
        ]
        let rawMessage: [String: Any] = ["type": "highlight", "timestamp": 1775193600000.0, "body": payload]

        service.processHighlight(payload: payload, rawMessage: rawMessage)
        service.processHighlight(payload: payload, rawMessage: rawMessage)

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            let request: NSFetchRequest<Highlight> = Highlight.fetchRequest()
            let highlights = try? self.store.viewContext.fetch(request)
            // Each gets a unique UUID since no bookmarkId is provided
            XCTAssertEqual(highlights?.count, 2)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 3.0)
    }

    func testDeleteHighlightRemovesRecord() {
        let expectation = expectation(description: "Highlight deleted")
        // First create a highlight
        let context = store.viewContext
        let book = Book(context: context)
        book.bookId = "book-del"
        book.title = "Del Book"
        book.author = "Author"
        book.createdAt = Date()
        book.updatedAt = Date()

        let highlight = Highlight(context: context)
        highlight.highlightId = "book-del_5_0-100"
        highlight.text = "to be deleted"
        highlight.highlightType = "straight"
        highlight.chapterUid = "5"
        highlight.range = "0-100"
        highlight.createdAt = Date()
        highlight.capturedAt = Date()
        highlight.serverDeleted = false
        highlight.book = book
        store.saveContext(context)

        // Now process delete
        let deletePayload: [String: Any] = ["bookmarkId": "book-del_5_0-100"]
        service.processDeleteHighlight(payload: deletePayload)

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            let request: NSFetchRequest<Highlight> = Highlight.fetchRequest()
            request.predicate = NSPredicate(format: "highlightId == %@", "book-del_5_0-100")
            let results = try? self.store.viewContext.fetch(request)
            XCTAssertEqual(results?.count, 0, "Highlight should be deleted from CoreData")
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 3.0)
    }

    // MARK: - Thought Tests (US2)

    func testProcessThoughtCreatesThoughtAndBook() {
        let expectation = expectation(description: "Thought saved")
        let payload: [String: Any] = [
            "bookId": "book-t1",
            "content": "My thought about this",
            "abstract": "The passage being annotated",
            "chapterUid": 3,
            "reviewId": "rev-1",
            "bookTitle": "Thought Book",
            "bookAuthor": "Thought Author"
        ]
        let rawMessage: [String: Any] = ["type": "thought", "timestamp": 1775193600000.0, "body": payload]

        service.processThought(payload: payload, rawMessage: rawMessage)

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            let request: NSFetchRequest<Thought> = Thought.fetchRequest()
            let thoughts = try? self.store.viewContext.fetch(request)
            XCTAssertEqual(thoughts?.count, 1)

            let t = thoughts?.first
            XCTAssertEqual(t?.thoughtText, "My thought about this")
            XCTAssertEqual(t?.passageText, "The passage being annotated")
            XCTAssertEqual(t?.chapterUid, "3")
            XCTAssertEqual(t?.thoughtId, "rev-1")
            XCTAssertEqual(t?.serverDeleted, false)
            XCTAssertEqual(t?.book?.bookId, "book-t1")

            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 3.0)
    }

    func testProcessThoughtUpdateModifiesExistingThought() {
        let expectation = expectation(description: "Thought updated")
        // Create a thought first
        let context = store.viewContext
        let book = Book(context: context)
        book.bookId = "book-upd"
        book.title = "Update Book"
        book.author = "Author"
        book.createdAt = Date()
        book.updatedAt = Date()

        let thought = Thought(context: context)
        thought.thoughtId = "rev-update-1"
        thought.thoughtText = "original thought"
        thought.passageText = "original passage"
        thought.createdAt = Date()
        thought.capturedAt = Date()
        thought.serverDeleted = false
        thought.book = book
        store.saveContext(context)

        // Now update it
        let updatePayload: [String: Any] = [
            "reviewId": "rev-update-1",
            "content": "updated thought text",
            "abstract": "updated passage"
        ]
        let rawMessage: [String: Any] = ["type": "updateThought", "timestamp": 1775193600000.0, "body": updatePayload]
        service.processThoughtUpdate(payload: updatePayload, rawMessage: rawMessage)

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            let request: NSFetchRequest<Thought> = Thought.fetchRequest()
            request.predicate = NSPredicate(format: "thoughtId == %@", "rev-update-1")
            let results = try? self.store.viewContext.fetch(request)
            XCTAssertEqual(results?.first?.thoughtText, "updated thought text")
            XCTAssertEqual(results?.first?.passageText, "updated passage")
            XCTAssertNotNil(results?.first?.updatedAt)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 3.0)
    }

    func testThoughtMissingContentIsIgnored() {
        let expectation = expectation(description: "No thought saved")
        let payload: [String: Any] = ["bookId": "book1"]
        let rawMessage: [String: Any] = ["type": "thought", "timestamp": 1775193600000.0, "body": payload]

        service.processThought(payload: payload, rawMessage: rawMessage)

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            let request: NSFetchRequest<Thought> = Thought.fetchRequest()
            let thoughts = try? self.store.viewContext.fetch(request)
            XCTAssertEqual(thoughts?.count, 0)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 3.0)
    }

    func testDeleteThoughtSetsServerDeletedFlag() {
        let expectation = expectation(description: "Thought delete flag set")
        let context = store.viewContext
        let book = Book(context: context)
        book.bookId = "book-tdel"
        book.title = "Del Book"
        book.author = "Author"
        book.createdAt = Date()
        book.updatedAt = Date()

        let thought = Thought(context: context)
        thought.thoughtId = "rev-del-1"
        thought.thoughtText = "to be deleted"
        thought.createdAt = Date()
        thought.capturedAt = Date()
        thought.serverDeleted = false
        thought.book = book
        store.saveContext(context)

        let deletePayload: [String: Any] = ["reviewId": "rev-del-1"]
        service.processDeleteThought(payload: deletePayload)

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            let request: NSFetchRequest<Thought> = Thought.fetchRequest()
            request.predicate = NSPredicate(format: "thoughtId == %@", "rev-del-1")
            let results = try? self.store.viewContext.fetch(request)
            XCTAssertEqual(results?.first?.serverDeleted, true)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 3.0)
    }

    // MARK: - Integration: Book Reuse

    func testMultipleAnnotationsReuseExistingBook() {
        let expectation = expectation(description: "Book reused")
        let payload1: [String: Any] = [
            "bookId": "shared-book",
            "markText": "highlight one",
            "style": 0,
            "bookTitle": "Shared Book",
            "bookAuthor": "Shared Author"
        ]
        let payload2: [String: Any] = [
            "bookId": "shared-book",
            "content": "thought one",
            "abstract": "passage"
        ]
        let raw1: [String: Any] = ["type": "highlight", "timestamp": 1775193600000.0, "body": payload1]
        let raw2: [String: Any] = ["type": "thought", "timestamp": 1775193600000.0, "body": payload2]

        // Sequence operations to allow the first to complete before the second
        service.processHighlight(payload: payload1, rawMessage: raw1)

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.service.processThought(payload: payload2, rawMessage: raw2)

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                let bookRequest: NSFetchRequest<Book> = Book.fetchRequest()
                bookRequest.predicate = NSPredicate(format: "bookId == %@", "shared-book")
                let books = try? self.store.viewContext.fetch(bookRequest)
                // Should only have one book, not two
                XCTAssertEqual(books?.count, 1)
                expectation.fulfill()
            }
        }
        wait(for: [expectation], timeout: 5.0)
    }
}
