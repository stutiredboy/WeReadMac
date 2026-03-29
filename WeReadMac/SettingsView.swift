import SwiftUI

struct SettingsView: View {
    @AppStorage("customUserAgent") private var customUserAgent: String = ""
    @State private var editingUA: String = ""
    @State private var showingResetAlert = false

    static let defaultUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15 WeReadMac/1.0"

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text("自定义 User-Agent")
                        .font(.headline)

                    Text("设置浏览器 User-Agent 字符串。留空则使用默认值。修改后需要重启应用或刷新页面 (Cmd+R) 生效。")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    TextEditor(text: $editingUA)
                        .font(.system(.body, design: .monospaced))
                        .frame(minHeight: 80)
                        .border(Color.secondary.opacity(0.3))

                    HStack {
                        Button("恢复默认") {
                            showingResetAlert = true
                        }
                        .alert("确认恢复默认 User-Agent？", isPresented: $showingResetAlert) {
                            Button("取消", role: .cancel) {}
                            Button("恢复") {
                                editingUA = ""
                                customUserAgent = ""
                            }
                        }

                        Spacer()

                        Button("保存") {
                            customUserAgent = editingUA.trimmingCharacters(in: .whitespacesAndNewlines)
                            NotificationCenter.default.post(name: .userAgentChanged, object: nil)
                        }
                        .keyboardShortcut(.return, modifiers: .command)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("当前默认 User-Agent：")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(Self.defaultUserAgent)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.secondary)
                            .textSelection(.enabled)
                    }
                }
                .padding()
            }
        }
        .frame(width: 520, height: 320)
        .onAppear {
            editingUA = customUserAgent
        }
    }
}

extension Notification.Name {
    static let userAgentChanged = Notification.Name("userAgentChanged")
}
