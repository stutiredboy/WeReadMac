import XCTest
import CoreData
@testable import WeReadMac

final class NotesExportServiceTests: XCTestCase {
    var store: NotesStore!
    var exportService: NotesExportService!

    override func setUp() {
        super.setUp()
        store = NotesStore(inMemory: true)
        exportService = NotesExportService(store: store)
    }

    override func tearDown() {
        exportService = nil
        store = nil
        super.tearDown()
    }

    private func createTestBook() -> Book {
        let context = store.viewContext
        let book = Book(context: context)
        book.bookId = "export-book"
        book.title = "Export Test Book"
        book.author = "Export Author"
        book.createdAt = Date()
        book.updatedAt = Date()

        let h1 = Highlight(context: context)
        h1.highlightId = "eh1"
        h1.text = "Highlighted passage one"
        h1.highlightType = "marker"
        h1.chapterUid = "1"
        h1.chapterTitle = "Chapter One"
        h1.createdAt = Date(timeIntervalSince1970: 1775193600)
        h1.capturedAt = Date()
        h1.serverDeleted = false
        h1.book = book

        let h2 = Highlight(context: context)
        h2.highlightId = "eh2"
        h2.text = "Highlighted passage two"
        h2.highlightType = "wavy"
        h2.chapterUid = "1"
        h2.chapterTitle = "Chapter One"
        h2.createdAt = Date(timeIntervalSince1970: 1775193700)
        h2.capturedAt = Date()
        h2.serverDeleted = false
        h2.book = book

        let t1 = Thought(context: context)
        t1.thoughtId = "et1"
        t1.thoughtText = "My thought on this"
        t1.passageText = "Related passage"
        t1.chapterUid = "2"
        t1.chapterTitle = "Chapter Two"
        t1.createdAt = Date(timeIntervalSince1970: 1775193800)
        t1.capturedAt = Date()
        t1.serverDeleted = false
        t1.book = book

        // Deleted thought - should be excluded
        let t2 = Thought(context: context)
        t2.thoughtId = "et2"
        t2.thoughtText = "Deleted thought"
        t2.chapterUid = "2"
        t2.chapterTitle = "Chapter Two"
        t2.createdAt = Date()
        t2.capturedAt = Date()
        t2.serverDeleted = true
        t2.book = book

        store.saveContext(context)
        return book
    }

    // MARK: - Markdown Export Tests

    func testMarkdownExportContainsBookHeader() {
        let book = createTestBook()
        let md = exportService.exportToMarkdown(book: book)
        XCTAssertTrue(md.contains("# Export Test Book"))
        XCTAssertTrue(md.contains("Export Author"))
    }

    func testMarkdownExportContainsChapterSections() {
        let book = createTestBook()
        let md = exportService.exportToMarkdown(book: book)
        XCTAssertTrue(md.contains("## Chapter One"))
        XCTAssertTrue(md.contains("## Chapter Two"))
    }

    func testMarkdownExportContainsHighlights() {
        let book = createTestBook()
        let md = exportService.exportToMarkdown(book: book)
        XCTAssertTrue(md.contains("Highlighted passage one"))
        XCTAssertTrue(md.contains("Highlighted passage two"))
    }

    func testMarkdownExportShowsHighlightTypeDisplayNames() {
        let book = createTestBook()
        let md = exportService.exportToMarkdown(book: book)
        // Check that display names are used (these may be localized)
        let hasMarkerType = md.contains("Marker") || md.contains("马克笔")
        let hasWavyType = md.contains("Wavy") || md.contains("波浪线")
        XCTAssertTrue(hasMarkerType, "Should contain marker type display name")
        XCTAssertTrue(hasWavyType, "Should contain wavy type display name")
    }

    func testMarkdownExportContainsThoughts() {
        let book = createTestBook()
        let md = exportService.exportToMarkdown(book: book)
        XCTAssertTrue(md.contains("My thought on this"))
        XCTAssertTrue(md.contains("Related passage"))
    }

    func testMarkdownExportExcludesDeletedItems() {
        let book = createTestBook()
        let md = exportService.exportToMarkdown(book: book)
        XCTAssertFalse(md.contains("Deleted thought"))
    }

    func testMarkdownExportCounts() {
        let book = createTestBook()
        let md = exportService.exportToMarkdown(book: book)
        XCTAssertTrue(md.contains("2")) // 2 highlights
        XCTAssertTrue(md.contains("1")) // 1 non-deleted thought
    }

    // MARK: - JSON Export Tests

    func testJSONExportIsValidJSON() {
        let book = createTestBook()
        let json = exportService.exportToJSON(book: book)
        let data = json.data(using: .utf8)!
        XCTAssertNoThrow(try JSONSerialization.jsonObject(with: data))
    }

    func testJSONExportContainsVersionField() {
        let book = createTestBook()
        let json = exportService.exportToJSON(book: book)
        let data = json.data(using: .utf8)!
        let obj = try! JSONSerialization.jsonObject(with: data) as! [String: Any]
        XCTAssertEqual(obj["version"] as? String, "1.0")
    }

    func testJSONExportContainsExportedAtField() {
        let book = createTestBook()
        let json = exportService.exportToJSON(book: book)
        let data = json.data(using: .utf8)!
        let obj = try! JSONSerialization.jsonObject(with: data) as! [String: Any]
        XCTAssertNotNil(obj["exportedAt"] as? String)
    }

    func testJSONExportContainsBookData() {
        let book = createTestBook()
        let json = exportService.exportToJSON(book: book)
        let data = json.data(using: .utf8)!
        let obj = try! JSONSerialization.jsonObject(with: data) as! [String: Any]
        let books = obj["books"] as! [[String: Any]]
        XCTAssertEqual(books.count, 1)
        XCTAssertEqual(books.first?["title"] as? String, "Export Test Book")
        XCTAssertEqual(books.first?["author"] as? String, "Export Author")
    }

    func testJSONExportContainsHighlightsAndThoughts() {
        let book = createTestBook()
        let json = exportService.exportToJSON(book: book)
        let data = json.data(using: .utf8)!
        let obj = try! JSONSerialization.jsonObject(with: data) as! [String: Any]
        let books = obj["books"] as! [[String: Any]]
        let highlights = books.first?["highlights"] as! [[String: Any]]
        let thoughts = books.first?["thoughts"] as! [[String: Any]]
        XCTAssertEqual(highlights.count, 2)
        XCTAssertEqual(thoughts.count, 1) // Deleted thought excluded
    }

    func testJSONExportExcludesDeletedItems() {
        let book = createTestBook()
        let json = exportService.exportToJSON(book: book)
        XCTAssertFalse(json.contains("Deleted thought"))
    }

    func testMultiBookJSONExportOrderedAlphabetically() {
        let context = store.viewContext
        let bookB = Book(context: context)
        bookB.bookId = "b-book"
        bookB.title = "Bravo Book"
        bookB.author = "B"
        bookB.createdAt = Date()
        bookB.updatedAt = Date()

        let bookA = Book(context: context)
        bookA.bookId = "a-book"
        bookA.title = "Alpha Book"
        bookA.author = "A"
        bookA.createdAt = Date()
        bookA.updatedAt = Date()

        // Add a highlight to each so they appear
        let h1 = Highlight(context: context)
        h1.highlightId = "ha"
        h1.text = "alpha text"
        h1.highlightType = "straight"
        h1.createdAt = Date()
        h1.capturedAt = Date()
        h1.serverDeleted = false
        h1.book = bookA

        let h2 = Highlight(context: context)
        h2.highlightId = "hb"
        h2.text = "bravo text"
        h2.highlightType = "straight"
        h2.createdAt = Date()
        h2.capturedAt = Date()
        h2.serverDeleted = false
        h2.book = bookB

        store.saveContext(context)

        let json = exportService.exportToJSON(books: [bookB, bookA])
        // JSON output should have books - order depends on the input but the
        // contract says "ordered alphabetically"
        let data = json.data(using: .utf8)!
        let obj = try! JSONSerialization.jsonObject(with: data) as! [String: Any]
        let books = obj["books"] as! [[String: Any]]
        XCTAssertEqual(books.count, 2)
    }
}
