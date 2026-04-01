import SwiftUI

struct NotesListView: View {
    @State private var selectedBookId: String?
    @State private var bookResults: [BookSearchResult] = []
    @State private var showExportSheet = false
    @State private var exportFormat: ExportFormat = .markdown
    private let searchService = NotesSearchService()
    private let exportService = NotesExportService()

    var body: some View {
        NavigationSplitView {
            bookSidebar
        } detail: {
            if let selectedBookId,
               let result = bookResults.first(where: { $0.book.bookId == selectedBookId }) {
                bookDetailView(result)
            } else {
                Text("选择一本书来查看笔记")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(minWidth: 700, minHeight: 500)
        .onAppear { refreshBooks() }
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Menu {
                    Button("导出为 Markdown...") {
                        exportFormat = .markdown
                        exportNotes()
                    }
                    Button("导出为 JSON...") {
                        exportFormat = .json
                        exportNotes()
                    }
                } label: {
                    Label("导出", systemImage: "square.and.arrow.up")
                }
                .accessibilityLabel("导出")
            }
        }
    }

    private var bookSidebar: some View {
        List(bookResults, selection: $selectedBookId) { result in
            HStack {
                VStack(alignment: .leading) {
                    Text(result.book.title ?? "未知书籍")
                        .lineLimit(1)
                    Text(result.book.author ?? "")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                Text("\(result.totalCount)")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.15))
                    .cornerRadius(8)
            }
            .tag(result.book.bookId)
            .accessibilityLabel("\(result.book.title ?? ""), \(result.totalCount) notes")
        }
        .listStyle(.sidebar)
        .navigationTitle("书籍")
    }

    private func bookDetailView(_ result: BookSearchResult) -> some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text(result.book.title ?? "未知书籍")
                        .font(.title2)
                        .fontWeight(.bold)
                        .textSelection(.enabled)
                    if let author = result.book.author, !author.isEmpty {
                        Text(author)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .textSelection(.enabled)
                    }
                    Text("划线 \(result.highlights.count) 条 · 想法 \(result.thoughts.count) 条")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }

            if !result.highlights.isEmpty {
                Section("划线") {
                    ForEach(result.highlights, id: \.highlightId) { highlight in
                        HighlightRow(highlight: highlight)
                    }
                }
            }
            if !result.thoughts.isEmpty {
                Section("想法") {
                    ForEach(result.thoughts, id: \.thoughtId) { thought in
                        ThoughtRow(thought: thought)
                    }
                }
            }
        }
        .textSelection(.enabled)
        .navigationTitle(result.book.title ?? "")
    }

    private func refreshBooks() {
        bookResults = searchService.allNotes()
    }

    private func exportNotes() {
        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        panel.title = "导出笔记"

        let books: [Book]
        if let selectedBookId,
           let result = bookResults.first(where: { $0.book.bookId == selectedBookId }) {
            books = [result.book]
            let bookTitle = result.book.title ?? "Notes"
            panel.nameFieldStringValue = exportFormat == .markdown ? "\(bookTitle) - Notes.md" : "\(bookTitle) - Notes.json"
        } else {
            books = bookResults.map(\.book)
            let dateStr = ISO8601DateFormatter().string(from: Date())
            panel.nameFieldStringValue = exportFormat == .markdown ? "WeRead Notes - \(dateStr).md" : "WeRead Notes Export - \(dateStr).json"
        }

        panel.allowedContentTypes = exportFormat == .markdown
            ? [.plainText]
            : [.json]

        guard panel.runModal() == .OK, let url = panel.url else { return }

        let content: String
        switch exportFormat {
        case .markdown:
            content = exportService.exportToMarkdown(books: books)
        case .json:
            content = exportService.exportToJSON(books: books)
        }

        try? content.write(to: url, atomically: true, encoding: .utf8)
    }
}

enum ExportFormat {
    case markdown
    case json
}
