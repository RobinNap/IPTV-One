//
//  HeroCard.swift
//  IPTV One
//
//  Created by Robin Nap on 21/01/2026.
//

import SwiftUI
import Combine

struct HeroCard: View {
    let title: String
    let subtitle: String?
    let imageURL: String?
    var gradient: [Color] = [.primaryAccent, .secondaryAccent]
    let onTap: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: onTap) {
            GeometryReader { geometry in
                ZStack(alignment: .bottomLeading) {
                    // Background
                    if let imageURL, let url = URL(string: imageURL) {
                        CachedAsyncImage(url: url) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: geometry.size.width, height: geometry.size.height)
                        } placeholder: {
                            gradientBackground
                        }
                    } else {
                        gradientBackground
                    }
                    
                    // Overlay gradient
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.8)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    
                    // Content
                    VStack(alignment: .leading, spacing: 8) {
                        Spacer()
                        
                        Text(title)
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(.white)
                            .lineLimit(2)
                        
                        if let subtitle {
                            Text(subtitle)
                                .font(.system(size: 15))
                                .foregroundStyle(.white.opacity(0.8))
                                .lineLimit(1)
                        }
                        
                        // Play button
                        HStack(spacing: 8) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 14))
                            Text("Watch Now")
                                .font(.system(size: 15, weight: .semibold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(LinearGradient.accentGradient)
                        .clipShape(Capsule())
                        .padding(.top, 8)
                    }
                    .padding(24)
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
            }
            .aspectRatio(16/9, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(
                        isHovered ? Color.primaryAccent : Color.white.opacity(0.1),
                        lineWidth: isHovered ? 2 : 1
                    )
            }
            .scaleEffect(isHovered ? 1.01 : 1.0)
            .shadow(
                color: isHovered ? Color.primaryAccent.opacity(0.3) : .clear,
                radius: 20
            )
            .animation(.smoothSpring, value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
    
    private var gradientBackground: some View {
        LinearGradient(
            colors: gradient,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - Featured Carousel

struct FeaturedCarousel<Item: Identifiable, Content: View>: View {
    let items: [Item]
    @ViewBuilder let content: (Item) -> Content
    
    @State private var currentIndex = 0
    private let timer = Timer.publish(every: 5, on: .main, in: .common).autoconnect()
    
    var body: some View {
        VStack(spacing: 16) {
            TabView(selection: $currentIndex) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    content(item)
                        .tag(index)
                        .padding(.horizontal, 16)
                }
            }
            #if os(iOS)
            .tabViewStyle(.page(indexDisplayMode: .never))
            #else
            .tabViewStyle(.automatic)
            #endif
            .frame(height: 220)
            
            // Page indicators
            if items.count > 1 {
                HStack(spacing: 8) {
                    ForEach(0..<items.count, id: \.self) { index in
                        Circle()
                            .fill(index == currentIndex ? Color.primaryAccent : Color.white.opacity(0.3))
                            .frame(width: 8, height: 8)
                            .scaleEffect(index == currentIndex ? 1.2 : 1.0)
                            .animation(.smoothSpring, value: currentIndex)
                    }
                }
            }
        }
        .onReceive(timer) { _ in
            withAnimation(.smoothSpring) {
                currentIndex = (currentIndex + 1) % max(items.count, 1)
            }
        }
    }
}

#Preview {
    ZStack {
        Color.darkBackground.ignoresSafeArea()
        
        ScrollView {
            VStack(spacing: 20) {
                HeroCard(
                    title: "CNN International",
                    subtitle: "Breaking News • Live Now",
                    imageURL: nil,
                    gradient: [Color(red: 0.8, green: 0.1, blue: 0.1), Color(red: 0.5, green: 0.0, blue: 0.0)]
                ) {}
                .padding(.horizontal, 16)
                
                HeroCard(
                    title: "The Matrix Resurrections",
                    subtitle: "2021 • Action, Sci-Fi",
                    imageURL: nil
                ) {}
                .padding(.horizontal, 16)
            }
        }
    }
}
