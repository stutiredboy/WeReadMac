import XCTest
import CoreData
@testable import WeReadMac

final class NotesSearchServiceTests: XCTestCase {
    var store: NotesStore!
    var searchService: NotesSearchService!

    override func setUp() {
        super.setUp()
        store = NotesStore(inMemory: true)
        searchService = NotesSearchService(store: store)
        seedTestData()
    }

    override func tearDown() {
        searchService = nil
        store = nil
        super.tearDown()
    }

    private func seedTestData() {
        let context = store.viewContext

        // Book 1
        let book1 = Book(context: context)
        book1.bookId = "b1"
        book1.title = "Swift Programming"
        book1.author = "Apple Developer"
        book1.createdAt = Date()
        book1.updatedAt = Date()

        let h1 = Highlight(context: context)
        h1.highlightId = "h1"
        h1.text = "Protocols define a blueprint of methods"
        h1.highlightType = "marker"
        h1.chapterTitle = "Protocols"
        h1.createdAt = Date()
        h1.capturedAt = Date()
        h1.serverDeleted = false
        h1.book = book1

        let t1 = Thought(context: context)
        t1.thoughtId = "t1"
        t1.thoughtText = "This is similar to Java interfaces"
        t1.passageText = "Protocols define a blueprint"
        t1.chapterTitle = "Protocols"
        t1.createdAt = Date()
        t1.capturedAt = Date()
        t1.serverDeleted = false
        t1.book = book1

        // Book 2
        let book2 = Book(context: context)
        book2.bookId = "b2"
        book2.title = "Design Patterns"
        book2.author = "Gang of Four"
        book2.createdAt = Date()
        book2.updatedAt = Date()

        let h2 = Highlight(context: context)
        h2.highlightId = "h2"
        h2.text = "Observer pattern provides a subscription model"
        h2.highlightType = "wavy"
        h2.chapterTitle = "Behavioral Patterns"
        h2.createdAt = Date()
        h2.capturedAt = Date()
        h2.serverDeleted = false
        h2.book = book2

        // Deleted highlight (should not appear in search)
        let h3 = Highlight(context: context)
        h3.highlightId = "h3"
        h3.text = "This was deleted"
        h3.highlightType = "straight"
        h3.createdAt = Date()
        h3.capturedAt = Date()
        h3.serverDeleted = true
        h3.book = book2

        store.saveContext(context)
    }

    func testSearchByKeywordFindsHighlights() {
        let results = searchService.search(keyword: "blueprint")
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.book.bookId, "b1")
        XCTAssertEqual(results.first?.highlights.count, 1)
    }

    func testSearchByKeywordFindsThoughts() {
        let results = searchService.search(keyword: "Java")
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.thoughts.count, 1)
    }

    func testSearchIsCaseInsensitive() {
        let results = searchService.search(keyword: "OBSERVER")
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.highlights.count, 1)
    }

    func testSearchByBookTitle() {
        let results = searchService.search(keyword: "Swift Programming")
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.book.title, "Swift Programming")
    }

    func testSearchByChapterTitle() {
        let results = searchService.search(keyword: "Behavioral")
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.book.bookId, "b2")
    }

    func testSearchExcludesServerDeletedItems() {
        let results = searchService.search(keyword: "deleted")
        XCTAssertTrue(results.isEmpty || results.allSatisfy { $0.highlights.allSatisfy { !$0.serverDeleted } })
    }

    func testEmptySearchReturnsAllNotes() {
        let results = searchService.search(keyword: "")
        XCTAssertEqual(results.count, 2) // Two books
    }

    func testSearchWithNoResults() {
        let results = searchService.search(keyword: "xyznonexistent")
        XCTAssertTrue(results.isEmpty)
    }

    func testAllNotesReturnsAllBooks() {
        let results = searchService.allNotes()
        XCTAssertEqual(results.count, 2)
    }

    func testSearchResultsGroupedByBook() {
        // Search for a term that appears in both books' context
        let results = searchService.search(keyword: "pattern")
        // "Design Patterns" book title + "Observer pattern" highlight
        XCTAssertTrue(results.contains { $0.book.bookId == "b2" })
    }
}
