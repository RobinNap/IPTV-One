//
//  EPGProgram.swift
//  IPTV One
//
//  Created by Robin Nap on 21/01/2026.
//

import Foundation
import SwiftData

@Model
final class EPGProgram {
    var id: UUID = UUID()
    var channelID: String = ""
    var title: String = ""
    var programDescription: String?
    var startTime: Date = Date()
    var endTime: Date = Date()
    var category: String?
    var iconURL: String?
    
    init(
        id: UUID = UUID(),
        channelID: String,
        title: String,
        programDescription: String? = nil,
        startTime: Date,
        endTime: Date,
        category: String? = nil,
        iconURL: String? = nil
    ) {
        self.id = id
        self.channelID = channelID
        self.title = title
        self.programDescription = programDescription
        self.startTime = startTime
        self.endTime = endTime
        self.category = category
        self.iconURL = iconURL
    }
    
    var isCurrentlyAiring: Bool {
        let now = Date()
        return startTime <= now && endTime > now
    }
    
    var progress: Double {
        let now = Date()
        guard startTime <= now && endTime > now else { return 0 }
        let total = endTime.timeIntervalSince(startTime)
        let elapsed = now.timeIntervalSince(startTime)
        return elapsed / total
    }
}
