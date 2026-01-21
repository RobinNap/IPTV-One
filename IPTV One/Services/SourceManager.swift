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
    var loadingProgress: Double = 0
    var error: Error?
    var errorMessage: String?
    
    // Granular loading states for progressive/background loading
    var isLoadingChannels = false
    var isLoadingMovies = false
    var isLoadingSeries = false
    var channelsLoaded = false
    var moviesLoaded = false
    var seriesLoaded = false
    
    private var modelContext: ModelContext?
    
    // Batch size for inserts to prevent database lock contention
    // Larger batches = fewer saves = less "database busy" warnings
    private let batchSize = 500
    
    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
    }
    
    @MainActor
    func loadSource(_ source: Source) async {
        switch source.sourceType {
        case .m3u:
            await loadM3USource(source)
        case .xtream:
            await loadXtreamSource(source)
        }
    }
    
    // MARK: - M3U Loading
    
    @MainActor
    private func loadM3USource(_ source: Source) async {
        guard let modelContext else {
            errorMessage = "Internal error: Model context not set"
            return
        }
        
        isLoading = true
        isLoadingChannels = true
        isLoadingMovies = true
        isLoadingSeries = true
        channelsLoaded = false
        moviesLoaded = false
        seriesLoaded = false
        loadingMessage = "Connecting to server..."
        loadingProgress = 0
        error = nil
        errorMessage = nil
        
        do {
            guard let url = URL(string: source.url) else {
                throw NetworkError.invalidURL
            }
            
            print("[SourceManager] Loading M3U source: \(source.name) from \(source.url)")
            
            loadingMessage = "Downloading playlist..."
            loadingProgress = 0.1
            
            let sourceInfo = try await M3UParser.shared.parsePlaylist(from: url)
            
            if sourceInfo.items.isEmpty {
                throw M3UParserError.emptyPlaylist
            }
            
            loadingMessage = "Processing \(sourceInfo.items.count) items..."
            loadingProgress = 0.3
            
            print("[SourceManager] Found \(sourceInfo.items.count) items in playlist")
            
            // Clear existing content
            await clearSourceContent(source, modelContext: modelContext)
            
            loadingProgress = 0.4
            
            // Process items
            let result = await processM3UItems(sourceInfo.items, source: source, modelContext: modelContext)
            
            loadingProgress = 0.9
            
            // Update EPG URL if found
            if let epgURL = sourceInfo.epgURL {
                source.epgURL = epgURL
                print("[SourceManager] EPG URL set: \(epgURL)")
            }
            
            source.lastUpdated = Date()
            
            loadingMessage = "Saving..."
            try modelContext.save()
            
            print("[SourceManager] Save complete!")
            print("  - Total channels: \(result.channelCount)")
            print("  - Total movies: \(result.movieCount)")
            print("  - Total series: \(result.seriesCount)")
            
            await loadEPGIfAvailable(source)
            
            finishLoading()
            
        } catch {
            handleError(error)
        }
    }
    
    // MARK: - Xtream Codes Loading (Progressive/Background)
    
    @MainActor
    private func loadXtreamSource(_ source: Source) async {
        guard let modelContext else {
            errorMessage = "Internal error: Model context not set"
            return
        }
        
        guard let credentials = source.xtreamCredentials else {
            errorMessage = "Invalid Xtream credentials"
            return
        }
        
        // Reset all loading states
        isLoading = true
        isLoadingChannels = true
        isLoadingMovies = true
        isLoadingSeries = true
        channelsLoaded = false
        moviesLoaded = false
        seriesLoaded = false
        loadingMessage = "Authenticating..."
        loadingProgress = 0
        error = nil
        errorMessage = nil
        
        do {
            print("[SourceManager] Loading Xtream source: \(source.name)")
            
            // Authenticate
            let authResponse = try await XtreamService.shared.authenticate(credentials: credentials)
            print("[SourceManager] Authenticated as: \(authResponse.userInfo?.username ?? "unknown")")
            
            loadingProgress = 0.05
            
            // Clear existing content
            loadingMessage = "Clearing old content..."
            await clearSourceContent(source, modelContext: modelContext)
            
            loadingProgress = 0.1
            
            // Fetch all categories in parallel (they're small and fast)
            loadingMessage = "Fetching categories..."
            async let liveCategoriesTask = XtreamService.shared.getLiveCategories(credentials: credentials)
            async let vodCategoriesTask = XtreamService.shared.getVodCategories(credentials: credentials)
            async let seriesCategoriesTask = XtreamService.shared.getSeriesCategories(credentials: credentials)
            
            let (liveCategories, vodCategories, seriesCategories) = try await (liveCategoriesTask, vodCategoriesTask, seriesCategoriesTask)
            
            let liveCategoryMap = Dictionary(uniqueKeysWithValues: liveCategories.compactMap { cat -> (String, String)? in
                guard let id = cat.categoryId, let name = cat.categoryName else { return nil }
                return (id, name)
            })
            let vodCategoryMap = Dictionary(uniqueKeysWithValues: vodCategories.compactMap { cat -> (String, String)? in
                guard let id = cat.categoryId, let name = cat.categoryName else { return nil }
                return (id, name)
            })
            let seriesCategoryMap = Dictionary(uniqueKeysWithValues: seriesCategories.compactMap { cat -> (String, String)? in
                guard let id = cat.categoryId, let name = cat.categoryName else { return nil }
                return (id, name)
            })
            
            loadingProgress = 0.15
            
            // ======== PROGRESSIVE LOADING ========
            // Load channels first (usually what users want first), save immediately
            // Then load movies and series in background while user can browse channels
            
            // 1. CHANNELS - Load and save immediately so user can start browsing
            loadingMessage = "Loading live channels..."
            let liveStreams = try await XtreamService.shared.getLiveStreams(credentials: credentials)
            print("[SourceManager] Found \(liveStreams.count) live channels")
            
            loadingProgress = 0.3
            
            // Process channels in batches to prevent database lock contention
            var channelCount = 0
            var batch: [Channel] = []
            
            for stream in liveStreams {
                guard let streamId = stream.streamId?.value else { continue }
                
                let categoryName = stream.categoryId.flatMap { liveCategoryMap[$0] } ?? "Uncategorized"
                
                // Use .ts format which is more universally supported by IPTV providers
                let channel = Channel(
                    name: stream.name ?? "Unknown",
                    streamURL: credentials.liveStreamURL(streamId: streamId, format: "ts"),
                    logoURL: stream.streamIcon,
                    categoryName: categoryName,
                    epgID: stream.epgChannelId,
                    tvgName: stream.name
                )
                channel.source = source
                batch.append(channel)
                channelCount += 1
                
                // Batch insert to reduce database contention
                if batch.count >= batchSize {
                    for item in batch {
                        modelContext.insert(item)
                    }
                    batch.removeAll()
                    // Yield to prevent UI blocking
                    await Task.yield()
                }
            }
            
            // Insert remaining items
            for item in batch {
                modelContext.insert(item)
            }
            
            // Save channels immediately - user can now browse Live TV!
            try modelContext.save()
            isLoadingChannels = false
            channelsLoaded = true
            isLoading = false  // Stop blocking UI - channels are ready!
            print("[SourceManager] ✓ Channels loaded: \(channelCount) - User can now browse!")
            
            loadingProgress = 0.4
            
            // 2. MOVIES - Load in background while user might be browsing channels
            loadingMessage = "Loading movies..."
            let vodStreams = try await XtreamService.shared.getVodStreams(credentials: credentials)
            print("[SourceManager] Found \(vodStreams.count) movies")
            
            loadingProgress = 0.6
            
            // Process movies in batches
            var movieCount = 0
            var movieBatch: [Movie] = []
            
            for stream in vodStreams {
                guard let streamId = stream.streamId?.value else { continue }
                
                let categoryName = stream.categoryId.flatMap { vodCategoryMap[$0] } ?? "Uncategorized"
                let ext = stream.containerExtension ?? "mp4"
                
                let movie = Movie(
                    name: stream.name ?? "Unknown",
                    streamURL: credentials.vodStreamURL(streamId: streamId, extension: ext),
                    posterURL: stream.streamIcon,
                    categoryName: categoryName,
                    rating: stream.rating
                )
                movie.source = source
                movieBatch.append(movie)
                movieCount += 1
                
                if movieBatch.count >= batchSize {
                    for item in movieBatch {
                        modelContext.insert(item)
                    }
                    movieBatch.removeAll()
                    await Task.yield()
                }
            }
            
            for item in movieBatch {
                modelContext.insert(item)
            }
            
            // Save movies - user can now browse Movies!
            try modelContext.save()
            isLoadingMovies = false
            moviesLoaded = true
            print("[SourceManager] ✓ Movies loaded: \(movieCount)")
            
            loadingProgress = 0.8
            
            // 3. SERIES - Load in background (basic info only, episodes loaded lazily)
            loadingMessage = "Loading series..."
            let seriesList = try await XtreamService.shared.getSeries(credentials: credentials)
            print("[SourceManager] Found \(seriesList.count) series")
            
            loadingProgress = 0.9
            
            // Process series in batches
            var seriesCount = 0
            var seriesBatch: [Series] = []
            
            for seriesItem in seriesList {
                guard let seriesId = seriesItem.seriesId?.value else { continue }
                
                let categoryName = seriesItem.categoryId.flatMap { seriesCategoryMap[$0] } ?? "Uncategorized"
                
                // Only store basic series info - episodes will be loaded on-demand
                let series = Series(
                    name: seriesItem.name ?? "Unknown",
                    posterURL: seriesItem.cover,
                    categoryName: categoryName,
                    plot: seriesItem.plot,
                    rating: seriesItem.rating,
                    cast: seriesItem.cast,
                    director: seriesItem.director,
                    xtreamSeriesId: seriesId
                )
                series.source = source
                seriesBatch.append(series)
                seriesCount += 1
                
                if seriesBatch.count >= batchSize {
                    for item in seriesBatch {
                        modelContext.insert(item)
                    }
                    seriesBatch.removeAll()
                    await Task.yield()
                }
            }
            
            for item in seriesBatch {
                modelContext.insert(item)
            }
            
            // Save series
            try modelContext.save()
            isLoadingSeries = false
            seriesLoaded = true
            print("[SourceManager] ✓ Series loaded: \(seriesCount)")
            
            loadingProgress = 1.0
            source.lastUpdated = Date()
            try modelContext.save()
            
            print("[SourceManager] ✓ Xtream load complete!")
            print("  - Channels: \(channelCount)")
            print("  - Movies: \(movieCount)")
            print("  - Series: \(seriesCount)")
            
            loadingMessage = ""
            loadingProgress = 0
            
        } catch {
            handleError(error)
        }
    }
    
    // MARK: - Helper Methods
    
    @MainActor
    private func clearSourceContent(_ source: Source, modelContext: ModelContext) async {
        loadingMessage = "Clearing old content..."
        for channel in source.channelsList {
            modelContext.delete(channel)
        }
        for movie in source.moviesList {
            modelContext.delete(movie)
        }
        for series in source.seriesList {
            modelContext.delete(series)
        }
    }
    
    private struct ProcessResult {
        var channelCount: Int
        var movieCount: Int
        var seriesCount: Int
    }
    
    @MainActor
    private func processM3UItems(_ items: [M3UItem], source: Source, modelContext: ModelContext) async -> ProcessResult {
        var seriesMap: [String: [(M3UItem, Int, Int)]] = [:]
        var channelCount = 0
        var movieCount = 0
        var seriesItemCount = 0
        
        let totalItems = items.count
        var processedItems = 0
        
        for item in items {
            processedItems += 1
            
            if processedItems % 100 == 0 {
                let itemProgress = Double(processedItems) / Double(totalItems)
                loadingProgress = 0.4 + (itemProgress * 0.4)
                loadingMessage = "Processing items... (\(processedItems)/\(totalItems))"
            }
            
            switch item.contentType {
            case M3UContentType.live:
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
                channelCount += 1
                
            case M3UContentType.movie:
                let movie = Movie(
                    name: item.name,
                    streamURL: item.streamURL,
                    posterURL: item.logoURL,
                    categoryName: item.groupTitle
                )
                movie.source = source
                modelContext.insert(movie)
                movieCount += 1
                
            case M3UContentType.series:
                seriesItemCount += 1
                if let info = item.name.extractSeriesInfo() {
                    let key = "\(info.seriesName)|\(item.groupTitle)"
                    seriesMap[key, default: []].append((item, info.season ?? 1, info.episode ?? 1))
                } else {
                    let movie = Movie(
                        name: item.name,
                        streamURL: item.streamURL,
                        posterURL: item.logoURL,
                        categoryName: item.groupTitle
                    )
                    movie.source = source
                    modelContext.insert(movie)
                    movieCount += 1
                }
            }
        }
        
        loadingProgress = 0.8
        loadingMessage = "Creating series..."
        
        var seriesCount = 0
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
                    season.episodesList.append(episode)
                }
                
                series.seasonsList.append(season)
            }
            
            modelContext.insert(series)
            seriesCount += 1
        }
        
        return ProcessResult(channelCount: channelCount, movieCount: movieCount, seriesCount: seriesCount)
    }
    
    @MainActor
    private func loadEPGIfAvailable(_ source: Source) async {
        loadingProgress = 0.95
        loadingMessage = "Loading EPG data..."
        
        if let epgURL = source.epgURL {
            do {
                _ = try await EPGService.shared.fetchEPG(from: epgURL)
                print("[SourceManager] EPG loaded successfully")
            } catch {
                print("[SourceManager] Failed to load EPG (optional): \(error)")
            }
        }
    }
    
    @MainActor
    private func finishLoading() {
        loadingProgress = 1.0
        loadingMessage = "Done!"
        
        Task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            isLoading = false
            isLoadingChannels = false
            isLoadingMovies = false
            isLoadingSeries = false
            channelsLoaded = true
            moviesLoaded = true
            seriesLoaded = true
            loadingMessage = ""
            loadingProgress = 0
        }
    }
    
    @MainActor
    private func handleError(_ error: Error) {
        print("[SourceManager] Error loading source: \(error)")
        self.error = error
        self.errorMessage = error.localizedDescription
        isLoading = false
        isLoadingChannels = false
        isLoadingMovies = false
        isLoadingSeries = false
        loadingMessage = ""
        loadingProgress = 0
    }
    
    func clearError() {
        error = nil
        errorMessage = nil
    }
    
    // MARK: - Lazy Loading for Series Episodes
    
    /// Loads episodes for a series on-demand (lazy loading)
    /// This is called when the user opens a series detail view
    @MainActor
    func loadSeriesEpisodes(_ series: Series) async -> Bool {
        guard let modelContext else {
            print("[SourceManager] Model context not set for lazy loading")
            return false
        }
        
        // Already loaded or no Xtream ID
        guard !series.episodesLoaded else {
            print("[SourceManager] Episodes already loaded for: \(series.name)")
            return true
        }
        
        guard let seriesId = series.xtreamSeriesId,
              let source = series.source,
              let credentials = source.xtreamCredentials else {
            // Not an Xtream series or missing credentials - mark as loaded to avoid retrying
            series.episodesLoaded = true
            return true
        }
        
        print("[SourceManager] Lazy loading episodes for: \(series.name) (ID: \(seriesId))")
        
        do {
            let seriesInfo = try await XtreamService.shared.getSeriesInfo(credentials: credentials, seriesId: seriesId)
            
            // Clear any existing seasons (shouldn't be any, but just in case)
            for season in series.seasonsList {
                modelContext.delete(season)
            }
            series.seasons = []
            
            if let episodes = seriesInfo.episodes {
                // Group episodes by season
                for (seasonNum, seasonEpisodes) in episodes.sorted(by: { Int($0.key) ?? 0 < Int($1.key) ?? 0 }) {
                    let season = Season(seasonNumber: Int(seasonNum) ?? 1)
                    season.series = series
                    
                    for ep in seasonEpisodes.sorted(by: { ($0.episodeNum?.value ?? 0) < ($1.episodeNum?.value ?? 0) }) {
                        guard let epId = ep.id, let epIdInt = Int(epId) else { continue }
                        
                        let epNum = ep.episodeNum?.value ?? 1
                        let ext = ep.containerExtension ?? "mp4"
                        let episode = Episode(
                            episodeNumber: epNum,
                            name: ep.title ?? "Episode \(epNum)",
                            streamURL: credentials.seriesStreamURL(streamId: epIdInt, extension: ext),
                            plot: ep.info?.plot,
                            duration: ep.info?.duration,
                            stillURL: ep.info?.movieImage
                        )
                        episode.season = season
                        season.episodesList.append(episode)
                    }
                    
                    series.seasonsList.append(season)
                }
            }
            
            // Update additional info from detailed response
            if let info = seriesInfo.info {
                if let plot = info.plot, series.plot == nil {
                    series.plot = plot
                }
                if let rating = info.rating, series.rating == nil {
                    series.rating = rating
                }
            }
            
            series.episodesLoaded = true
            try modelContext.save()
            
            print("[SourceManager] Loaded \(series.seasonsList.count) seasons with episodes for: \(series.name)")
            return true
            
        } catch {
            print("[SourceManager] Failed to lazy load episodes for \(series.name): \(error)")
            // Don't mark as loaded so it can be retried
            return false
        }
    }
}
