//
//  Source.swift
//  IPTV One
//
//  Created by Robin Nap on 21/01/2026.
//

import Foundation
import SwiftData

@Model
final class Source {
    var id: UUID
    var name: String
    var url: String
    var username: String?
    var password: String?
    var epgURL: String?
    var lastUpdated: Date?
    var isActive: Bool
    
    @Relationship(deleteRule: .cascade)
    var channels: [Channel]
    
    @Relationship(deleteRule: .cascade)
    var movies: [Movie]
    
    @Relationship(deleteRule: .cascade)
    var series: [Series]
    
    init(
        id: UUID = UUID(),
        name: String,
        url: String,
        username: String? = nil,
        password: String? = nil,
        epgURL: String? = nil,
        lastUpdated: Date? = nil,
        isActive: Bool = true
    ) {
        self.id = id
        self.name = name
        self.url = url
        self.username = username
        self.password = password
        self.epgURL = epgURL
        self.lastUpdated = lastUpdated
        self.isActive = isActive
        self.channels = []
        self.movies = []
        self.series = []
    }
}
