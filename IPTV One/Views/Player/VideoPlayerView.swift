//
//  VideoPlayerView.swift
//  IPTV One
//
//  Created by Robin Nap on 21/01/2026.
//

import SwiftUI
import AVKit

struct VideoPlayerView: View {
    let title: String
    let streamURL: String
    var posterURL: String?
    
    @Environment(\.dismiss) private var dismiss
    @State private var player: AVPlayer?
    @State private var isPlaying = false
    @State private var showControls = true
    @State private var controlsTimer: Timer?
    @State private var isLoading = true
    @State private var error: Error?
    @State private var currentTime: Double = 0
    @State private var duration: Double = 0
    @State private var isSeeking = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.ignoresSafeArea()
                
                // Video Player
                if let player {
                    VideoPlayer(player: player)
                        .ignoresSafeArea()
                        .onTapGesture {
                            toggleControls()
                        }
                }
                
                // Loading indicator
                if isLoading && error == nil {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                        .scaleEffect(1.5)
                }
                
                // Error view
                if let error {
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
            setupPlayer()
        }
        .onDisappear {
            cleanupPlayer()
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
                    
                    Text(title)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    
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
                        seek(by: -10)
                    } label: {
                        Image(systemName: "gobackward.10")
                            .font(.system(size: 32))
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                    
                    // Play/Pause
                    Button {
                        togglePlayPause()
                    } label: {
                        Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(.white)
                            .frame(width: 72, height: 72)
                            .background(Circle().fill(Color.white.opacity(0.2)))
                    }
                    .buttonStyle(.plain)
                    
                    // Forward 10s
                    Button {
                        seek(by: 10)
                    } label: {
                        Image(systemName: "goforward.10")
                            .font(.system(size: 32))
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                }
                
                Spacer()
                
                // Bottom bar with progress
                VStack(spacing: 12) {
                    // Progress bar
                    ProgressSlider(
                        value: $currentTime,
                        in: 0...max(duration, 1),
                        isSeeking: $isSeeking
                    ) { editing in
                        if !editing {
                            player?.seek(to: CMTime(seconds: currentTime, preferredTimescale: 600))
                        }
                    }
                    
                    // Time labels
                    HStack {
                        Text(formatTime(currentTime))
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.8))
                        
                        Spacer()
                        
                        Text(formatTime(duration))
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.8))
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
                .foregroundStyle(.red)
            
            Text("Playback Error")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
            
            Text(error.localizedDescription)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            Button {
                self.error = nil
                setupPlayer()
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
    
    // MARK: - Player Management
    
    private func setupPlayer() {
        guard let url = URL(string: streamURL) else {
            error = NetworkError.invalidURL
            return
        }
        
        let playerItem = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: playerItem)
        player?.automaticallyWaitsToMinimizeStalling = true
        
        // Observe player status
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemFailedToPlayToEndTime,
            object: playerItem,
            queue: .main
        ) { notification in
            if let error = notification.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error {
                self.error = error
            }
        }
        
        // Time observer
        let interval = CMTime(seconds: 0.5, preferredTimescale: 600)
        player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { time in
            guard !isSeeking else { return }
            currentTime = time.seconds
            
            if let item = player?.currentItem {
                duration = item.duration.seconds.isFinite ? item.duration.seconds : 0
            }
            
            if isLoading && player?.timeControlStatus == .playing {
                isLoading = false
            }
        }
        
        // Start playing
        player?.play()
        isPlaying = true
        resetControlsTimer()
    }
    
    private func cleanupPlayer() {
        controlsTimer?.invalidate()
        player?.pause()
        player = nil
    }
    
    private func togglePlayPause() {
        if isPlaying {
            player?.pause()
        } else {
            player?.play()
        }
        isPlaying.toggle()
        resetControlsTimer()
    }
    
    private func seek(by seconds: Double) {
        guard let player else { return }
        let newTime = currentTime + seconds
        let clampedTime = max(0, min(newTime, duration))
        player.seek(to: CMTime(seconds: clampedTime, preferredTimescale: 600))
        currentTime = clampedTime
        resetControlsTimer()
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
            if isPlaying {
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
