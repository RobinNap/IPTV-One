//
//  SeriesDetailView.swift
//  IPTV One
//
//  Created by Robin Nap on 21/01/2026.
//

import SwiftUI
import SwiftData

struct SeriesDetailView: View {
    let series: Series
    
    @State private var selectedSeason: Season?
    @State private var selectedEpisode: Episode?
    @State private var showingPlayer = false
    
    private var sortedSeasons: [Season] {
        series.seasons.sorted { $0.seasonNumber < $1.seasonNumber }
    }
    
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {
                // Header
                headerView
                
                // Season picker
                if !sortedSeasons.isEmpty {
                    seasonPicker
                }
                
                // Episodes
                if let season = selectedSeason {
                    episodeList(for: season)
                }
            }
            .padding(.bottom, 32)
        }
        .background(Color.darkBackground)
        .navigationTitle(series.name)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .onAppear {
            if selectedSeason == nil {
                selectedSeason = sortedSeasons.first
            }
        }
        .fullScreenCover(isPresented: $showingPlayer) {
            if let episode = selectedEpisode {
                VideoPlayerView(
                    title: episode.name,
                    streamURL: episode.streamURL,
                    posterURL: episode.stillURL ?? series.posterURL
                )
            }
        }
    }
    
    private var headerView: some View {
        HStack(alignment: .top, spacing: 16) {
            // Poster
            if let posterURL = series.posterURL, let url = URL(string: posterURL) {
                CachedAsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Color.darkCardBackground
                }
                .frame(width: 140, height: 210)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            } else {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.darkCardBackground)
                    .frame(width: 140, height: 210)
                    .overlay {
                        Image(systemName: "tv")
                            .font(.system(size: 40))
                            .foregroundStyle(.secondary)
                    }
            }
            
            VStack(alignment: .leading, spacing: 10) {
                Text(series.name)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.white)
                
                HStack(spacing: 12) {
                    if let year = series.year {
                        Text(year)
                            .foregroundStyle(.secondary)
                    }
                    
                    if let rating = series.rating, !rating.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "star.fill")
                                .foregroundStyle(.yellow)
                            Text(rating)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .font(.system(size: 14))
                
                // Season/Episode count
                HStack(spacing: 8) {
                    Text("\(sortedSeasons.count) Season\(sortedSeasons.count == 1 ? "" : "s")")
                    Text("•")
                    Text("\(totalEpisodes) Episode\(totalEpisodes == 1 ? "" : "s")")
                }
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                
                Text(series.categoryName)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.darkCardBackground)
                    .clipShape(Capsule())
                
                Spacer()
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
    }
    
    private var totalEpisodes: Int {
        sortedSeasons.reduce(0) { $0 + $1.episodes.count }
    }
    
    private var seasonPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(sortedSeasons) { season in
                    Button {
                        withAnimation(.smoothSpring) {
                            selectedSeason = season
                        }
                    } label: {
                        Text(season.name ?? "Season \(season.seasonNumber)")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(selectedSeason?.id == season.id ? .white : .secondary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background {
                                if selectedSeason?.id == season.id {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.primaryAccent)
                                } else {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.darkCardBackground)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
        }
    }
    
    private func episodeList(for season: Season) -> some View {
        let sortedEpisodes = season.episodes.sorted { $0.episodeNumber < $1.episodeNumber }
        
        return VStack(alignment: .leading, spacing: 12) {
            Text("Episodes")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
            
            ForEach(sortedEpisodes) { episode in
                EpisodeRow(episode: episode, seriesPosterURL: series.posterURL) {
                    selectedEpisode = episode
                    showingPlayer = true
                }
            }
        }
    }
}

struct EpisodeRow: View {
    let episode: Episode
    var seriesPosterURL: String?
    let onTap: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Thumbnail
                ZStack {
                    if let stillURL = episode.stillURL ?? seriesPosterURL,
                       let url = URL(string: stillURL) {
                        CachedAsyncImage(url: url) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Color.darkCardBackground
                        }
                    } else {
                        Color.darkCardBackground
                    }
                    
                    // Play overlay
                    Circle()
                        .fill(Color.black.opacity(0.5))
                        .frame(width: 36, height: 36)
                        .overlay {
                            Image(systemName: "play.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(.white)
                        }
                    
                    // Progress
                    if episode.watchProgress > 0 {
                        VStack {
                            Spacer()
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Rectangle()
                                        .fill(Color.white.opacity(0.3))
                                    Rectangle()
                                        .fill(Color.primaryAccent)
                                        .frame(width: geo.size.width * episode.watchProgress)
                                }
                            }
                            .frame(height: 3)
                        }
                    }
                }
                .frame(width: 140, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                
                // Info
                VStack(alignment: .leading, spacing: 4) {
                    Text("Episode \(episode.episodeNumber)")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    
                    Text(episode.name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                    
                    if let duration = episode.duration {
                        Text(duration)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    
                    if let plot = episode.plot {
                        Text(plot)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }
            .padding(12)
            .background {
                RoundedRectangle(cornerRadius: 10)
                    .fill(isHovered ? Color.darkCardBackground : Color.clear)
            }
            .animation(.quickSpring, value: isHovered)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 8)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

#Preview {
    NavigationStack {
        SeriesDetailView(series: {
            let s = Series(name: "Breaking Bad", year: "2008", rating: "9.5")
            let season1 = Season(seasonNumber: 1)
            season1.episodes = [
                Episode(episodeNumber: 1, name: "Pilot", streamURL: "http://example.com"),
                Episode(episodeNumber: 2, name: "Cat's in the Bag...", streamURL: "http://example.com"),
                Episode(episodeNumber: 3, name: "...And the Bag's in the River", streamURL: "http://example.com")
            ]
            let season2 = Season(seasonNumber: 2)
            s.seasons = [season1, season2]
            return s
        }())
    }
    .modelContainer(for: [Series.self], inMemory: true)
}
