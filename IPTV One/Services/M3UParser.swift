//
//  M3UParser.swift
//  IPTV One
//
//  Created by Robin Nap on 21/01/2026.
//

import Foundation

struct M3UItem {
    var name: String
    var streamURL: String
    var logoURL: String?
    var groupTitle: String
    var tvgID: String?
    var tvgName: String?
    var duration: Int
    var attributes: [String: String]
    
    // Content type detection
    var contentType: ContentType {
        let groupLower = groupTitle.lowercased()
        let nameLower = name.lowercased()
        
        // Check for VOD/Movie indicators
        if groupLower.contains("vod") || groupLower.contains("movie") ||
           groupLower.contains("film") || groupLower.contains("cinema") {
            return .movie
        }
        
        // Check for Series indicators
        if groupLower.contains("series") || groupLower.contains("episode") ||
           groupLower.contains("season") || nameLower.contains(" s0") ||
           nameLower.contains(" e0") || nameLower.range(of: #"s\d+e\d+"#, options: .regularExpression) != nil {
            return .series
        }
        
        // Default to live TV
        return .live
    }
    
    enum ContentType {
        case live
        case movie
        case series
    }
}

struct M3UPlaylistInfo {
    var epgURL: String?
    var items: [M3UItem]
}

actor M3UParser {
    static let shared = M3UParser()
    
    private init() {}
    
    func parsePlaylist(from url: URL) async throws -> M3UPlaylistInfo {
        let content = try await NetworkService.shared.fetchString(from: url, useCache: false)
        return try parseContent(content)
    }
    
    func parseContent(_ content: String) throws -> M3UPlaylistInfo {
        let lines = content.components(separatedBy: .newlines)
        
        guard !lines.isEmpty else {
            throw M3UParserError.emptyPlaylist
        }
        
        // Check for M3U header
        let firstLine = lines.first?.trimmingCharacters(in: .whitespaces) ?? ""
        guard firstLine.hasPrefix("#EXTM3U") else {
            throw M3UParserError.invalidFormat
        }
        
        // Extract EPG URL from header
        let epgURL = extractAttribute(from: firstLine, key: "url-tvg") ??
                     extractAttribute(from: firstLine, key: "x-tvg-url")
        
        var items: [M3UItem] = []
        var currentInfo: String?
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            
            if trimmedLine.hasPrefix("#EXTINF:") {
                currentInfo = trimmedLine
            } else if !trimmedLine.isEmpty && !trimmedLine.hasPrefix("#") && currentInfo != nil {
                // This is the stream URL
                if let item = parseExtInf(currentInfo!, streamURL: trimmedLine) {
                    items.append(item)
                }
                currentInfo = nil
            }
        }
        
        return M3UPlaylistInfo(epgURL: epgURL, items: items)
    }
    
    private func parseExtInf(_ extInf: String, streamURL: String) -> M3UItem? {
        // Format: #EXTINF:duration tvg-id="..." tvg-name="..." tvg-logo="..." group-title="...",Channel Name
        
        // Remove #EXTINF: prefix
        var info = extInf
        if info.hasPrefix("#EXTINF:") {
            info = String(info.dropFirst(8))
        }
        
        // Extract duration (first number)
        var duration = -1
        if let durationMatch = info.range(of: #"^-?\d+"#, options: .regularExpression) {
            duration = Int(info[durationMatch]) ?? -1
            info = String(info[durationMatch.upperBound...])
        }
        
        // Extract all attributes
        var attributes: [String: String] = [:]
        let attributePattern = #"(\w+[-\w]*)="([^"]*)"#
        let regex = try? NSRegularExpression(pattern: attributePattern, options: [])
        let nsString = info as NSString
        let matches = regex?.matches(in: info, options: [], range: NSRange(location: 0, length: nsString.length)) ?? []
        
        for match in matches {
            if match.numberOfRanges >= 3 {
                let keyRange = match.range(at: 1)
                let valueRange = match.range(at: 2)
                let key = nsString.substring(with: keyRange).lowercased()
                let value = nsString.substring(with: valueRange)
                attributes[key] = value
            }
        }
        
        // Extract channel name (after the last comma)
        var name = "Unknown"
        if let commaIndex = info.lastIndex(of: ",") {
            name = String(info[info.index(after: commaIndex)...]).trimmingCharacters(in: .whitespaces)
        }
        
        // Clean up name - remove any remaining attributes
        if name.isEmpty || name.contains("=") {
            name = attributes["tvg-name"] ?? "Unknown"
        }
        
        return M3UItem(
            name: name,
            streamURL: streamURL,
            logoURL: attributes["tvg-logo"],
            groupTitle: attributes["group-title"] ?? "Uncategorized",
            tvgID: attributes["tvg-id"],
            tvgName: attributes["tvg-name"],
            duration: duration,
            attributes: attributes
        )
    }
    
    private func extractAttribute(from line: String, key: String) -> String? {
        let pattern = "\(key)=\"([^\"]*)\""
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: line, options: [], range: NSRange(location: 0, length: line.utf16.count)),
              match.numberOfRanges >= 2 else {
            return nil
        }
        
        let nsString = line as NSString
        return nsString.substring(with: match.range(at: 1))
    }
}

enum M3UParserError: LocalizedError {
    case invalidFormat
    case emptyPlaylist
    case parseError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidFormat:
            return "Invalid M3U format. File must start with #EXTM3U"
        case .emptyPlaylist:
            return "Playlist is empty"
        case .parseError(let message):
            return "Parse error: \(message)"
        }
    }
}
