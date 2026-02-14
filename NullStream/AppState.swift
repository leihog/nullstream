import SwiftUI
import Combine

@MainActor
final class AppState: ObservableObject {
    @Published var playerController: YouTubePlayerController?
    @Published var currentVideoURL: String?
    @Published var isPlaying: Bool = false
    @Published var currentTime: Double = 0
    @Published var duration: Double = 0
    @Published var playerReady: Bool = false
    @Published var lastError: String?
    
    var canControlPlayback: Bool {
        playerReady && currentVideoURL != nil
    }
    
    func setPlayerController(_ controller: YouTubePlayerController) {
        playerController = controller
        if let url = currentVideoURL {
            playerController?.loadVideo(url: url)
        }
    }
    
    func play() {
        playerController?.play()
    }
    
    func pause() {
        playerController?.pause()
    }
    
    func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }
    
    func seek(to seconds: Double) {
        currentTime = seconds
        playerController?.seek(to: seconds)
    }
    
    func loadVideo(url: String) {
        currentVideoURL = url
        lastError = nil
        playerController?.loadVideo(url: url)
    }
}
