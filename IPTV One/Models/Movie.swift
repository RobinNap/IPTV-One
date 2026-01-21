//
//  Movie.swift
//  IPTV One
//
//  Created by Robin Nap on 21/01/2026.
//

import Foundation
import SwiftData

@Model
final class Movie {
    var id: UUID = UUID()
    var name: String = ""
    var streamURL: String = ""
    var posterURL: String?
    var categoryName: String = "Uncategorized"
    var plot: String?
    var year: String?
    var rating: String?
    var duration: String?
    var director: String?
    var cast: String?
    var isFavorite: Bool = false
    var lastWatched: Date?
    var watchProgress: Double = 0
    
    @Relationship(inverse: \Source.movies)
    var source: Source?
    
    init(
        id: UUID = UUID(),
        name: String,
        streamURL: String,
        posterURL: String? = nil,
        categoryName: String = "Uncategorized",
        plot: String? = nil,
        year: String? = nil,
        rating: String? = nil,
        duration: String? = nil,
        director: String? = nil,
        cast: String? = nil,
        isFavorite: Bool = false,
        lastWatched: Date? = nil,
        watchProgress: Double = 0
    ) {
        self.id = id
        self.name = name
        self.streamURL = streamURL
        self.posterURL = posterURL
        self.categoryName = categoryName
        self.plot = plot
        self.year = year
        self.rating = rating
        self.duration = duration
        self.director = director
        self.cast = cast
        self.isFavorite = isFavorite
        self.lastWatched = lastWatched
        self.watchProgress = watchProgress
    }
}
