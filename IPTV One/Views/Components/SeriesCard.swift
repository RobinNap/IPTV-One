//
//  SeriesCard.swift
//  IPTV One
//
//  Created by Robin Nap on 21/01/2026.
//

import SwiftUI

struct SeriesCard: View {
    let series: Series
    var onTap: () -> Void
    
    @State private var isHovered = false
    
    private var seasonCount: Int {
        series.seasons.count
    }
    
    private var episodeCount: Int {
        series.seasons.reduce(0) { $0 + $1.episodes.count }
    }
    
    var body: some View {
        Button(action: onTap) {
            GeometryReader { geometry in
                ZStack(alignment: .bottom) {
                    // Poster
                    if let posterURL = series.posterURL, let url = URL(string: posterURL) {
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
                        if series.isFavorite {
                            Image(systemName: "heart.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(.red)
                        }
                        
                        Spacer()
                        
                        Text(series.name)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                        
                        HStack(spacing: 8) {
                            if let year = series.year {
                                Text(year)
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                            }
                            
                            if seasonCount > 0 {
                                Text("\(seasonCount) Season\(seasonCount == 1 ? "" : "s")")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        
                        if let rating = series.rating, !rating.isEmpty {
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
                Image(systemName: "tv")
                    .font(.system(size: 32))
                    .foregroundStyle(.secondary)
                
                Text(series.name)
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
            SeriesCard(
                series: {
                    let s = Series(
                        name: "Breaking Bad",
                        year: "2008",
                        rating: "9.5",
                        isFavorite: true
                    )
                    s.seasons = [Season(seasonNumber: 1), Season(seasonNumber: 2)]
                    return s
                }()
            ) {}
            .frame(width: 150)
            
            SeriesCard(
                series: Series(
                    name: "Game of Thrones",
                    year: "2011",
                    rating: "9.2"
                )
            ) {}
            .frame(width: 150)
        }
        .padding()
    }
}
