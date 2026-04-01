import CoreData

struct BookSearchResult: Identifiable {
    let book: Book
    let highlights: [Highlight]
    let thoughts: [Thought]

    var id: String { book.bookId ?? UUID().uuidString }
    var totalCount: Int { highlights.count + thoughts.count }
}

final class NotesSearchService {
    private let store: NotesStore

    init(store: NotesStore = .shared) {
        self.store = store
    }

    func search(keyword: String, bookFilter: Book? = nil) -> [BookSearchResult] {
        let context = store.viewContext
        let trimmed = keyword.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            return allNotes(bookFilter: bookFilter, context: context)
        }

        let highlights = searchHighlights(keyword: trimmed, bookFilter: bookFilter, context: context)
        let thoughts = searchThoughts(keyword: trimmed, bookFilter: bookFilter, context: context)

        return groupByBook(highlights: highlights, thoughts: thoughts)
    }

    func allNotes(bookFilter: Book? = nil, context: NSManagedObjectContext? = nil) -> [BookSearchResult] {
        let ctx = context ?? store.viewContext

        let bookRequest: NSFetchRequest<Book> = Book.fetchRequest()
        if let bookFilter {
            bookRequest.predicate = NSPredicate(format: "bookId == %@", bookFilter.bookId ?? "")
        }
        bookRequest.sortDescriptors = [NSSortDescriptor(key: "updatedAt", ascending: false)]

        guard let books = try? ctx.fetch(bookRequest) else { return [] }

        return books.compactMap { book in
            let highlights = (book.highlights?.allObjects as? [Highlight])?.sorted {
                ($0.createdAt ?? .distantPast) < ($1.createdAt ?? .distantPast)
            } ?? []
            let thoughts = (book.thoughts?.allObjects as? [Thought])?.sorted {
                ($0.createdAt ?? .distantPast) < ($1.createdAt ?? .distantPast)
            } ?? []

            guard !highlights.isEmpty || !thoughts.isEmpty else { return nil }
            return BookSearchResult(book: book, highlights: highlights, thoughts: thoughts)
        }
    }

    private func searchHighlights(keyword: String, bookFilter: Book?, context: NSManagedObjectContext) -> [Highlight] {
        let request: NSFetchRequest<Highlight> = Highlight.fetchRequest()
        var predicates = [NSPredicate]()
        predicates.append(NSPredicate(
            format: "text CONTAINS[cd] %@ OR chapterTitle CONTAINS[cd] %@ OR book.title CONTAINS[cd] %@",
            keyword, keyword, keyword
        ))
        predicates.append(NSPredicate(format: "serverDeleted == NO"))
        if let bookFilter {
            predicates.append(NSPredicate(format: "book.bookId == %@", bookFilter.bookId ?? ""))
        }
        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: true)]
        return (try? context.fetch(request)) ?? []
    }

    private func searchThoughts(keyword: String, bookFilter: Book?, context: NSManagedObjectContext) -> [Thought] {
        let request: NSFetchRequest<Thought> = Thought.fetchRequest()
        var predicates = [NSPredicate]()
        predicates.append(NSPredicate(
            format: "thoughtText CONTAINS[cd] %@ OR passageText CONTAINS[cd] %@ OR chapterTitle CONTAINS[cd] %@ OR book.title CONTAINS[cd] %@",
            keyword, keyword, keyword, keyword
        ))
        predicates.append(NSPredicate(format: "serverDeleted == NO"))
        if let bookFilter {
            predicates.append(NSPredicate(format: "book.bookId == %@", bookFilter.bookId ?? ""))
        }
        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: true)]
        return (try? context.fetch(request)) ?? []
    }

    private func groupByBook(highlights: [Highlight], thoughts: [Thought]) -> [BookSearchResult] {
        var bookMap: [String: (book: Book, highlights: [Highlight], thoughts: [Thought])] = [:]

        for h in highlights {
            guard let book = h.book, let bookId = book.bookId else { continue }
            var entry = bookMap[bookId] ?? (book: book, highlights: [], thoughts: [])
            entry.highlights.append(h)
            bookMap[bookId] = entry
        }

        for t in thoughts {
            guard let book = t.book, let bookId = book.bookId else { continue }
            var entry = bookMap[bookId] ?? (book: book, highlights: [], thoughts: [])
            entry.thoughts.append(t)
            bookMap[bookId] = entry
        }

        return bookMap.values.map { entry in
            BookSearchResult(book: entry.book, highlights: entry.highlights, thoughts: entry.thoughts)
        }.sorted { ($0.book.title ?? "") < ($1.book.title ?? "") }
    }
}
