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
            }
        }

        Settings {
            SettingsView()
        }
    }
}

extension Notification.Name {
    static let webViewReload = Notification.Name("webViewReload")
    static let webViewGoBack = Notification.Name("webViewGoBack")
    static let webViewGoForward = Notification.Name("webViewGoForward")
}
