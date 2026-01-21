//
//  ShimmerView.swift
//  IPTV One
//
//  Created by Robin Nap on 21/01/2026.
//

import SwiftUI

struct ShimmerView: View {
    @State private var phase: CGFloat = 0
    
    var body: some View {
        LinearGradient(
            gradient: Gradient(stops: [
                .init(color: Color.white.opacity(0), location: 0),
                .init(color: Color.white.opacity(0.1), location: 0.3),
                .init(color: Color.white.opacity(0.2), location: 0.5),
                .init(color: Color.white.opacity(0.1), location: 0.7),
                .init(color: Color.white.opacity(0), location: 1),
            ]),
            startPoint: UnitPoint(x: phase - 0.5, y: phase - 0.5),
            endPoint: UnitPoint(x: phase + 0.5, y: phase + 0.5)
        )
        .onAppear {
            withAnimation(
                .linear(duration: 1.5)
                .repeatForever(autoreverses: false)
            ) {
                phase = 1
            }
        }
    }
}

struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0
    
    func body(content: Content) -> some View {
        content
            .overlay {
                ShimmerView()
            }
            .mask(content)
    }
}

extension View {
    func shimmer() -> some View {
        modifier(ShimmerModifier())
    }
}

// MARK: - Skeleton Loading Views

struct ChannelCardSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Rectangle()
                .fill(Color.darkCardBackground)
                .frame(height: 100)
                .shimmer()
            
            VStack(alignment: .leading, spacing: 8) {
                Rectangle()
                    .fill(Color.white.opacity(0.1))
                    .frame(height: 14)
                    .frame(maxWidth: 120)
                
                Rectangle()
                    .fill(Color.white.opacity(0.05))
                    .frame(height: 10)
                    .frame(maxWidth: 80)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.darkCardBackground.opacity(0.8))
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shimmer()
    }
}

struct MovieCardSkeleton: View {
    var body: some View {
        Rectangle()
            .fill(Color.darkCardBackground)
            .aspectRatio(2/3, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .shimmer()
    }
}

struct LoadingGrid: View {
    var itemCount: Int = 12
    var isMovie: Bool = false
    
    private var columns: [GridItem] {
        #if os(macOS)
        if isMovie {
            return [GridItem(.adaptive(minimum: 150, maximum: 180), spacing: 20)]
        }
        return [GridItem(.adaptive(minimum: 200, maximum: 280), spacing: 16)]
        #else
        if isMovie {
            return [GridItem(.adaptive(minimum: 120, maximum: 160), spacing: 16)]
        }
        return [GridItem(.adaptive(minimum: 160, maximum: 200), spacing: 12)]
        #endif
    }
    
    var body: some View {
        LazyVGrid(columns: columns, spacing: isMovie ? 20 : 16) {
            ForEach(0..<itemCount, id: \.self) { _ in
                if isMovie {
                    MovieCardSkeleton()
                } else {
                    ChannelCardSkeleton()
                }
            }
        }
        .padding(.horizontal, 16)
    }
}

#Preview("Shimmer") {
    ZStack {
        Color.darkBackground.ignoresSafeArea()
        
        VStack(spacing: 20) {
            ChannelCardSkeleton()
                .frame(width: 200)
            
            MovieCardSkeleton()
                .frame(width: 150)
        }
        .padding()
    }
}

#Preview("Loading Grid") {
    ZStack {
        Color.darkBackground.ignoresSafeArea()
        
        ScrollView {
            LoadingGrid(itemCount: 8)
        }
    }
}
