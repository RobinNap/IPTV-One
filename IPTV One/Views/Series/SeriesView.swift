//
//  SeriesView.swift
//  IPTV One
//
//  Created by Robin Nap on 21/01/2026.
//

import SwiftUI
import SwiftData

struct SeriesView: View {
    @Bindable var sourceManager: SourceManager
    
    @Environment(\.modelContext) private var modelContext
    @Query private var sources: [Source]
    @Query(sort: \Series.name) private var allSeries: [Series]
    
    @State private var searchText = ""
    @State private var selectedCategory: String?
    @State private var selectedSeries: Series?
    
    /// Check if there's at least one configured source
    private var hasActiveSource: Bool {
        sources.contains { $0.isActive }
    }
    
    private var series: [Series] {
        guard hasActiveSource else { return [] }
        
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
        guard hasActiveSource else { return [] }
        return Array(Set(allSeries.map { $0.categoryName })).sorted()
    }
    
    var body: some View {
        ZStack {
            Color.darkBackground.ignoresSafeArea()
            
            // No source configured
            if sources.isEmpty {
                noSourceState
            }
            // Show loading screen while loading series
            else if sourceManager.isLoadingSeries && series.isEmpty {
                LoadingView(message: sourceManager.loadingMessage, progress: sourceManager.loadingProgress)
            }
            // Source exists but no series
            else if series.isEmpty {
                emptyState
            }
            // Show series
            else {
                seriesGrid
            }
        }
        .navigationTitle("Series")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
        .navigationDestination(item: $selectedSeries) { series in
            SeriesDetailView(series: series, sourceManager: sourceManager)
        }
    }
    
    private var noSourceState: some View {
        EmptyStateView(
            icon: "plus.circle",
            title: "No Source Configured",
            message: "Add an IPTV source in Settings to browse TV series.",
            actionTitle: nil,
            action: nil
        )
    }
    
    private var emptyState: some View {
        EmptyStateView(
            icon: "tv",
            title: "No Series",
            message: "Your source doesn't have any TV series, or they're still loading.",
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
        SeriesView(sourceManager: SourceManager())
    }
    .modelContainer(for: [Source.self, Series.self], inMemory: true)
}
