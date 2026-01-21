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
    
    private var channels: [Channel] {
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
        Array(Set(allChannels.map { $0.categoryName })).sorted()
    }
    
    var body: some View {
        ZStack {
            Color.darkBackground.ignoresSafeArea()
            
            if sourceManager.isLoading {
                LoadingView(message: sourceManager.loadingMessage, progress: sourceManager.loadingProgress)
            } else if allChannels.isEmpty {
                emptyState
            } else {
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
                posterURL: channel.logoURL
            )
        }
        .task {
            await loadEPGData()
        }
    }
    
    private var emptyState: some View {
        EmptyStateView(
            icon: "antenna.radiowaves.left.and.right",
            title: "No Channels",
            message: "Add a source in Settings to start watching live TV channels.",
            actionTitle: nil,
            action: nil
        )
    }
    
    private var channelGrid: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
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
