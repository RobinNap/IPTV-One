//
//  SourceManager.swift
//  IPTV One
//
//  Created by Robin Nap on 21/01/2026.
//

import Foundation
import SwiftData
import SwiftUI

@Observable
class SourceManager {
    var isLoading = false
    var loadingMessage = ""
    var error: Error?
    
    private var modelContext: ModelContext?
    
    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
    }
    
    @MainActor
    func loadSource(_ source: Source) async {
        guard let modelContext else { return }
        
        isLoading = true
        loadingMessage = "Fetching source..."
        error = nil
        
        do {
            guard let url = URL(string: source.url) else {
                throw NetworkError.invalidURL
            }
            
            let sourceInfo = try await M3UParser.shared.parsePlaylist(from: url)
            
            loadingMessage = "Processing channels..."
            
            // Clear existing content
            for channel in source.channels {
                modelContext.delete(channel)
            }
            for movie in source.movies {
                modelContext.delete(movie)
            }
            for series in source.series {
                modelContext.delete(series)
            }
            
            // Group series episodes
            var seriesMap: [String: [(M3UItem, Int, Int)]] = [:]
            
            for item in sourceInfo.items {
                switch item.contentType {
                case .live:
                    let channel = Channel(
                        name: item.name,
                        streamURL: item.streamURL,
                        logoURL: item.logoURL,
                        categoryName: item.groupTitle,
                        epgID: item.tvgID,
                        tvgName: item.tvgName
                    )
                    channel.source = source
                    modelContext.insert(channel)
                    
                case .movie:
                    let movie = Movie(
                        name: item.name,
                        streamURL: item.streamURL,
                        posterURL: item.logoURL,
                        categoryName: item.groupTitle
                    )
                    movie.source = source
                    modelContext.insert(movie)
                    
                case .series:
                    // Try to extract series info
                    if let info = item.name.extractSeriesInfo() {
                        let key = "\(info.seriesName)|\(item.groupTitle)"
                        seriesMap[key, default: []].append((item, info.season ?? 1, info.episode ?? 1))
                    } else {
                        // Treat as movie if we can't parse series info
                        let movie = Movie(
                            name: item.name,
                            streamURL: item.streamURL,
                            posterURL: item.logoURL,
                            categoryName: item.groupTitle
                        )
                        movie.source = source
                        modelContext.insert(movie)
                    }
                }
            }
            
            // Create series from grouped episodes
            loadingMessage = "Processing series..."
            
            for (key, episodes) in seriesMap {
                let components = key.split(separator: "|")
                let seriesName = String(components.first ?? "Unknown")
                let categoryName = components.count > 1 ? String(components[1]) : "Series"
                
                let series = Series(
                    name: seriesName,
                    posterURL: episodes.first?.0.logoURL,
                    categoryName: categoryName
                )
                series.source = source
                
                // Group by season
                let seasonGroups = Dictionary(grouping: episodes) { $0.1 }
                
                for (seasonNum, seasonEpisodes) in seasonGroups.sorted(by: { $0.key < $1.key }) {
                    let season = Season(seasonNumber: seasonNum)
                    season.series = series
                    
                    for (item, _, episodeNum) in seasonEpisodes.sorted(by: { $0.2 < $1.2 }) {
                        let episode = Episode(
                            episodeNumber: episodeNum,
                            name: item.name,
                            streamURL: item.streamURL,
                            stillURL: item.logoURL
                        )
                        episode.season = season
                        season.episodes.append(episode)
                    }
                    
                    series.seasons.append(season)
                }
                
                modelContext.insert(series)
            }
            
            // Update EPG URL if found
            if let epgURL = sourceInfo.epgURL {
                source.epgURL = epgURL
            }
            
            source.lastUpdated = Date()
            
            try modelContext.save()
            
            loadingMessage = "Loading EPG data..."
            
            // Load EPG if available
            if let epgURL = source.epgURL {
                do {
                    _ = try await EPGService.shared.fetchEPG(from: epgURL)
                } catch {
                    // EPG is optional, don't fail the whole load
                    print("Failed to load EPG: \(error)")
                }
            }
            
            isLoading = false
            loadingMessage = ""
            
        } catch {
            self.error = error
            isLoading = false
            loadingMessage = ""
        }
    }
}
