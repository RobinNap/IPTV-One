//
//  IPTV_OneApp.swift
//  IPTV One
//
//  Created by Robin Nap on 21/01/2026.
//

import SwiftUI
import SwiftData

@main
struct IPTV_OneApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Playlist.self,
            Channel.self,
            Movie.self,
            Series.self,
            Season.self,
            Episode.self,
            Category.self,
            EPGProgram.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        
        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
    
    var body: some Scene {
        WindowGroup {
            NavigationStack {
                MainTabView()
            }
            .preferredColorScheme(.dark)
        }
        .modelContainer(sharedModelContainer)
        #if os(macOS)
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1200, height: 800)
        #endif
    }
}
