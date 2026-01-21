//
//  VideoPlayerView.swift
//  IPTV One
//
//  Created by Robin Nap on 21/01/2026.
//

import SwiftUI
import AVKit
import AVFoundation
import Combine

// MARK: - Custom Player Layer View (No built-in controls)

#if os(iOS)
struct PlayerLayerView: UIViewRepresentable {
    let player: AVPlayer
    
    func makeUIView(context: Context) -> PlayerUIView {
        let view = PlayerUIView()
        view.player = player
        return view
    }
    
    func updateUIView(_ uiView: PlayerUIView, context: Context) {
        uiView.player = player
    }
}

class PlayerUIView: UIView {
    override class var layerClass: AnyClass {
        AVPlayerLayer.self
    }
    
    var playerLayer: AVPlayerLayer {
        layer as! AVPlayerLayer
    }
    
    var player: AVPlayer? {
        get { playerLayer.player }
        set {
            playerLayer.player = newValue
            playerLayer.videoGravity = .resizeAspect
        }
    }
}

#else
struct PlayerLayerView: NSViewRepresentable {
    let player: AVPlayer
    
    func makeNSView(context: Context) -> PlayerNSView {
        let view = PlayerNSView()
        view.player = player
        return view
    }
    
    func updateNSView(_ nsView: PlayerNSView, context: Context) {
        nsView.player = player
    }
}

class PlayerNSView: NSView {
    private var playerLayer: AVPlayerLayer?
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupLayer()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupLayer()
    }
    
    private func setupLayer() {
        wantsLayer = true
        playerLayer = AVPlayerLayer()
        playerLayer?.videoGravity = .resizeAspect
        layer?.addSublayer(playerLayer!)
    }
    
    override func layout() {
        super.layout()
        playerLayer?.frame = bounds
    }
    
    var player: AVPlayer? {
        get { playerLayer?.player }
        set { playerLayer?.player = newValue }
    }
}
#endif

// MARK: - Video Player View

struct VideoPlayerView: View {
    let title: String
    let streamURL: String
    var posterURL: String?
    var isLiveStream: Bool = true
    
    @Environment(\.dismiss) private var dismiss
    @StateObject private var playerController = VideoPlayerController()
    @State private var showControls = true
    @State private var controlsTimer: Timer?
    @State private var isSeeking = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.ignoresSafeArea()
                
                // Video Player - Custom layer view without Apple's controls
                if let player = playerController.player {
                    PlayerLayerView(player: player)
                        .ignoresSafeArea()
                }
                
                // Tap gesture layer (on top of video)
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        toggleControls()
                    }
                
                // Loading indicator
                if playerController.isLoading && playerController.error == nil {
                    VStack(spacing: 12) {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(.white)
                            .scaleEffect(1.5)
                        Text(playerController.loadingMessage)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
                
                // Buffering indicator (when playing but buffering)
                if playerController.isBuffering && !playerController.isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                        .scaleEffect(1.2)
                }
                
                // Error view
                if let error = playerController.error {
                    errorView(error)
                }
                
                // Custom controls overlay
                if showControls {
                    controlsOverlay(size: geometry.size)
                }
            }
        }
        .background(Color.black)
        .onAppear {
            playerController.setup(url: streamURL, isLive: isLiveStream)
        }
        .onDisappear {
            playerController.cleanup()
            controlsTimer?.invalidate()
        }
        .statusBarHidden(true)
        #if os(iOS)
        .persistentSystemOverlays(.hidden)
        #endif
    }
    
    // MARK: - Controls Overlay
    
    private func controlsOverlay(size: CGSize) -> some View {
        ZStack {
            // Gradient background
            VStack {
                LinearGradient(
                    colors: [.black.opacity(0.7), .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 120)
                
                Spacer()
                
                LinearGradient(
                    colors: [.clear, .black.opacity(0.7)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 160)
            }
            .ignoresSafeArea()
            
            VStack {
                // Top bar
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(Circle().fill(Color.white.opacity(0.2)))
                    }
                    .buttonStyle(.plain)
                    
                    Spacer()
                    
                    VStack(spacing: 2) {
                        Text(title)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        
                        if isLiveStream {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 6, height: 6)
                                Text("LIVE")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(.red)
                            }
                        }
                    }
                    
                    Spacer()
                    
                    // PiP button
                    #if os(iOS)
                    Button {
                        // PiP handled by system
                    } label: {
                        Image(systemName: "pip.enter")
                            .font(.system(size: 18))
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(Circle().fill(Color.white.opacity(0.2)))
                    }
                    .buttonStyle(.plain)
                    #else
                    Color.clear.frame(width: 44)
                    #endif
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                
                Spacer()
                
                // Center play/pause
                HStack(spacing: 48) {
                    // Rewind 10s
                    Button {
                        playerController.seek(by: -10)
                        resetControlsTimer()
                    } label: {
                        Image(systemName: "gobackward.10")
                            .font(.system(size: 32))
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                    .opacity(isLiveStream ? 0.5 : 1)
                    .disabled(isLiveStream)
                    
                    // Play/Pause
                    Button {
                        playerController.togglePlayPause()
                        resetControlsTimer()
                    } label: {
                        Image(systemName: playerController.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(.white)
                            .frame(width: 72, height: 72)
                            .background(Circle().fill(Color.white.opacity(0.2)))
                    }
                    .buttonStyle(.plain)
                    
                    // Forward 10s
                    Button {
                        playerController.seek(by: 10)
                        resetControlsTimer()
                    } label: {
                        Image(systemName: "goforward.10")
                            .font(.system(size: 32))
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                    .opacity(isLiveStream ? 0.5 : 1)
                    .disabled(isLiveStream)
                }
                
                Spacer()
                
                // Bottom bar with progress
                VStack(spacing: 12) {
                    if !isLiveStream {
                        // Progress bar (only for VOD)
                        ProgressSlider(
                            value: Binding(
                                get: { playerController.currentTime },
                                set: { playerController.currentTime = $0 }
                            ),
                            in: 0...max(playerController.duration, 1),
                            isSeeking: $isSeeking
                        ) { editing in
                            if !editing {
                                playerController.seekTo(time: playerController.currentTime)
                            }
                        }
                        
                        // Time labels
                        HStack {
                            Text(formatTime(playerController.currentTime))
                                .font(.system(size: 12, weight: .medium, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.8))
                            
                            Spacer()
                            
                            Text(formatTime(playerController.duration))
                                .font(.system(size: 12, weight: .medium, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.8))
                        }
                    } else {
                        // Live indicator bar
                        HStack {
                            Text("Live")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.white.opacity(0.8))
                            
                            Spacer()
                            
                            // Quality indicator
                            if let bitrate = playerController.currentBitrate {
                                Text(formatBitrate(bitrate))
                                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                                    .foregroundStyle(.white.opacity(0.6))
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
        }
        .transition(.opacity)
    }
    
    private func errorView(_ error: Error) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.orange)
            
            Text("Playback Error")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
            
            Text(error.localizedDescription)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            HStack(spacing: 16) {
                Button {
                    dismiss()
                } label: {
                    Text("Close")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.white.opacity(0.2))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                
                Button {
                    playerController.retry()
                } label: {
                    Text("Retry")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.primaryAccent)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    private func toggleControls() {
        withAnimation(.easeInOut(duration: 0.2)) {
            showControls.toggle()
        }
        if showControls {
            resetControlsTimer()
        }
    }
    
    private func resetControlsTimer() {
        controlsTimer?.invalidate()
        controlsTimer = Timer.scheduledTimer(withTimeInterval: 4, repeats: false) { _ in
            if playerController.isPlaying {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showControls = false
                }
            }
        }
    }
    
    private func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite && seconds >= 0 else { return "00:00" }
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        let secs = Int(seconds) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%02d:%02d", minutes, secs)
    }
    
    private func formatBitrate(_ bitrate: Double) -> String {
        if bitrate >= 1_000_000 {
            return String(format: "%.1f Mbps", bitrate / 1_000_000)
        } else if bitrate >= 1000 {
            return String(format: "%.0f Kbps", bitrate / 1000)
        }
        return "\(Int(bitrate)) bps"
    }
}

// MARK: - Video Player Controller

@MainActor
class VideoPlayerController: ObservableObject {
    @Published var player: AVPlayer?
    @Published var isPlaying = false
    @Published var isLoading = true
    @Published var isBuffering = false
    @Published var loadingMessage = "Starting proxy..."
    @Published var error: Error?
    @Published var currentTime: Double = 0
    @Published var duration: Double = 0
    @Published var currentBitrate: Double?
    
    private var streamURL: String = ""
    private var isLiveStream: Bool = true
    private var currentURLIndex = 0
    private var urlVariants: [String] = []
    private var cancellables = Set<AnyCancellable>()
    private var timeObserver: Any?
    private var accessLogObserver: NSObjectProtocol?
    
    /// Extract Xtream credentials from URL if present
    private func extractCredentials(from urlString: String) -> (username: String, password: String)? {
        guard let url = URL(string: urlString) else { return nil }
        let pathComponents = url.pathComponents
        
        if let typeIndex = pathComponents.firstIndex(where: { $0 == "live" || $0 == "movie" || $0 == "series" }),
           typeIndex + 2 < pathComponents.count {
            return (pathComponents[typeIndex + 1], pathComponents[typeIndex + 2])
        }
        return nil
    }
    
    /// Generate all URL variants to try
    private func generateURLVariants(from url: String) -> [String] {
        var variants: [String] = []
        
        // Helper to add both HTTP and HTTPS versions
        func addWithHTTPS(_ urlString: String) {
            variants.append(urlString)
            // Also try HTTPS version if it's HTTP (many CDNs redirect to HTTPS)
            if urlString.hasPrefix("http://") {
                variants.append(urlString.replacingOccurrences(of: "http://", with: "https://"))
            }
        }
        
        if isLiveStream {
            // For live streams, try different formats
            // TS format is most common for live IPTV
            if url.hasSuffix(".m3u8") {
                addWithHTTPS(url)
                let base = String(url.dropLast(5))
                addWithHTTPS(base + ".ts")
            } else if url.hasSuffix(".ts") {
                addWithHTTPS(url)
                let base = String(url.dropLast(3))
                addWithHTTPS(base + ".m3u8")
            } else {
                // No extension - try TS first (most common)
                addWithHTTPS(url + ".ts")
                addWithHTTPS(url + ".m3u8")
                addWithHTTPS(url)
            }
        } else {
            // For VOD, just try the URL as-is, with HTTPS fallback
            addWithHTTPS(url)
        }
        
        return variants
    }
    
    func setup(url: String, isLive: Bool) {
        self.streamURL = url
        self.isLiveStream = isLive
        self.urlVariants = generateURLVariants(from: url)
        self.currentURLIndex = 0
        
        // Start proxy server if not running
        Task {
            await startProxyAndPlay()
        }
    }
    
    private func startProxyAndPlay() async {
        loadingMessage = "Starting proxy server..."
        
        // Start the proxy server
        if !StreamProxyServer.shared.isRunning {
            do {
                try await StreamProxyServer.shared.start()
            } catch {
                print("[VideoPlayer] Failed to start proxy: \(error)")
                self.error = error
                self.isLoading = false
                return
            }
        }
        
        loadingMessage = "Connecting..."
        tryCurrentVariant()
    }
    
    private func tryCurrentVariant() {
        guard currentURLIndex < urlVariants.count else {
            error = NSError(
                domain: "StreamError",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Unable to play this stream. The channel may be offline or using an unsupported format."]
            )
            isLoading = false
            return
        }
        
        let originalURL = urlVariants[currentURLIndex]
        let credentials = extractCredentials(from: originalURL)
        
        // Get the proxied URL
        let proxyURL = StreamProxyServer.shared.proxyURL(for: originalURL, credentials: credentials)
        
        guard let url = URL(string: proxyURL) else {
            currentURLIndex += 1
            tryCurrentVariant()
            return
        }
        
        print("[VideoPlayer] Trying variant \(currentURLIndex + 1)/\(urlVariants.count) via proxy: \(originalURL)")
        loadingMessage = currentURLIndex == 0 ? "Connecting..." : "Trying alternate format..."
        
        // Cleanup previous player
        cleanupObservers()
        
        // Create player item - no special options needed since proxy handles everything
        let asset = AVURLAsset(url: url)
        let playerItem = AVPlayerItem(asset: asset)
        
        // Configure for optimal IPTV performance
        if isLiveStream {
            playerItem.preferredForwardBufferDuration = 3
            playerItem.canUseNetworkResourcesForLiveStreamingWhilePaused = false
            playerItem.preferredPeakBitRate = 4_000_000
            playerItem.configuredTimeOffsetFromLive = CMTime(seconds: 3, preferredTimescale: 1)
            playerItem.automaticallyPreservesTimeOffsetFromLive = true
        } else {
            playerItem.preferredForwardBufferDuration = 10
            playerItem.preferredPeakBitRate = 0
        }
        
        let newPlayer = AVPlayer(playerItem: playerItem)
        newPlayer.automaticallyWaitsToMinimizeStalling = !isLiveStream
        
        // Configure audio session
        #if os(iOS)
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("[VideoPlayer] Audio session error: \(error)")
        }
        #endif
        
        player = newPlayer
        setupObservers(for: playerItem)
        
        // Start playback
        newPlayer.playImmediately(atRate: 1.0)
        isPlaying = true
    }
    
    private func setupObservers(for item: AVPlayerItem) {
        // Status observer
        item.publisher(for: \.status)
            .receive(on: DispatchQueue.main)
            .sink { [weak self, weak item] status in
                guard let self = self else { return }
                
                switch status {
                case .readyToPlay:
                    print("[VideoPlayer] ✓ Ready to play")
                    self.isLoading = false
                    self.error = nil
                    item?.preferredPeakBitRate = 0
                    
                case .failed:
                    print("[VideoPlayer] ✗ Failed: \(item?.error?.localizedDescription ?? "unknown")")
                    self.currentURLIndex += 1
                    
                    if self.currentURLIndex < self.urlVariants.count {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            self.tryCurrentVariant()
                        }
                    } else {
                        self.error = item?.error
                        self.isLoading = false
                    }
                    
                default:
                    break
                }
            }
            .store(in: &cancellables)
        
        // Buffer state observers
        item.publisher(for: \.isPlaybackLikelyToKeepUp)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isLikelyToKeepUp in
                if isLikelyToKeepUp && self?.isLoading == true {
                    self?.isLoading = false
                }
            }
            .store(in: &cancellables)
        
        item.publisher(for: \.isPlaybackBufferEmpty)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isEmpty in
                self?.isBuffering = isEmpty
            }
            .store(in: &cancellables)
        
        // Time observer
        let interval = CMTime(seconds: 0.5, preferredTimescale: 600)
        timeObserver = player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self = self else { return }
            self.currentTime = time.seconds
            
            if let duration = self.player?.currentItem?.duration.seconds, duration.isFinite {
                self.duration = duration
            }
            
            if self.isLoading && self.player?.timeControlStatus == .playing {
                self.isLoading = false
            }
        }
        
        // Access log for bitrate
        accessLogObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemNewAccessLogEntry,
            object: item,
            queue: .main
        ) { [weak self] notification in
            guard let item = notification.object as? AVPlayerItem,
                  let event = item.accessLog()?.events.last else { return }
            self?.currentBitrate = event.indicatedBitrate
        }
        
        // Failure observer
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemFailedToPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] notification in
            if let error = notification.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error {
                self?.error = error
            }
        }
    }
    
    private func cleanupObservers() {
        cancellables.removeAll()
        
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
            timeObserver = nil
        }
        
        if let observer = accessLogObserver {
            NotificationCenter.default.removeObserver(observer)
            accessLogObserver = nil
        }
        
        player?.pause()
        player = nil
    }
    
    func cleanup() {
        cleanupObservers()
    }
    
    func togglePlayPause() {
        if isPlaying {
            player?.pause()
        } else {
            player?.play()
        }
        isPlaying.toggle()
    }
    
    func seek(by seconds: Double) {
        guard let player = player else { return }
        let newTime = currentTime + seconds
        let clampedTime = max(0, min(newTime, duration))
        player.seek(to: CMTime(seconds: clampedTime, preferredTimescale: 600))
        currentTime = clampedTime
    }
    
    func seekTo(time: Double) {
        player?.seek(to: CMTime(seconds: time, preferredTimescale: 600))
    }
    
    func retry() {
        error = nil
        isLoading = true
        currentURLIndex = 0
        Task {
            await startProxyAndPlay()
        }
    }
}

// MARK: - Custom Progress Slider

struct ProgressSlider: View {
    @Binding var value: Double
    var range: ClosedRange<Double>
    @Binding var isSeeking: Bool
    var onEditingChanged: (Bool) -> Void
    
    init(value: Binding<Double>, in range: ClosedRange<Double>, isSeeking: Binding<Bool>, onEditingChanged: @escaping (Bool) -> Void) {
        self._value = value
        self.range = range
        self._isSeeking = isSeeking
        self.onEditingChanged = onEditingChanged
    }
    
    @State private var isDragging = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Track
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.white.opacity(0.3))
                    .frame(height: isDragging ? 8 : 4)
                
                // Progress
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.primaryAccent)
                    .frame(width: progressWidth(in: geometry.size.width), height: isDragging ? 8 : 4)
                
                // Thumb
                if isDragging {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 16, height: 16)
                        .shadow(color: .black.opacity(0.3), radius: 4)
                        .offset(x: thumbOffset(in: geometry.size.width))
                }
            }
            .frame(height: 16)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        if !isDragging {
                            isDragging = true
                            isSeeking = true
                            onEditingChanged(true)
                        }
                        
                        let newValue = calculateValue(from: gesture.location.x, in: geometry.size.width)
                        value = newValue
                    }
                    .onEnded { _ in
                        isDragging = false
                        isSeeking = false
                        onEditingChanged(false)
                    }
            )
            .animation(.spring(response: 0.2), value: isDragging)
        }
        .frame(height: 16)
    }
    
    private func progressWidth(in totalWidth: CGFloat) -> CGFloat {
        let percent = (value - range.lowerBound) / (range.upperBound - range.lowerBound)
        return CGFloat(percent) * totalWidth
    }
    
    private func thumbOffset(in totalWidth: CGFloat) -> CGFloat {
        progressWidth(in: totalWidth) - 8
    }
    
    private func calculateValue(from x: CGFloat, in totalWidth: CGFloat) -> Double {
        let percent = Double(max(0, min(x, totalWidth)) / totalWidth)
        return range.lowerBound + percent * (range.upperBound - range.lowerBound)
    }
}

#Preview {
    VideoPlayerView(
        title: "CNN International",
        streamURL: "http://example.com/stream.m3u8"
    )
}
