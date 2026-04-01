import XCTest
import CoreData
@testable import WeReadMac

final class NotesStoreTests: XCTestCase {
    var store: NotesStore!

    override func setUp() {
        super.setUp()
        store = NotesStore(inMemory: true)
    }

    override func tearDown() {
        store = nil
        super.tearDown()
    }

    func testContainerLoads() {
        XCTAssertNotNil(store.container.persistentStoreCoordinator.persistentStores.first)
    }

    func testViewContextIsAvailable() {
        XCTAssertNotNil(store.viewContext)
    }

    func testBackgroundContextIsDifferentFromViewContext() {
        let bgContext = store.newBackgroundContext()
        XCTAssertNotEqual(bgContext, store.viewContext)
    }

    func testSaveBookToContext() {
        let context = store.viewContext
        let book = Book(context: context)
        book.bookId = "test-book-1"
        book.title = "Test Book"
        book.author = "Test Author"
        book.createdAt = Date()
        book.updatedAt = Date()

        store.saveContext(context)

        let request: NSFetchRequest<Book> = Book.fetchRequest()
        request.predicate = NSPredicate(format: "bookId == %@", "test-book-1")
        let results = try? context.fetch(request)
        XCTAssertEqual(results?.count, 1)
        XCTAssertEqual(results?.first?.title, "Test Book")
    }

    func testSaveHighlightWithBookRelationship() {
        let context = store.viewContext
        let book = Book(context: context)
        book.bookId = "test-book-2"
        book.title = "Book Two"
        book.author = "Author Two"
        book.createdAt = Date()
        book.updatedAt = Date()

        let highlight = Highlight(context: context)
        highlight.highlightId = "h1"
        highlight.text = "highlighted text"
        highlight.highlightType = "marker"
        highlight.createdAt = Date()
        highlight.capturedAt = Date()
        highlight.serverDeleted = false
        highlight.book = book

        store.saveContext(context)

        let request: NSFetchRequest<Highlight> = Highlight.fetchRequest()
        request.predicate = NSPredicate(format: "highlightId == %@", "h1")
        let results = try? context.fetch(request)
        XCTAssertEqual(results?.count, 1)
        XCTAssertEqual(results?.first?.book?.bookId, "test-book-2")
    }

    func testSaveThoughtWithBookRelationship() {
        let context = store.viewContext
        let book = Book(context: context)
        book.bookId = "test-book-3"
        book.title = "Book Three"
        book.author = "Author Three"
        book.createdAt = Date()
        book.updatedAt = Date()

        let thought = Thought(context: context)
        thought.thoughtId = "t1"
        thought.thoughtText = "my thought"
        thought.passageText = "the passage"
        thought.createdAt = Date()
        thought.capturedAt = Date()
        thought.serverDeleted = false
        thought.book = book

        store.saveContext(context)

        let request: NSFetchRequest<Thought> = Thought.fetchRequest()
        request.predicate = NSPredicate(format: "thoughtId == %@", "t1")
        let results = try? context.fetch(request)
        XCTAssertEqual(results?.count, 1)
        XCTAssertEqual(results?.first?.book?.bookId, "test-book-3")
    }

    func testBackgroundContextSaveMergesToViewContext() {
        let expectation = expectation(description: "Background save merges")
        let bgContext = store.newBackgroundContext()

        bgContext.perform {
            let book = Book(context: bgContext)
            book.bookId = "bg-book"
            book.title = "Background Book"
            book.author = "BG Author"
            book.createdAt = Date()
            book.updatedAt = Date()
            self.store.saveContext(bgContext)

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                let request: NSFetchRequest<Book> = Book.fetchRequest()
                request.predicate = NSPredicate(format: "bookId == %@", "bg-book")
                let results = try? self.store.viewContext.fetch(request)
                XCTAssertEqual(results?.count, 1)
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 3.0)
    }

    func testSaveContextWithNoChangesDoesNotThrow() {
        let context = store.viewContext
        // No changes made
        store.saveContext(context)
        // Should not throw or cause issues
    }
}
