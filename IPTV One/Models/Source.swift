//
//  Source.swift
//  IPTV One
//
//  Created by Robin Nap on 21/01/2026.
//

import Foundation
import SwiftData

enum SourceType: String, Codable {
    case m3u = "m3u"
    case xtream = "xtream"
}

@Model
final class Source {
    var id: UUID = UUID()
    var name: String = ""
    var url: String = ""  // M3U URL or Xtream server URL
    var username: String?
    var password: String?
    var epgURL: String?
    var lastUpdated: Date?
    var isActive: Bool = true
    var sourceTypeRaw: String = SourceType.m3u.rawValue
    
    var sourceType: SourceType {
        get { SourceType(rawValue: sourceTypeRaw) ?? .m3u }
        set { sourceTypeRaw = newValue.rawValue }
    }
    
    @Relationship(deleteRule: .cascade)
    var channels: [Channel]?
    
    @Relationship(deleteRule: .cascade)
    var movies: [Movie]?
    
    @Relationship(deleteRule: .cascade)
    var series: [Series]?
    
    init(
        id: UUID = UUID(),
        name: String,
        url: String,
        username: String? = nil,
        password: String? = nil,
        epgURL: String? = nil,
        lastUpdated: Date? = nil,
        isActive: Bool = true,
        sourceType: SourceType = .m3u
    ) {
        self.id = id
        self.name = name
        self.url = url
        self.username = username
        self.password = password
        self.epgURL = epgURL
        self.lastUpdated = lastUpdated
        self.isActive = isActive
        self.sourceTypeRaw = sourceType.rawValue
        self.channels = []
        self.movies = []
        self.series = []
    }
    
    // Helper computed properties to safely access optional arrays
    var channelsList: [Channel] {
        get { channels ?? [] }
        set { channels = newValue }
    }
    
    var moviesList: [Movie] {
        get { movies ?? [] }
        set { movies = newValue }
    }
    
    var seriesList: [Series] {
        get { series ?? [] }
        set { series = newValue }
    }
    
    // Xtream credentials helper
    var xtreamCredentials: XtreamService.XtreamCredentials? {
        guard sourceType == .xtream,
              let username = username,
              let password = password else {
            return nil
        }
        return XtreamService.XtreamCredentials(
            serverURL: url,
            username: username,
            password: password
        )
    }
}
