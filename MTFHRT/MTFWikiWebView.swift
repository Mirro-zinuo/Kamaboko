import SwiftUI
import WebKit

struct MTFWikiWebView: UIViewRepresentable {
    let localFileURL: URL

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.allowsBackForwardNavigationGestures = true
        webView.scrollView.contentInsetAdjustmentBehavior = .automatic
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        webView.loadFileURL(localFileURL, allowingReadAccessTo: localFileURL.deletingLastPathComponent())
    }
}
