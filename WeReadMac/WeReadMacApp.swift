import SwiftUI

@main
struct WeReadMacApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .defaultSize(width: 1200, height: 800)
        .commands {
            CommandGroup(after: .toolbar) {
                Button("刷新页面") {
                    NotificationCenter.default.post(name: .webViewReload, object: nil)
                }
                .keyboardShortcut("r", modifiers: .command)

                Button("后退") {
                    NotificationCenter.default.post(name: .webViewGoBack, object: nil)
                }
                .keyboardShortcut("[", modifiers: .command)

                Button("前进") {
                    NotificationCenter.default.post(name: .webViewGoForward, object: nil)
                }
                .keyboardShortcut("]", modifiers: .command)

                Divider()

                NotesMenuButtons()
            }
        }

        Settings {
            SettingsView()
        }

        Window("搜索笔记", id: "notes-search") {
            NotesSearchView()
        }
        .defaultSize(width: 600, height: 500)

        Window("浏览笔记", id: "notes-list") {
            NotesListView()
        }
        .defaultSize(width: 800, height: 600)
    }
}

/// Extracted into a View so we can use @Environment(\.openWindow)
struct NotesMenuButtons: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("搜索笔记") {
            openWindow(id: "notes-search")
        }
        .keyboardShortcut("n", modifiers: [.command, .shift])

        Button("浏览笔记") {
            openWindow(id: "notes-list")
        }
    }
}

extension Notification.Name {
    static let webViewReload = Notification.Name("webViewReload")
    static let webViewGoBack = Notification.Name("webViewGoBack")
    static let webViewGoForward = Notification.Name("webViewGoForward")
}
