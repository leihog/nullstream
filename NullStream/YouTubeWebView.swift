import SwiftUI
import WebKit

struct YouTubeWebView: NSViewRepresentable {
    @ObservedObject var bridge: YouTubeBridge
    
    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.userContentController.add(bridge, name: "youtube")
        
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isInspectable = true
        webView.navigationDelegate = context.coordinator
        bridge.webView = webView
        
        loadPlayerHTML(webView: webView)
        
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        bridge.webView = webView
    }
    
    func loadPlayerHTML(webView: WKWebView) {
        guard let htmlURL = Bundle.main.url(forResource: "YouTubePlayer", withExtension: "html", subdirectory: "Resources")
            ?? Bundle.main.url(forResource: "YouTubePlayer", withExtension: "html", subdirectory: nil),
            let html = try? String(contentsOf: htmlURL, encoding: .utf8) else {
            print("Failed to load player.html from bundle")
            return
        }

        let baseURL = URL(string: "https://gomitech.com/")
        webView.loadHTMLString(html, baseURL: baseURL)
    }    

    func makeCoordinator() -> Coordinator {
        Coordinator(bridge: bridge)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        let bridge: YouTubeBridge
        
        init(bridge: YouTubeBridge) {
            self.bridge = bridge
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            bridge.webView = webView
        }
    }
}
