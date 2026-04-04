import SwiftUI

struct NotesSearchView: View {
    @State private var searchText = ""
    @State private var results: [BookSearchResult] = []
    private let searchService = NotesSearchService()

    var body: some View {
        VStack(spacing: 0) {
            searchBar
            Divider()
            if results.isEmpty {
                emptyState
            } else {
                resultsList
            }
        }
        .frame(minWidth: 500, minHeight: 400)
        .onChange(of: searchText) { _ in
            performSearch()
        }
        .onAppear {
            performSearch()
        }
    }

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            TextField(
                "搜索笔记...",
                text: $searchText
            )
            .textFieldStyle(.plain)
            .accessibilityLabel("搜索笔记")

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("清除搜索")
            }
        }
        .padding(12)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: searchText.isEmpty ? "note.text" : "magnifyingglass")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            Text(searchText.isEmpty ? "暂无笔记" : "未找到结果")
                .foregroundColor(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .accessibilityLabel(searchText.isEmpty ? "暂无笔记" : "未找到结果")
    }

    private var resultsList: some View {
        List {
            ForEach(results) { result in
                Section {
                    ForEach(result.highlights, id: \.highlightId) { highlight in
                        HighlightRow(highlight: highlight)
                    }
                    ForEach(result.thoughts, id: \.thoughtId) { thought in
                        ThoughtRow(thought: thought)
                    }
                } header: {
                    HStack {
                        Text(result.book.title ?? "未知书籍")
                            .font(.headline)
                        Spacer()
                        Text("\(result.totalCount)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .accessibilityLabel("\(result.book.title ?? ""), \(result.totalCount) notes")
                }
            }
        }
    }

    private func performSearch() {
        results = searchService.search(keyword: searchText)
    }
}

struct HighlightRow: View {
    let highlight: Highlight
    var onDelete: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(highlight.text ?? "")
                .lineLimit(3)
                .textSelection(.enabled)
            HStack {
                highlightTypeBadge
                if let chapter = highlight.chapterTitle {
                    Text(chapter)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                if let onDelete {
                    Button(role: .destructive, action: onDelete) {
                        Image(systemName: "trash")
                            .font(.caption)
                    }
                    .buttonStyle(.borderless)
                    .help("删除")
                }
                if let date = highlight.createdAt {
                    Text(date, style: .date)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }

    private var highlightTypeBadge: some View {
        let typeName: String = {
            switch highlight.highlightType {
            case "marker": return "马克笔"
            case "wavy": return "波浪线"
            default: return "直线"
            }
        }()
        return Text(typeName)
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.accentColor.opacity(0.15))
            .cornerRadius(4)
    }
}

struct ThoughtRow: View {
    let thought: Thought
    var onDelete: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let passage = thought.passageText, !passage.isEmpty {
                Text(passage)
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .textSelection(.enabled)
            }
            Text(thought.thoughtText ?? "")
                .lineLimit(3)
                .textSelection(.enabled)
            HStack {
                Text("想法")
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.orange.opacity(0.15))
                    .cornerRadius(4)
                if let chapter = thought.chapterTitle {
                    Text(chapter)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                if let onDelete {
                    Button(role: .destructive, action: onDelete) {
                        Image(systemName: "trash")
                            .font(.caption)
                    }
                    .buttonStyle(.borderless)
                    .help("删除")
                }
                if let date = thought.createdAt {
                    Text(date, style: .date)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }
}
