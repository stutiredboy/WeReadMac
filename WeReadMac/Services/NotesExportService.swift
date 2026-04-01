import CoreData
import Foundation

final class NotesExportService {
    private let store: NotesStore
    private let dateFormatter: DateFormatter
    private let isoFormatter: ISO8601DateFormatter

    init(store: NotesStore = .shared) {
        self.store = store
        self.dateFormatter = DateFormatter()
        self.dateFormatter.dateFormat = "yyyy-MM-dd HH:mm"
        self.isoFormatter = ISO8601DateFormatter()
        self.isoFormatter.formatOptions = [.withInternetDateTime]
    }

    // MARK: - Markdown Export

    func exportToMarkdown(books: [Book]) -> String {
        books.map { markdownForBook($0) }.joined(separator: "\n\n---\n\n")
    }

    func exportToMarkdown(book: Book) -> String {
        markdownForBook(book)
    }

    private func markdownForBook(_ book: Book) -> String {
        var lines = [String]()

        let title = book.title ?? "未知书籍"
        let author = book.author ?? "未知作者"

        let allHighlights = (book.highlights?.allObjects as? [Highlight])?.filter { !$0.serverDeleted }
            .sorted { ($0.createdAt ?? .distantPast) < ($1.createdAt ?? .distantPast) } ?? []
        let allThoughts = (book.thoughts?.allObjects as? [Thought])?.filter { !$0.serverDeleted }
            .sorted { ($0.createdAt ?? .distantPast) < ($1.createdAt ?? .distantPast) } ?? []

        lines.append("# \(title)")
        lines.append("")
        lines.append("**作者**: \(author)  ")
        lines.append("**导出时间**: \(dateFormatter.string(from: Date()))  ")
        lines.append("**划线数**: \(allHighlights.count) | **想法数**: \(allThoughts.count)")

        // Group by chapter
        let chapters = groupByChapter(highlights: allHighlights, thoughts: allThoughts)

        for chapter in chapters {
            lines.append("")
            lines.append("---")
            lines.append("")
            lines.append("## \(chapter.title)")

            if !chapter.highlights.isEmpty {
                lines.append("")
                lines.append("### 划线")

                for h in chapter.highlights {
                    lines.append("")
                    lines.append("> \(h.text ?? "")")
                    lines.append("> ")
                    let typeName = displayNameForHighlightType(h.highlightType ?? "straight")
                    let date = h.createdAt.map { dateFormatter.string(from: $0) } ?? ""
                    lines.append("> — *\(typeName)* · \(date)")
                }
            }

            if !chapter.thoughts.isEmpty {
                lines.append("")
                lines.append("### 想法")

                for t in chapter.thoughts {
                    lines.append("")
                    if let passage = t.passageText, !passage.isEmpty {
                        lines.append("> **原文**: \(passage)")
                        lines.append("> ")
                    }
                    lines.append("> **想法**: \(t.thoughtText ?? "")")
                    lines.append("> ")
                    let date = t.createdAt.map { dateFormatter.string(from: $0) } ?? ""
                    lines.append("> — \(date)")
                }
            }
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - JSON Export

    func exportToJSON(books: [Book]) -> String {
        let booksData = books.map { jsonForBook($0) }
        let root: [String: Any] = [
            "exportedAt": isoFormatter.string(from: Date()),
            "version": "1.0",
            "books": booksData
        ]
        return jsonPrettyString(root) ?? "{}"
    }

    func exportToJSON(book: Book) -> String {
        exportToJSON(books: [book])
    }

    private func jsonForBook(_ book: Book) -> [String: Any] {
        let allHighlights = (book.highlights?.allObjects as? [Highlight])?.filter { !$0.serverDeleted }
            .sorted { ($0.createdAt ?? .distantPast) < ($1.createdAt ?? .distantPast) } ?? []
        let allThoughts = (book.thoughts?.allObjects as? [Thought])?.filter { !$0.serverDeleted }
            .sorted { ($0.createdAt ?? .distantPast) < ($1.createdAt ?? .distantPast) } ?? []

        var dict: [String: Any] = [
            "bookId": book.bookId ?? "",
            "title": book.title ?? "",
            "author": book.author ?? ""
        ]
        if let coverURL = book.coverURL { dict["coverURL"] = coverURL }

        dict["highlights"] = allHighlights.map { h -> [String: Any] in
            var item: [String: Any] = [
                "highlightId": h.highlightId ?? "",
                "text": h.text ?? "",
                "highlightType": h.highlightType ?? "straight",
                "createdAt": h.createdAt.map { isoFormatter.string(from: $0) } ?? ""
            ]
            if let v = h.chapterUid { item["chapterUid"] = v }
            if let v = h.chapterTitle { item["chapterTitle"] = v }
            if let v = h.range { item["range"] = v }
            return item
        }

        dict["thoughts"] = allThoughts.map { t -> [String: Any] in
            var item: [String: Any] = [
                "thoughtId": t.thoughtId ?? "",
                "thoughtText": t.thoughtText ?? "",
                "createdAt": t.createdAt.map { isoFormatter.string(from: $0) } ?? ""
            ]
            if let v = t.passageText { item["passageText"] = v }
            if let v = t.chapterUid { item["chapterUid"] = v }
            if let v = t.chapterTitle { item["chapterTitle"] = v }
            if let v = t.range { item["range"] = v }
            if let v = t.updatedAt { item["updatedAt"] = isoFormatter.string(from: v) }
            return item
        }

        return dict
    }

    // MARK: - Helpers

    private struct ChapterGroup {
        let title: String
        let chapterUid: String?
        var highlights: [Highlight]
        var thoughts: [Thought]
    }

    private func groupByChapter(highlights: [Highlight], thoughts: [Thought]) -> [ChapterGroup] {
        var chapterMap: [String: ChapterGroup] = [:]
        let unknownChapter = "未知章节"

        for h in highlights {
            let key = h.chapterUid ?? "unknown"
            var group = chapterMap[key] ?? ChapterGroup(
                title: h.chapterTitle ?? unknownChapter,
                chapterUid: h.chapterUid,
                highlights: [],
                thoughts: []
            )
            group.highlights.append(h)
            chapterMap[key] = group
        }

        for t in thoughts {
            let key = t.chapterUid ?? "unknown"
            var group = chapterMap[key] ?? ChapterGroup(
                title: t.chapterTitle ?? unknownChapter,
                chapterUid: t.chapterUid,
                highlights: [],
                thoughts: []
            )
            group.thoughts.append(t)
            chapterMap[key] = group
        }

        return chapterMap.values.sorted { ($0.chapterUid ?? "") < ($1.chapterUid ?? "") }
    }

    func displayNameForHighlightType(_ type: String) -> String {
        switch type {
        case "marker": return "马克笔"
        case "wavy": return "波浪线"
        case "straight": return "直线"
        default: return type
        }
    }

    private func jsonPrettyString(_ obj: Any) -> String? {
        guard let data = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys]) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
