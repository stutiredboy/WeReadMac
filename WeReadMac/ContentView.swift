import SwiftUI

struct ContentView: View {
    var body: some View {
        WebView(url: URL(string: "https://weread.qq.com")!)
            .frame(minWidth: 800, minHeight: 600)
    }
}
