import Foundation
import WebKit

@MainActor
protocol YouTubePlayerController: AnyObject {
    func play()
    func pause()
    func seek(to seconds: Double)
    func loadVideo(url: String)
}
