import XCTest
import CoreData
@testable import WeReadMac

final class NotesDeleteServiceTests: XCTestCase {
    var store: NotesStore!
    var service: NotesDeleteService!

    override func setUp() {
        super.setUp()
        store = NotesStore(inMemory: true)
        service = NotesDeleteService(store: store)
    }

    override func tearDown() {
        service = nil
        store = nil
        super.tearDown()
    }

    // MARK: - Helpers

    private func createBook(bookId: String, context: NSManagedObjectContext) -> Book {
        let book = Book(context: context)
        book.bookId = bookId
        book.title = "Test Book"
        book.author = "Author"
        book.createdAt = Date()
        book.updatedAt = Date()
        return book
    }

    private func createHighlight(id: String, book: Book, context: NSManagedObjectContext) -> Highlight {
        let highlight = Highlight(context: context)
        highlight.highlightId = id
        highlight.text = "Highlighted text"
        highlight.highlightType = "straight"
        highlight.createdAt = Date()
        highlight.capturedAt = Date()
        highlight.serverDeleted = false
        highlight.book = book
        return highlight
    }

    private func createThought(id: String, reviewId: String?, book: Book, context: NSManagedObjectContext) -> Thought {
        let thought = Thought(context: context)
        thought.thoughtId = id
        thought.reviewId = reviewId
        thought.thoughtText = "A thought"
        thought.createdAt = Date()
        thought.capturedAt = Date()
        thought.serverDeleted = false
        thought.book = book
        return thought
    }

    // MARK: - Highlight Deletion Tests

    func testDeleteHighlightWithServerValidId() {
        let expectation = expectation(description: "Highlight deleted")
        let context = store.viewContext
        let book = createBook(bookId: "book1", context: context)
        let highlight = createHighlight(id: "CB_book1_5_100-200", book: book, context: context)
        store.saveContext(context)

        service.deleteHighlight(highlight)

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            let request: NSFetchRequest<Highlight> = Highlight.fetchRequest()
            request.predicate = NSPredicate(format: "highlightId == %@", "CB_book1_5_100-200")
            let results = try? self.store.viewContext.fetch(request)
            XCTAssertEqual(results?.count, 0, "Highlight should be deleted from CoreData")
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 3.0)
    }

    func testDeleteHighlightWithCompositeId() {
        let expectation = expectation(description: "Highlight deleted locally only")
        let context = store.viewContext
        let book = createBook(bookId: "book1", context: context)
        let highlight = createHighlight(id: "book1_5_0-100", book: book, context: context)
        store.saveContext(context)

        service.deleteHighlight(highlight)

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            let request: NSFetchRequest<Highlight> = Highlight.fetchRequest()
            request.predicate = NSPredicate(format: "highlightId == %@", "book1_5_0-100")
            let results = try? self.store.viewContext.fetch(request)
            XCTAssertEqual(results?.count, 0, "Highlight should be deleted locally")
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 3.0)
    }

    // MARK: - Thought Deletion Tests

    func testDeleteThoughtWithReviewId() {
        let expectation = expectation(description: "Thought deleted")
        let context = store.viewContext
        let book = createBook(bookId: "book2", context: context)
        let thought = createThought(id: "thought1", reviewId: "rev-123", book: book, context: context)
        store.saveContext(context)

        service.deleteThought(thought)

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            let request: NSFetchRequest<Thought> = Thought.fetchRequest()
            request.predicate = NSPredicate(format: "thoughtId == %@", "thought1")
            let results = try? self.store.viewContext.fetch(request)
            XCTAssertEqual(results?.count, 0, "Thought should be deleted from CoreData")
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 3.0)
    }

    func testDeleteThoughtWithoutReviewId() {
        let expectation = expectation(description: "Thought deleted locally only")
        let context = store.viewContext
        let book = createBook(bookId: "book3", context: context)
        let thought = createThought(id: "thought2", reviewId: nil, book: book, context: context)
        store.saveContext(context)

        service.deleteThought(thought)

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            let request: NSFetchRequest<Thought> = Thought.fetchRequest()
            request.predicate = NSPredicate(format: "thoughtId == %@", "thought2")
            let results = try? self.store.viewContext.fetch(request)
            XCTAssertEqual(results?.count, 0, "Thought should be deleted locally")
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 3.0)
    }

    // MARK: - Edge Cases

    func testDeleteHighlightNoWebView() {
        // WebViewHolder.shared.webView is nil by default in tests — this should not crash
        // Using CB_ prefix to exercise the server-delete code path (which gracefully handles nil WebView)
        let expectation = expectation(description: "Delete succeeds without WebView")
        let context = store.viewContext
        let book = createBook(bookId: "book4", context: context)
        let highlight = createHighlight(id: "CB_book4_10_0-50", book: book, context: context)
        store.saveContext(context)

        service.deleteHighlight(highlight)

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            let request: NSFetchRequest<Highlight> = Highlight.fetchRequest()
            request.predicate = NSPredicate(format: "highlightId == %@", "CB_book4_10_0-50")
            let results = try? self.store.viewContext.fetch(request)
            XCTAssertEqual(results?.count, 0, "Local deletion should succeed even without WebView")
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 3.0)
    }

    func testDeletedHighlightNotInSearchResults() {
        let expectation = expectation(description: "Deleted highlight excluded from search")
        let context = store.viewContext
        let book = createBook(bookId: "book5", context: context)
        let highlight = createHighlight(id: "555", book: book, context: context)
        highlight.text = "unique search term xyz"
        store.saveContext(context)

        let searchService = NotesSearchService(store: store)
        let beforeResults = searchService.search(keyword: "xyz")
        XCTAssertFalse(beforeResults.isEmpty, "Should find highlight before deletion")

        service.deleteHighlight(highlight)

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            let afterResults = searchService.search(keyword: "xyz")
            let totalHighlights = afterResults.flatMap { $0.highlights }
            XCTAssertTrue(totalHighlights.isEmpty, "Deleted highlight should not appear in search")
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 3.0)
    }
}
