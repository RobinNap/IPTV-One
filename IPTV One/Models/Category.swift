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
    var id: UUID = UUID()
    var name: String = ""
    var typeRawValue: String = CategoryType.live.rawValue
    
    var type: CategoryType {
        get { CategoryType(rawValue: typeRawValue) ?? .live }
        set { typeRawValue = newValue.rawValue }
    }
    
    init(id: UUID = UUID(), name: String, type: CategoryType) {
        self.id = id
        self.name = name
        self.typeRawValue = type.rawValue
    }
}

enum CategoryType: String, Codable {
    case live = "live"
    case movie = "movie"
    case series = "series"
}
