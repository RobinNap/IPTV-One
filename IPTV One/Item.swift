//
//  Item.swift
//  IPTV One
//
//  Created by Robin Nap on 21/01/2026.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
