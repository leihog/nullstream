import SwiftUI

private struct WindowDragHandle: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { NSView() }
    func updateNSView(_ nsView: NSView, context: Context) {
        // Allows the user to drag the window by this view
        nsView.window?.isMovableByWindowBackground = true
    }
}

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var videoStore = VideoStore()
    @StateObject private var bridge = YouTubeBridge()
    
    @State private var showLeftPane = true
    @State private var showAddURLSheet = false
    @State private var newURL = ""
    @State private var isSeeking = false
    @State private var seekValue: Double = 0
    private var isWebviewInteractionBlocked = true
    private let topBarHeight: CGFloat = 44
    
    var body: some View {
        ZStack(alignment: .top) {
            GeometryReader { geo in
                let safeTop = geo.safeAreaInsets.top
                let padTop = max(0, topBarHeight - safeTop)
                
                HSplitView {
                    if showLeftPane {
                        leftPane
                            .frame(minWidth: 200, idealWidth: 240, maxWidth: 320)
                    }
                    
                    mainContent
                }
                .padding(.top, padTop)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            TopBar()
                .frame(height: topBarHeight)
                .frame(maxWidth: .infinity)
                .ignoresSafeArea(.container, edges: .top)
        }
        .onAppear {
            setupBridge()
        }
        .sheet(isPresented: $showAddURLSheet) {
            AddURLSheet(
                isPresented: $showAddURLSheet,
                urlText: $newURL,
                onAdd: { url in
                    videoStore.add(url)
                    appState.loadVideo(url: url)
                    Task {
                        if let meta = try? await fetchOEmbed(videoUrl: url) {
                            videoStore.updateMetadata(url: url, title: meta.title, thumbnailURL: meta.thumbnailUrl)
                        }
                    }
                }
            )
        }
        .background(Color.nullBackground)
    }
    
    private struct TopBar: View {
        var body: some View {
            ZStack {
                Color.nullBackground

                Text("NullStream")
                    .font(.headline)
                    .foregroundStyle(Color.primaryText)
            }
            .overlay(alignment: .bottom) {
                Divider()
            }
            .background(WindowDragHandle())
        }
    }
    
    
    private var leftPane: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Videos")
                    .font(.headline)
                Spacer()
                Button(action: { showLeftPane = false }) {
                    Image(systemName: "sidebar.left")
                }
                .buttonStyle(.plain)
            }
            .padding()
            
            Divider()
            
            videoList
        }
        .background(Color.surface)
    }
    
    @ViewBuilder
    private var videoList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 4) {
                ForEach(videoStore.videos) { video in
                    HStack {
                        Button(action: {
                            appState.loadVideo(url: video.url)
                        }) {
                            Text(video.displayName)
                                .lineLimit(1)
                                .truncationMode(.tail)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                        
                        Button(action: {
                            videoStore.remove(video.url)
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                                .font(.caption)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        appState.currentVideoURL == video.url
                            ? Color.accentColor.opacity(0.2)
                            : Color.clear
                    )
                    .cornerRadius(6)
                }
            }
            .padding(8)
        }
        
        Divider()
        
        Button(action: { showAddURLSheet = true }) {
            Label("Add URL", systemImage: "plus.circle.fill")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .padding()
    }
    
    @ViewBuilder
    private var mainContent: some View {
        Group {
            if appState.currentVideoURL == nil {
                noVideoPlaceholderView
            } else {
                playerView
            }
        }
        .frame(minWidth: 480, minHeight: 360)
        .background(Color.nullBackground)
    }

    private var noVideoPlaceholderView: some View {
        ZStack(alignment: .topLeading) {
            VStack(spacing: 20) {
                Image("nullstream_logo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: 356)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.nullBackground)
            if !showLeftPane {
                Button(action: { showLeftPane = true }) {
                    Image(systemName: "sidebar.left")
                        .padding(8)
                        .background(.ultraThinMaterial)
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .padding(8)
            }
        }
    }
    
    private var playerView: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .topLeading) {
                YouTubeWebView(bridge: bridge)
                    .background(Color.black)
 
                if !showLeftPane {
                    Button(action: { showLeftPane = true }) {
                        Image(systemName: "sidebar.left")
                            .padding(8)
                            .background(.ultraThinMaterial)
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    .padding(8)
                    .zIndex(20)
                }
            }
            
            Divider()
            
            playerControls
        }
    }
    
    private var playerControls: some View {
        HStack(spacing: 16) {
            Button(action: { appState.togglePlayPause() }) {
                Image(systemName: appState.isPlaying ? "pause.fill" : "play.fill")
                    .font(.title2)
            }
            .buttonStyle(.plain)
            .disabled(!appState.canControlPlayback)
            
            Text(formatTime(isSeeking ? seekValue : appState.currentTime))
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(Color.secondaryText)
            
            Slider(
                value: Binding(
                    get: { isSeeking ? seekValue : appState.currentTime },
                    set: { newValue in
                        seekValue = newValue
                        isSeeking = true
                    }
                ),
                in: 0...max(appState.duration, 1)
            ) { editing in
                if !editing {
                    appState.seek(to: seekValue)
                    isSeeking = false
                }
            }
            .disabled(!appState.canControlPlayback)
            
            Text(formatTime(appState.duration))
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(Color.secondaryText)
            
            Spacer()
            
            Button(action: { showAddURLSheet = true }) {
                Image(systemName: "plus.rectangle")
            }
            .buttonStyle(.plain)
            
            if let err = appState.lastError {
                Text(err)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding(12)
        .background(Color.nullBackground)
        .foregroundStyle(Color.primaryText)
    }
    
    private func setupBridge() {
        appState.setPlayerController(bridge)
        bridge.onReady = {
            appState.playerReady = true
        }
        bridge.onStateChange = { state in
            appState.isPlaying = (state == 1)
        }
        bridge.onTimeUpdate = { time in
            appState.currentTime = time
        }
        bridge.onDurationChange = { dur in
            appState.duration = dur
        }
        bridge.onError = { err in
            appState.lastError = err
        }
    }
    
    private func formatTime(_ seconds: Double) -> String {
        let m = Int(seconds) / 60
        let s = Int(seconds) % 60
        return String(format: "%d:%02d", m, s)
    }
}

// MARK: - Add URL Sheet
struct AddURLSheet: View {
    @Binding var isPresented: Bool
    @Binding var urlText: String
    @FocusState private var isFocused: Bool
    let onAdd: (String) -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Add YouTube Video")
                .font(.headline)
      
            ZStack(alignment: .leading) {
                if urlText.isEmpty {
                    Text("YouTube URL")
                        .foregroundStyle(Color("SecondaryTextColor").opacity(0.8))
                        .padding(.horizontal, 12)
                }

                TextField("", text: $urlText)
                    .textFieldStyle(.plain)
                    .foregroundStyle(Color("PrimaryTextColor"))
                    .padding(.vertical, 10)
                    .padding(.horizontal, 12)
            }
            .background(Color("InputBackgroundColor"))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color("InputBorderColor").opacity(0.7), lineWidth: 1)
            )
            
            
            HStack {
                Button("Cancel") {
                    isPresented = false
                }
                .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                Button("Add") {
                    onAdd(urlText)
                    urlText = ""
                    isPresented = false
                }
                .keyboardShortcut(.defaultAction)
                .disabled(urlText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 400)
        .background(Color("ElevatedSurfaceColor"))
        .foregroundStyle(Color("PrimaryTextColor"))
    }
}

private extension Bundle {
    var appName: String {
        (infoDictionary?["CFBundleName"] as? String) ?? "NullStream"
    }
}
