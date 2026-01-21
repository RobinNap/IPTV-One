//
//  Category.swift
//  IPTV One
//
//  Created by Robin Nap on 21/01/2026.
//

import Foundation
import SwiftData

@Model
final class Category {
    var id: UUID
    var name: String
    var type: CategoryType
    
    init(id: UUID = UUID(), name: String, type: CategoryType) {
        self.id = id
        self.name = name
        self.type = type
    }
}

enum CategoryType: String, Codable {
    case live = "live"
    case movie = "movie"
    case series = "series"
}
