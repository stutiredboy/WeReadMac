import SwiftUI

struct BrowseNotesFloatingButton: View {
    @Environment(\.openWindow) private var openWindow

    // WeRead brand blue, slightly muted to feel calmer against book content
    private static let weReadBlue = Color(red: 30/255, green: 95/255, blue: 190/255)

    var body: some View {
        Button {
            openWindow(id: "notes-list")
        } label: {
            Label("浏览笔记", systemImage: "note.text")
                .foregroundStyle(Color.white.opacity(0.92))
        }
        .buttonStyle(.borderedProminent)
        .tint(Self.weReadBlue.opacity(0.78))
        .controlSize(.large)
        .shadow(color: Self.weReadBlue.opacity(0.22), radius: 5, x: 0, y: 2)
        .help("浏览笔记")
    }
}
