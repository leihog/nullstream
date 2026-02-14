import Foundation
import WebKit
import Combine

@MainActor
final class YouTubeBridge: NSObject, ObservableObject, WKScriptMessageHandler, YouTubePlayerController {
    weak var webView: WKWebView?
    private var pendingVideoURL: String?
    
    var onReady: (() -> Void)?
    var onStateChange: ((Int) -> Void)?
    var onTimeUpdate: ((Double) -> Void)?
    var onDurationChange: ((Double) -> Void)?
    var onError: ((String) -> Void)?
    
    private func extractVideoId(from url: String) -> String? {
        let patterns = [
            "(?:youtube\\.com\\/watch\\?v=|youtu\\.be\\/|youtube\\.com\\/embed\\/)([^&?\\/]+)",
            "youtube\\.com\\/shorts\\/([^&?\\/]+)"
        ]
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: url, range: NSRange(url.startIndex..., in: url)),
               let range = Range(match.range(at: 1), in: url) {
                return String(url[range])
            }
        }
        return nil
    }
    
    private func eval(_ js: String) {
        webView?.evaluateJavaScript("(function(){ \(js); return null; })()")
    }

    func loadVideo(url: String) {
        guard let videoId = extractVideoId(from: url) else {
            onError?("Invalid YouTube URL")
            return
        }
        if webView != nil {
            eval("appPlayer.loadVideoById('\(videoId)')")

            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 1_200_000_000)
                play()
            }
        } else {
            pendingVideoURL = url
        }
    }
    
    func play() {
        eval("player.playVideo()")
    }
    
    func pause() {
        eval("player.pauseVideo()")
    }
    
    func seek(to seconds: Double) {
        eval("appPlayer.seekTo(\(seconds))")
    }
    
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == "youtube", let body = message.body as? [String: Any] else { return }
        
        Task { @MainActor in
            if let event = body["event"] as? String {
                switch event {
                case "ready":
                    onReady?()
                    if let url = pendingVideoURL {
                        pendingVideoURL = nil
                        loadVideo(url: url)
                    }
                case "state":
                    if let state = body["value"] as? Int {
                        onStateChange?(state)
                    }
                case "time":
                    if let time = body["value"] as? Double {
                        onTimeUpdate?(time)
                    }
                case "duration":
                    if let dur = body["value"] as? Double {
                        onDurationChange?(dur)
                    }
                case "error":
                    if let err = body["value"] as? String {
                        onError?(err)
                    }
                default:
                    break
                }
            }
        }
    }
}
