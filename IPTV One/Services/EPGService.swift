//
//  EPGService.swift
//  IPTV One
//
//  Created by Robin Nap on 21/01/2026.
//

import Foundation

struct EPGProgramData {
    var channelID: String
    var title: String
    var description: String?
    var startTime: Date
    var endTime: Date
    var category: String?
    var iconURL: String?
}

actor EPGService {
    static let shared = EPGService()
    
    private var programCache: [String: [EPGProgramData]] = [:]
    private var lastUpdate: Date?
    private let cacheExpiry: TimeInterval = 3600 // 1 hour
    
    private init() {}
    
    func fetchEPG(from urlString: String) async throws -> [String: [EPGProgramData]] {
        // Check cache
        if let lastUpdate = lastUpdate,
           Date().timeIntervalSince(lastUpdate) < cacheExpiry,
           !programCache.isEmpty {
            return programCache
        }
        
        guard let url = URL(string: urlString) else {
            throw NetworkError.invalidURL
        }
        
        let data = try await NetworkService.shared.fetchData(from: url, useCache: false)
        let programs = try parseXMLTV(data: data)
        
        // Group by channel ID
        var grouped: [String: [EPGProgramData]] = [:]
        for program in programs {
            grouped[program.channelID, default: []].append(program)
        }
        
        // Sort each channel's programs by start time
        for (channelID, channelPrograms) in grouped {
            grouped[channelID] = channelPrograms.sorted { $0.startTime < $1.startTime }
        }
        
        programCache = grouped
        lastUpdate = Date()
        
        return grouped
    }
    
    func getCurrentProgram(for channelID: String) -> EPGProgramData? {
        let now = Date()
        return programCache[channelID]?.first { program in
            program.startTime <= now && program.endTime > now
        }
    }
    
    func getNextProgram(for channelID: String) -> EPGProgramData? {
        let now = Date()
        return programCache[channelID]?.first { program in
            program.startTime > now
        }
    }
    
    func getPrograms(for channelID: String, on date: Date = Date()) -> [EPGProgramData] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? date
        
        return programCache[channelID]?.filter { program in
            program.startTime >= startOfDay && program.startTime < endOfDay
        } ?? []
    }
    
    func clearCache() {
        programCache.removeAll()
        lastUpdate = nil
    }
    
    private func parseXMLTV(data: Data) throws -> [EPGProgramData] {
        let parser = XMLTVParser()
        return try parser.parse(data: data)
    }
}

// XMLTV Parser
private class XMLTVParser: NSObject, XMLParserDelegate {
    private var programs: [EPGProgramData] = []
    private var currentElement: String = ""
    private var currentChannelID: String?
    private var currentTitle: String = ""
    private var currentDescription: String = ""
    private var currentCategory: String = ""
    private var currentIconURL: String?
    private var currentStartTime: Date?
    private var currentEndTime: Date?
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMddHHmmss Z"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()
    
    private let dateFormatterNoTZ: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMddHHmmss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter
    }()
    
    func parse(data: Data) throws -> [EPGProgramData] {
        programs = []
        let parser = XMLParser(data: data)
        parser.delegate = self
        
        if parser.parse() {
            return programs
        } else if let error = parser.parserError {
            throw error
        }
        
        return programs
    }
    
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        currentElement = elementName
        
        if elementName == "programme" {
            currentChannelID = attributeDict["channel"]
            
            if let start = attributeDict["start"] {
                currentStartTime = parseDate(start)
            }
            if let stop = attributeDict["stop"] {
                currentEndTime = parseDate(stop)
            }
            
            currentTitle = ""
            currentDescription = ""
            currentCategory = ""
            currentIconURL = nil
        } else if elementName == "icon" {
            currentIconURL = attributeDict["src"]
        }
    }
    
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        
        switch currentElement {
        case "title":
            currentTitle += trimmed
        case "desc":
            currentDescription += trimmed
        case "category":
            currentCategory += trimmed
        default:
            break
        }
    }
    
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if elementName == "programme" {
            if let channelID = currentChannelID,
               let startTime = currentStartTime,
               let endTime = currentEndTime,
               !currentTitle.isEmpty {
                
                let program = EPGProgramData(
                    channelID: channelID,
                    title: currentTitle,
                    description: currentDescription.isEmpty ? nil : currentDescription,
                    startTime: startTime,
                    endTime: endTime,
                    category: currentCategory.isEmpty ? nil : currentCategory,
                    iconURL: currentIconURL
                )
                programs.append(program)
            }
        }
        
        currentElement = ""
    }
    
    private func parseDate(_ string: String) -> Date? {
        // Try with timezone first
        if let date = dateFormatter.date(from: string) {
            return date
        }
        
        // Try without timezone
        let cleaned = string.components(separatedBy: " ").first ?? string
        return dateFormatterNoTZ.date(from: cleaned)
    }
}
