//
//  CachedAsyncImage.swift
//  IPTV One
//
//  Created by Robin Nap on 21/01/2026.
//

import SwiftUI

struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    let url: URL?
    @ViewBuilder let content: (Image) -> Content
    @ViewBuilder let placeholder: () -> Placeholder
    
    @State private var image: Image?
    @State private var isLoading = false
    
    var body: some View {
        Group {
            if let image {
                content(image)
            } else {
                placeholder()
                    .task(id: url) {
                        await loadImage()
                    }
            }
        }
    }
    
    private func loadImage() async {
        guard let url, !isLoading else { return }
        
        isLoading = true
        defer { isLoading = false }
        
        // Use getOrLoad which deduplicates concurrent requests for the same URL
        let loadedImage = await ImageCache.shared.getOrLoad(for: url) {
            do {
                // Use verbose: false to reduce console noise for image fetches
                let data = try await NetworkService.shared.fetchData(from: url, verbose: false)
                
                #if os(macOS)
                if let nsImage = NSImage(data: data) {
                    return Image(nsImage: nsImage)
                }
                #else
                if let uiImage = UIImage(data: data) {
                    return Image(uiImage: uiImage)
                }
                #endif
            } catch {
                // Silently fail - placeholder will show
            }
            return nil
        }
        
        if let loadedImage {
            await MainActor.run {
                withAnimation(.easeIn(duration: 0.2)) {
                    self.image = loadedImage
                }
            }
        }
    }
}

// In-memory image cache with request deduplication
actor ImageCache {
    static let shared = ImageCache()
    
    private var cache: [URL: Image] = [:]
    private var inFlightRequests: [URL: Task<Image?, Never>] = [:]
    private let maxSize = 200
    
    private init() {}
    
    func get(for url: URL) -> Image? {
        return cache[url]
    }
    
    func set(_ image: Image, for url: URL) {
        // Simple LRU-ish eviction
        if cache.count >= maxSize {
            cache.removeValue(forKey: cache.keys.first!)
        }
        cache[url] = image
    }
    
    /// Get or start loading an image, deduplicating concurrent requests
    func getOrLoad(for url: URL, loader: @escaping () async -> Image?) async -> Image? {
        // Check cache first
        if let cached = cache[url] {
            return cached
        }
        
        // Check if there's already a request in flight for this URL
        if let existingTask = inFlightRequests[url] {
            // Wait for the existing request instead of starting a new one
            return await existingTask.value
        }
        
        // Start a new request and track it
        let task = Task<Image?, Never> {
            let image = await loader()
            if let image = image {
                await self.setAndCleanup(image, for: url)
            } else {
                await self.cleanupInFlight(for: url)
            }
            return image
        }
        
        inFlightRequests[url] = task
        return await task.value
    }
    
    private func setAndCleanup(_ image: Image, for url: URL) {
        set(image, for: url)
        inFlightRequests.removeValue(forKey: url)
    }
    
    private func cleanupInFlight(for url: URL) {
        inFlightRequests.removeValue(forKey: url)
    }
    
    func clear() {
        cache.removeAll()
        inFlightRequests.removeAll()
    }
}

// Convenience initializer
extension CachedAsyncImage where Placeholder == Color {
    init(url: URL?, @ViewBuilder content: @escaping (Image) -> Content) {
        self.url = url
        self.content = content
        self.placeholder = { Color.darkCardBackground }
    }
}

#Preview {
    CachedAsyncImage(url: URL(string: "https://example.com/image.jpg")) { image in
        image
            .resizable()
            .aspectRatio(contentMode: .fill)
    } placeholder: {
        Color.gray
    }
    .frame(width: 200, height: 200)
    .clipShape(RoundedRectangle(cornerRadius: 12))
}
