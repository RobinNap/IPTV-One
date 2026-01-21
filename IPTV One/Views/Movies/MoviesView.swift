//
//  MoviesView.swift
//  IPTV One
//
//  Created by Robin Nap on 21/01/2026.
//

import SwiftUI
import SwiftData

struct MoviesView: View {
    @Bindable var sourceManager: SourceManager
    
    @Environment(\.modelContext) private var modelContext
    @Query private var sources: [Source]
    @Query(sort: \Movie.name) private var allMovies: [Movie]
    
    @State private var searchText = ""
    @State private var selectedCategory: String?
    @State private var selectedMovie: Movie?
    @State private var movieToPlay: Movie?
    @State private var pendingPlayMovie: Movie?
    
    /// Check if there's at least one configured source
    private var hasActiveSource: Bool {
        sources.contains { $0.isActive }
    }
    
    private var movies: [Movie] {
        guard hasActiveSource else { return [] }
        
        var filtered = allMovies
        
        if !searchText.isEmpty {
            filtered = filtered.filter {
                $0.name.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        if let category = selectedCategory {
            filtered = filtered.filter { $0.categoryName == category }
        }
        
        return filtered
    }
    
    private var categories: [String] {
        guard hasActiveSource else { return [] }
        return Array(Set(allMovies.map { $0.categoryName })).sorted()
    }
    
    private var continueWatching: [Movie] {
        guard hasActiveSource else { return [] }
        return allMovies.filter { $0.watchProgress > 0 && $0.watchProgress < 0.95 }
            .sorted { ($0.lastWatched ?? .distantPast) > ($1.lastWatched ?? .distantPast) }
    }
    
    var body: some View {
        ZStack {
            Color.darkBackground.ignoresSafeArea()
            
            // No source configured
            if sources.isEmpty {
                noSourceState
            }
            // Show loading screen while loading movies
            else if sourceManager.isLoadingMovies && movies.isEmpty {
                LoadingView(message: sourceManager.loadingMessage, progress: sourceManager.loadingProgress)
            }
            // Source exists but no movies
            else if movies.isEmpty {
                emptyState
            }
            // Show movies
            else {
                movieGrid
            }
        }
        .navigationTitle("Movies")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
        .sheet(item: $selectedMovie, onDismiss: {
            // After sheet dismisses, show player if we have a movie queued
            if let movie = pendingPlayMovie {
                pendingPlayMovie = nil
                // Small delay to allow sheet dismissal animation to complete
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    movieToPlay = movie
                }
            }
        }) { movie in
            MovieDetailView(movie: movie) {
                // Queue movie to play and dismiss the sheet
                pendingPlayMovie = movie
                selectedMovie = nil  // This dismisses the sheet
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .fullScreenCover(item: $movieToPlay) { movie in
            VideoPlayerView(
                title: movie.name,
                streamURL: movie.streamURL,
                posterURL: movie.posterURL,
                isLiveStream: false
            )
        }
    }
    
    private var noSourceState: some View {
        EmptyStateView(
            icon: "plus.circle",
            title: "No Source Configured",
            message: "Add an IPTV source in Settings to browse movies.",
            actionTitle: nil,
            action: nil
        )
    }
    
    private var emptyState: some View {
        EmptyStateView(
            icon: "film",
            title: "No Movies",
            message: "Your source doesn't have any movies, or they're still loading.",
            actionTitle: nil,
            action: nil
        )
    }
    
    private var movieGrid: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                // Background loading indicator
                if sourceManager.isLoadingSeries {
                    BackgroundLoadingBanner(message: sourceManager.loadingMessage)
                }
                
                // Search
                SearchBar(text: $searchText, placeholder: "Search movies...")
                    .padding(.horizontal, 16)
                
                // Continue Watching
                if !continueWatching.isEmpty && searchText.isEmpty && selectedCategory == nil {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Continue Watching")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(continueWatching.prefix(10)) { movie in
                                    MovieCard(movie: movie) {
                                        selectedMovie = movie
                                    }
                                    .frame(width: 140)
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                    }
                }
                
                // Categories
                if !categories.isEmpty {
                    CategoryPicker(
                        categories: categories,
                        selectedCategory: $selectedCategory
                    )
                }
                
                // Results count
                Text("\(movies.count) movie\(movies.count == 1 ? "" : "s")")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)
                
                // Movie grid
                LazyVGrid(
                    columns: gridColumns,
                    spacing: 20
                ) {
                    ForEach(movies) { movie in
                        MovieCard(movie: movie) {
                            selectedMovie = movie
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 32)
            }
            .padding(.top, 8)
        }
    }
    
    private var gridColumns: [GridItem] {
        #if os(macOS)
        [GridItem(.adaptive(minimum: 150, maximum: 180), spacing: 20)]
        #else
        [GridItem(.adaptive(minimum: 120, maximum: 160), spacing: 16)]
        #endif
    }
}

// MARK: - Movie Detail View

struct MovieDetailView: View {
    let movie: Movie
    let onPlay: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header with poster
                HStack(alignment: .top, spacing: 16) {
                    // Poster
                    if let posterURL = movie.posterURL, let url = URL(string: posterURL) {
                        CachedAsyncImage(url: url) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Color.darkCardBackground
                        }
                        .frame(width: 120, height: 180)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text(movie.name)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(.white)
                        
                        HStack(spacing: 12) {
                            if let year = movie.year {
                                Text(year)
                                    .foregroundStyle(.secondary)
                            }
                            
                            if let rating = movie.rating, !rating.isEmpty {
                                HStack(spacing: 4) {
                                    Image(systemName: "star.fill")
                                        .foregroundStyle(.yellow)
                                    Text(rating)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            
                            if let duration = movie.duration {
                                Text(duration)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .font(.system(size: 14))
                        
                        Text(movie.categoryName)
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.darkCardBackground)
                            .clipShape(Capsule())
                        
                        Spacer()
                        
                        // Play button
                        Button(action: onPlay) {
                            HStack {
                                Image(systemName: "play.fill")
                                Text(movie.watchProgress > 0 ? "Continue" : "Play")
                            }
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(LinearGradient.accentGradient)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                
                // Plot
                if let plot = movie.plot, !plot.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Plot")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                        
                        Text(plot)
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                            .lineSpacing(4)
                    }
                    .padding(.horizontal, 20)
                }
                
                // Cast & Crew
                if let cast = movie.cast, !cast.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Cast")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                        
                        Text(cast)
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 20)
                }
                
                if let director = movie.director, !director.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Director")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                        
                        Text(director)
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 20)
                }
            }
            .padding(.bottom, 32)
        }
        .background(Color.darkBackground)
    }
}

#Preview {
    NavigationStack {
        MoviesView(sourceManager: SourceManager())
    }
    .modelContainer(for: [Source.self, Movie.self], inMemory: true)
}
