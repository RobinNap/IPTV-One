//
//  Channel.swift
//  IPTV One
//
//  Created by Robin Nap on 21/01/2026.
//

import Foundation
import SwiftData

@Model
final class Channel {
    var id: UUID = UUID()
    var name: String = ""
    var streamURL: String = ""
    var logoURL: String?
    var categoryName: String = "Uncategorized"
    var epgID: String?
    var tvgName: String?
    var isFavorite: Bool = false
    var lastWatched: Date?
    
    @Relationship(inverse: \Source.channels)
    var source: Source?
    
    init(
        id: UUID = UUID(),
        name: String,
        streamURL: String,
        logoURL: String? = nil,
        categoryName: String = "Uncategorized",
        epgID: String? = nil,
        tvgName: String? = nil,
        isFavorite: Bool = false,
        lastWatched: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.streamURL = streamURL
        self.logoURL = logoURL
        self.categoryName = categoryName
        self.epgID = epgID
        self.tvgName = tvgName
        self.isFavorite = isFavorite
        self.lastWatched = lastWatched
    }
}
