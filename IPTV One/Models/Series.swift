//
//  Series.swift
//  IPTV One
//
//  Created by Robin Nap on 21/01/2026.
//

import Foundation
import SwiftData

@Model
final class Series {
    var id: UUID
    var name: String
    var posterURL: String?
    var categoryName: String
    var plot: String?
    var year: String?
    var rating: String?
    var cast: String?
    var director: String?
    var isFavorite: Bool
    
    @Relationship(deleteRule: .cascade)
    var seasons: [Season]
    
    @Relationship(inverse: \Source.series)
    var source: Source?
    
    init(
        id: UUID = UUID(),
        name: String,
        posterURL: String? = nil,
        categoryName: String = "Uncategorized",
        plot: String? = nil,
        year: String? = nil,
        rating: String? = nil,
        cast: String? = nil,
        director: String? = nil,
        isFavorite: Bool = false
    ) {
        self.id = id
        self.name = name
        self.posterURL = posterURL
        self.categoryName = categoryName
        self.plot = plot
        self.year = year
        self.rating = rating
        self.cast = cast
        self.director = director
        self.isFavorite = isFavorite
        self.seasons = []
    }
}

@Model
final class Season {
    var id: UUID
    var seasonNumber: Int
    var name: String?
    
    @Relationship(deleteRule: .cascade)
    var episodes: [Episode]
    
    @Relationship(inverse: \Series.seasons)
    var series: Series?
    
    init(
        id: UUID = UUID(),
        seasonNumber: Int,
        name: String? = nil
    ) {
        self.id = id
        self.seasonNumber = seasonNumber
        self.name = name
        self.episodes = []
    }
}

@Model
final class Episode {
    var id: UUID
    var episodeNumber: Int
    var name: String
    var streamURL: String
    var plot: String?
    var duration: String?
    var stillURL: String?
    var watchProgress: Double
    var lastWatched: Date?
    
    @Relationship(inverse: \Season.episodes)
    var season: Season?
    
    init(
        id: UUID = UUID(),
        episodeNumber: Int,
        name: String,
        streamURL: String,
        plot: String? = nil,
        duration: String? = nil,
        stillURL: String? = nil,
        watchProgress: Double = 0,
        lastWatched: Date? = nil
    ) {
        self.id = id
        self.episodeNumber = episodeNumber
        self.name = name
        self.streamURL = streamURL
        self.plot = plot
        self.duration = duration
        self.stillURL = stillURL
        self.watchProgress = watchProgress
        self.lastWatched = lastWatched
    }
}
