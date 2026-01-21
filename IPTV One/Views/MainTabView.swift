//
//  MainTabView.swift
//  IPTV One
//
//  Created by Robin Nap on 21/01/2026.
//

import SwiftUI
import SwiftData

enum AppTab: String, CaseIterable {
    case liveTV = "Live TV"
    case movies = "Movies"
    case series = "Series"
    case settings = "Settings"
    
    var icon: String {
        switch self {
        case .liveTV: return "antenna.radiowaves.left.and.right"
        case .movies: return "film"
        case .series: return "tv"
        case .settings: return "gearshape"
        }
    }
}

struct MainTabView: View {
    @State private var selectedTab: AppTab = .liveTV
    @State private var playlistManager = PlaylistManager()
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        #if os(macOS)
        macOSLayout
        #else
        iOSLayout
        #endif
    }
    
    // MARK: - iOS Layout (Tab Bar)
    
    #if os(iOS)
    private var iOSLayout: some View {
        TabView(selection: $selectedTab) {
            LiveTVView(playlistManager: playlistManager)
                .tabItem {
                    Label(AppTab.liveTV.rawValue, systemImage: AppTab.liveTV.icon)
                }
                .tag(AppTab.liveTV)
            
            MoviesView(playlistManager: playlistManager)
                .tabItem {
                    Label(AppTab.movies.rawValue, systemImage: AppTab.movies.icon)
                }
                .tag(AppTab.movies)
            
            SeriesView(playlistManager: playlistManager)
                .tabItem {
                    Label(AppTab.series.rawValue, systemImage: AppTab.series.icon)
                }
                .tag(AppTab.series)
            
            SettingsView(playlistManager: playlistManager)
                .tabItem {
                    Label(AppTab.settings.rawValue, systemImage: AppTab.settings.icon)
                }
                .tag(AppTab.settings)
        }
        .tint(.primaryAccent)
        .onAppear {
            configureTabBarAppearance()
            playlistManager.setModelContext(modelContext)
        }
    }
    
    private func configureTabBarAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(Color.darkBackground)
        
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
    #endif
    
    // MARK: - macOS Layout (Sidebar)
    
    #if os(macOS)
    private var macOSLayout: some View {
        NavigationSplitView {
            List(AppTab.allCases, id: \.self, selection: $selectedTab) { tab in
                Label(tab.rawValue, systemImage: tab.icon)
                    .tag(tab)
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 180, ideal: 200)
        } detail: {
            ZStack {
                Color.darkBackground.ignoresSafeArea()
                
                switch selectedTab {
                case .liveTV:
                    LiveTVView(playlistManager: playlistManager)
                case .movies:
                    MoviesView(playlistManager: playlistManager)
                case .series:
                    SeriesView(playlistManager: playlistManager)
                case .settings:
                    SettingsView(playlistManager: playlistManager)
                }
            }
        }
        .onAppear {
            playlistManager.setModelContext(modelContext)
        }
    }
    #endif
}

#Preview {
    MainTabView()
        .modelContainer(for: [Playlist.self, Channel.self, Movie.self, Series.self], inMemory: true)
}
