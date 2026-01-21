//
//  LiveTVView.swift
//  IPTV One
//
//  Created by Robin Nap on 21/01/2026.
//

import SwiftUI
import SwiftData

struct LiveTVView: View {
    @Bindable var sourceManager: SourceManager
    
    @Environment(\.modelContext) private var modelContext
    @Query private var sources: [Source]
    @Query(sort: \Channel.name) private var allChannels: [Channel]
    
    @State private var searchText = ""
    @State private var selectedCategory: String?
    @State private var selectedChannel: Channel?
    @State private var epgData: [String: [EPGProgramData]] = [:]
    
    /// Check if there's at least one configured source
    private var hasActiveSource: Bool {
        sources.contains { $0.isActive }
    }
    
    /// Only return channels if there's an active source
    private var channels: [Channel] {
        // No channels without an active source
        guard hasActiveSource else { return [] }
        
        var filtered = allChannels
        
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
        return Array(Set(allChannels.map { $0.categoryName })).sorted()
    }
    
    var body: some View {
        ZStack {
            Color.darkBackground.ignoresSafeArea()
            
            // No source configured - show empty state
            if sources.isEmpty {
                noSourceState
            }
            // Show loading screen while loading channels
            else if sourceManager.isLoadingChannels && channels.isEmpty {
                LoadingView(message: sourceManager.loadingMessage, progress: sourceManager.loadingProgress)
            }
            // Source exists but no channels yet
            else if channels.isEmpty {
                emptyState
            }
            // Show channels
            else {
                channelGrid
            }
        }
        .navigationTitle("Live TV")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
        .fullScreenCover(item: $selectedChannel) { channel in
            VideoPlayerView(
                title: channel.name,
                streamURL: channel.streamURL,
                posterURL: channel.logoURL,
                isLiveStream: true
            )
        }
        .task {
            await loadEPGData()
        }
    }
    
    private var noSourceState: some View {
        EmptyStateView(
            icon: "plus.circle",
            title: "No Source Configured",
            message: "Add an IPTV source in Settings to start watching live TV.",
            actionTitle: nil,
            action: nil
        )
    }
    
    private var emptyState: some View {
        EmptyStateView(
            icon: "antenna.radiowaves.left.and.right",
            title: "No Channels",
            message: "Your source doesn't have any live TV channels, or they're still loading.",
            actionTitle: nil,
            action: nil
        )
    }
    
    private var channelGrid: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                // Background loading indicator
                if sourceManager.isLoadingMovies || sourceManager.isLoadingSeries {
                    BackgroundLoadingBanner(message: sourceManager.loadingMessage)
                }
                
                // Search
                SearchBar(text: $searchText, placeholder: "Search channels...")
                    .padding(.horizontal, 16)
                
                // Categories
                if !categories.isEmpty {
                    CategoryPicker(
                        categories: categories,
                        selectedCategory: $selectedCategory
                    )
                }
                
                // Results count
                Text("\(channels.count) channel\(channels.count == 1 ? "" : "s")")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)
                
                // Channel grid
                LazyVGrid(
                    columns: gridColumns,
                    spacing: 16
                ) {
                    ForEach(channels) { channel in
                        ChannelCard(
                            channel: channel,
                            currentProgram: getCurrentProgram(for: channel)
                        ) {
                            selectedChannel = channel
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
        [GridItem(.adaptive(minimum: 200, maximum: 280), spacing: 16)]
        #else
        [GridItem(.adaptive(minimum: 160, maximum: 200), spacing: 12)]
        #endif
    }
    
    private func getCurrentProgram(for channel: Channel) -> EPGProgramData? {
        guard let epgID = channel.epgID ?? channel.tvgName else { return nil }
        let now = Date()
        return epgData[epgID]?.first { program in
            program.startTime <= now && program.endTime > now
        }
    }
    
    private func loadEPGData() async {
        guard let source = sources.first(where: { $0.isActive }),
              let epgURL = source.epgURL else { return }
        
        do {
            epgData = try await EPGService.shared.fetchEPG(from: epgURL)
        } catch {
            print("Failed to load EPG: \(error)")
        }
    }
}

#Preview {
    NavigationStack {
        LiveTVView(sourceManager: SourceManager())
    }
    .modelContainer(for: [Source.self, Channel.self], inMemory: true)
}
