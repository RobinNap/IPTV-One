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
        
        // Check memory cache first
        if let cached = ImageCache.shared.get(for: url) {
            self.image = cached
            return
        }
        
        do {
            let data = try await NetworkService.shared.fetchData(from: url)
            
            #if os(macOS)
            if let nsImage = NSImage(data: data) {
                let loadedImage = Image(nsImage: nsImage)
                ImageCache.shared.set(loadedImage, for: url)
                await MainActor.run {
                    withAnimation(.easeIn(duration: 0.2)) {
                        self.image = loadedImage
                    }
                }
            }
            #else
            if let uiImage = UIImage(data: data) {
                let loadedImage = Image(uiImage: uiImage)
                ImageCache.shared.set(loadedImage, for: url)
                await MainActor.run {
                    withAnimation(.easeIn(duration: 0.2)) {
                        self.image = loadedImage
                    }
                }
            }
            #endif
        } catch {
            // Silently fail - placeholder will show
        }
    }
}

// Simple in-memory image cache
class ImageCache {
    static let shared = ImageCache()
    
    private var cache: [URL: Image] = [:]
    private let lock = NSLock()
    private let maxSize = 100
    
    private init() {}
    
    func get(for url: URL) -> Image? {
        lock.lock()
        defer { lock.unlock() }
        return cache[url]
    }
    
    func set(_ image: Image, for url: URL) {
        lock.lock()
        defer { lock.unlock() }
        
        // Simple LRU-ish eviction
        if cache.count >= maxSize {
            cache.removeValue(forKey: cache.keys.first!)
        }
        cache[url] = image
    }
    
    func clear() {
        lock.lock()
        defer { lock.unlock() }
        cache.removeAll()
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
