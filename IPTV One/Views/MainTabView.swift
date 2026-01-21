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
    @State private var sourceManager = SourceManager()
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
            NavigationStack {
                LiveTVView(sourceManager: sourceManager)
            }
            .tabItem {
                Label(AppTab.liveTV.rawValue, systemImage: AppTab.liveTV.icon)
            }
            .tag(AppTab.liveTV)
            
            NavigationStack {
                MoviesView(sourceManager: sourceManager)
            }
            .tabItem {
                Label(AppTab.movies.rawValue, systemImage: AppTab.movies.icon)
            }
            .tag(AppTab.movies)
            
            NavigationStack {
                SeriesView(sourceManager: sourceManager)
            }
            .tabItem {
                Label(AppTab.series.rawValue, systemImage: AppTab.series.icon)
            }
            .tag(AppTab.series)
            
            NavigationStack {
                SettingsView(sourceManager: sourceManager)
            }
            .tabItem {
                Label(AppTab.settings.rawValue, systemImage: AppTab.settings.icon)
            }
            .tag(AppTab.settings)
        }
        .tint(.primaryAccent)
        .onAppear {
            configureTabBarAppearance()
            sourceManager.setModelContext(modelContext)
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
                    NavigationStack {
                        LiveTVView(sourceManager: sourceManager)
                    }
                case .movies:
                    NavigationStack {
                        MoviesView(sourceManager: sourceManager)
                    }
                case .series:
                    NavigationStack {
                        SeriesView(sourceManager: sourceManager)
                    }
                case .settings:
                    NavigationStack {
                        SettingsView(sourceManager: sourceManager)
                    }
                }
            }
        }
        .onAppear {
            sourceManager.setModelContext(modelContext)
        }
    }
    #endif
}

#Preview {
    MainTabView()
        .modelContainer(for: [Source.self, Channel.self, Movie.self, Series.self], inMemory: true)
}
