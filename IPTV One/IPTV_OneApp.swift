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
            Source.self,
            Channel.self,
            Movie.self,
            Series.self,
            Season.self,
            Episode.self,
            Category.self,
            EPGProgram.self,
        ])
        
        // Try CloudKit sync first, fall back to local storage if it fails
        do {
            let cloudConfig = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                cloudKitDatabase: .private("iCloud.com.robinnap.IPTV-One")
            )
            return try ModelContainer(for: schema, configurations: [cloudConfig])
        } catch {
            print("CloudKit sync failed, falling back to local storage: \(error)")
            
            // Fall back to local storage without CloudKit
            do {
                let localConfig = ModelConfiguration(
                    schema: schema,
                    isStoredInMemoryOnly: false,
                    cloudKitDatabase: .none
                )
                return try ModelContainer(for: schema, configurations: [localConfig])
            } catch {
                fatalError("Could not create ModelContainer: \(error)")
            }
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
