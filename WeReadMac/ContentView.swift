import SwiftUI

struct ContentView: View {
    @StateObject private var readerState = ReaderState()

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            WebView(url: URL(string: "https://weread.qq.com")!, readerState: readerState)
                .frame(minWidth: 800, minHeight: 600)

            if readerState.isReaderView {
                BrowseNotesFloatingButton()
                    .padding(16)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.15), value: readerState.isReaderView)
    }
}
