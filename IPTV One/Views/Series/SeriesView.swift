//
//  SeriesView.swift
//  IPTV One
//
//  Created by Robin Nap on 21/01/2026.
//

import SwiftUI
import SwiftData

struct SeriesView: View {
    @Bindable var playlistManager: PlaylistManager
    
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Series.name) private var allSeries: [Series]
    
    @State private var searchText = ""
    @State private var selectedCategory: String?
    @State private var selectedSeries: Series?
    
    private var series: [Series] {
        var filtered = allSeries
        
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
        Array(Set(allSeries.map { $0.categoryName })).sorted()
    }
    
    var body: some View {
        ZStack {
            Color.darkBackground.ignoresSafeArea()
            
            if playlistManager.isLoading {
                LoadingView(message: playlistManager.loadingMessage)
            } else if allSeries.isEmpty {
                emptyState
            } else {
                seriesGrid
            }
        }
        .navigationTitle("Series")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
        .navigationDestination(item: $selectedSeries) { series in
            SeriesDetailView(series: series)
        }
    }
    
    private var emptyState: some View {
        EmptyStateView(
            icon: "tv",
            title: "No Series",
            message: "Add a playlist in Settings to browse TV series.",
            actionTitle: nil,
            action: nil
        )
    }
    
    private var seriesGrid: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                // Search
                SearchBar(text: $searchText, placeholder: "Search series...")
                    .padding(.horizontal, 16)
                
                // Categories
                if !categories.isEmpty {
                    CategoryPicker(
                        categories: categories,
                        selectedCategory: $selectedCategory
                    )
                }
                
                // Results count
                Text("\(series.count) series")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)
                
                // Series grid
                LazyVGrid(
                    columns: gridColumns,
                    spacing: 20
                ) {
                    ForEach(series) { show in
                        SeriesCard(series: show) {
                            selectedSeries = show
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

#Preview {
    NavigationStack {
        SeriesView(playlistManager: PlaylistManager())
    }
    .modelContainer(for: [Playlist.self, Series.self], inMemory: true)
}
