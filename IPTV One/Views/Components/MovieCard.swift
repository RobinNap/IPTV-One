//
//  MovieCard.swift
//  IPTV One
//
//  Created by Robin Nap on 21/01/2026.
//

import SwiftUI

struct MovieCard: View {
    let movie: Movie
    var onTap: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: onTap) {
            GeometryReader { geometry in
                ZStack(alignment: .bottom) {
                    // Poster
                    if let posterURL = movie.posterURL, let url = URL(string: posterURL) {
                        CachedAsyncImage(url: url) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: geometry.size.width, height: geometry.size.height)
                        } placeholder: {
                            posterPlaceholder
                        }
                    } else {
                        posterPlaceholder
                    }
                    
                    // Gradient overlay
                    LinearGradient.cardOverlay
                    
                    // Info
                    VStack(alignment: .leading, spacing: 4) {
                        if movie.isFavorite {
                            Image(systemName: "heart.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(.red)
                        }
                        
                        Spacer()
                        
                        Text(movie.name)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                        
                        HStack(spacing: 6) {
                            if let year = movie.year {
                                Text(year)
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                            }
                            
                            if let rating = movie.rating, !rating.isEmpty {
                                HStack(spacing: 2) {
                                    Image(systemName: "star.fill")
                                        .font(.system(size: 9))
                                        .foregroundStyle(.yellow)
                                    Text(rating)
                                        .font(.system(size: 11))
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        
                        // Watch progress
                        if movie.watchProgress > 0 {
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(Color.white.opacity(0.3))
                                    
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(Color.primaryAccent)
                                        .frame(width: geo.size.width * movie.watchProgress)
                                }
                            }
                            .frame(height: 3)
                        }
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
            }
            .aspectRatio(2/3, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(
                        isHovered ? Color.primaryAccent : Color.white.opacity(0.08),
                        lineWidth: isHovered ? 2 : 1
                    )
            }
            .scaleEffect(isHovered ? 1.03 : 1.0)
            .shadow(color: isHovered ? Color.primaryAccent.opacity(0.4) : .clear, radius: 16)
            .animation(.smoothSpring, value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
    
    private var posterPlaceholder: some View {
        ZStack {
            Color.darkCardBackground
            
            VStack(spacing: 8) {
                Image(systemName: "film")
                    .font(.system(size: 32))
                    .foregroundStyle(.secondary)
                
                Text(movie.name)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .padding(.horizontal, 8)
            }
        }
    }
}

#Preview {
    ZStack {
        Color.darkBackground.ignoresSafeArea()
        
        HStack(spacing: 16) {
            MovieCard(
                movie: Movie(
                    name: "The Matrix Resurrections",
                    streamURL: "http://example.com",
                    posterURL: nil,
                    year: "2021",
                    rating: "7.5",
                    isFavorite: true,
                    watchProgress: 0.3
                )
            ) {}
            .frame(width: 150)
            
            MovieCard(
                movie: Movie(
                    name: "Inception",
                    streamURL: "http://example.com",
                    year: "2010",
                    rating: "8.8"
                )
            ) {}
            .frame(width: 150)
        }
        .padding()
    }
}
