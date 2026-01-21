//
//  M3UParser.swift
//  IPTV One
//
//  Created by Robin Nap on 21/01/2026.
//

import Foundation

enum M3UContentType: String, Sendable, Equatable {
    case live
    case movie
    case series
}

struct M3UItem: Sendable {
    var name: String
    var streamURL: String
    var logoURL: String?
    var groupTitle: String
    var tvgID: String?
    var tvgName: String?
    var duration: Int
    var attributes: [String: String]
    var contentType: M3UContentType
}

struct M3UPlaylistInfo: Sendable {
    var epgURL: String?
    var items: [M3UItem]
}

actor M3UParser {
    static let shared = M3UParser()
    
    private init() {}
    
    func parsePlaylist(from url: URL) async throws -> M3UPlaylistInfo {
        print("[M3UParser] Fetching playlist from: \(url.absoluteString)")
        let content = try await NetworkService.shared.fetchString(from: url, useCache: false)
        print("[M3UParser] Received \(content.count) characters")
        return parseContent(content)
    }
    
    nonisolated func parseContent(_ content: String) -> M3UPlaylistInfo {
        // Handle different line ending styles
        let normalizedContent = content
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        
        let lines = normalizedContent.components(separatedBy: "\n")
        
        guard !lines.isEmpty else {
            return M3UPlaylistInfo(epgURL: nil, items: [])
        }
        
        // Check for M3U header (be more lenient)
        let firstLine = lines.first?.trimmingCharacters(in: .whitespaces) ?? ""
        let hasValidHeader = firstLine.uppercased().hasPrefix("#EXTM3U")
        
        if !hasValidHeader {
            // Some playlists don't have the header, try to parse anyway if it looks like M3U
            if !content.contains("#EXTINF:") {
                print("[M3UParser] Invalid format - no header and no EXTINF entries")
                return M3UPlaylistInfo(epgURL: nil, items: [])
            }
            print("[M3UParser] Warning: Missing #EXTM3U header, attempting to parse anyway")
        }
        
        // Extract EPG URL from header
        let epgURL = extractAttribute(from: firstLine, key: "url-tvg") ??
                     extractAttribute(from: firstLine, key: "x-tvg-url") ??
                     extractAttribute(from: firstLine, key: "tvg-url")
        
        print("[M3UParser] EPG URL: \(epgURL ?? "not found")")
        
        var items: [M3UItem] = []
        var currentInfo: String?
        var lineCount = 0
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if trimmedLine.hasPrefix("#EXTINF:") {
                currentInfo = trimmedLine
                lineCount += 1
            } else if !trimmedLine.isEmpty && !trimmedLine.hasPrefix("#") && currentInfo != nil {
                // This is the stream URL
                if let item = parseExtInf(currentInfo!, streamURL: trimmedLine) {
                    items.append(item)
                }
                currentInfo = nil
            }
        }
        
        print("[M3UParser] Parsed \(items.count) items")
        
        // Log content type breakdown
        let liveCount = items.filter { $0.contentType == .live }.count
        let movieCount = items.filter { $0.contentType == .movie }.count
        let seriesCount = items.filter { $0.contentType == .series }.count
        print("[M3UParser] Content breakdown - Live: \(liveCount), Movies: \(movieCount), Series: \(seriesCount)")
        
        if items.isEmpty && lineCount > 0 {
            print("[M3UParser] Warning: Found \(lineCount) entries but failed to parse any valid items")
        }
        
        return M3UPlaylistInfo(epgURL: epgURL, items: items)
    }
    
    nonisolated private func parseExtInf(_ extInf: String, streamURL: String) -> M3UItem? {
        // Format: #EXTINF:duration tvg-id="..." tvg-name="..." tvg-logo="..." group-title="...",Channel Name
        
        // Validate stream URL
        guard !streamURL.isEmpty,
              streamURL.lowercased().hasPrefix("http://") || streamURL.lowercased().hasPrefix("https://") else {
            return nil
        }
        
        // Remove #EXTINF: prefix
        var info = extInf
        if info.hasPrefix("#EXTINF:") {
            info = String(info.dropFirst(8))
        }
        
        // Extract duration (first number, can be negative)
        var duration = -1
        if let durationMatch = info.range(of: #"^-?\d+"#, options: .regularExpression) {
            duration = Int(info[durationMatch]) ?? -1
            info = String(info[durationMatch.upperBound...])
        }
        
        // Extract all attributes
        var attributes: [String: String] = [:]
        let attributePattern = #"([\w-]+)="([^"]*)"#
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
        
        // Extract channel name (after the last comma, outside of quotes)
        var name = "Unknown"
        
        // Find the last comma that's not inside quotes
        var insideQuotes = false
        var lastCommaIndex: String.Index?
        for (index, char) in info.enumerated() {
            if char == "\"" {
                insideQuotes = !insideQuotes
            } else if char == "," && !insideQuotes {
                lastCommaIndex = info.index(info.startIndex, offsetBy: index)
            }
        }
        
        if let commaIndex = lastCommaIndex {
            name = String(info[info.index(after: commaIndex)...]).trimmingCharacters(in: .whitespaces)
        }
        
        // Clean up name
        if name.isEmpty {
            name = attributes["tvg-name"] ?? "Unknown"
        }
        
        // Remove any leftover attribute patterns from name
        if name.contains("=\"") {
            name = attributes["tvg-name"] ?? "Unknown"
        }
        
        let groupTitle = attributes["group-title"] ?? "Uncategorized"
        let contentType = detectContentType(groupTitle: groupTitle, name: name, streamURL: streamURL)
        
        return M3UItem(
            name: name,
            streamURL: streamURL,
            logoURL: attributes["tvg-logo"],
            groupTitle: groupTitle,
            tvgID: attributes["tvg-id"],
            tvgName: attributes["tvg-name"],
            duration: duration,
            attributes: attributes,
            contentType: contentType
        )
    }
    
    nonisolated private func detectContentType(groupTitle: String, name: String, streamURL: String) -> M3UContentType {
        let groupLower = groupTitle.lowercased()
        let nameLower = name.lowercased()
        let urlLower = streamURL.lowercased()
        
        // Check URL patterns (Xtream Codes specific)
        if urlLower.contains("/movie/") || urlLower.contains("/vod/") {
            return .movie
        }
        
        if urlLower.contains("/series/") {
            return .series
        }
        
        // Check for VOD/Movie indicators in group
        if groupLower.contains("vod") || groupLower.contains("movie") ||
           groupLower.contains("film") || groupLower.contains("cinema") ||
           groupLower.contains("peliculas") || groupLower.contains("filme") {
            return .movie
        }
        
        // Check for Series indicators
        if groupLower.contains("series") || groupLower.contains("episode") ||
           groupLower.contains("season") || groupLower.contains("serie") ||
           nameLower.contains(" s0") || nameLower.contains(" e0") ||
           nameLower.range(of: #"s\d+\s*e\d+"#, options: [.regularExpression, .caseInsensitive]) != nil ||
           nameLower.range(of: #"season\s*\d+"#, options: [.regularExpression, .caseInsensitive]) != nil {
            return .series
        }
        
        // Default to live TV
        return .live
    }
    
    nonisolated private func extractAttribute(from line: String, key: String) -> String? {
        let pattern = "\(key)=\"([^\"]*)\""
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: line, options: [], range: NSRange(location: 0, length: line.utf16.count)),
              match.numberOfRanges >= 2 else {
            return nil
        }
        
        let nsString = line as NSString
        let value = nsString.substring(with: match.range(at: 1))
        return value.isEmpty ? nil : value
    }
}

enum M3UParserError: LocalizedError {
    case invalidFormat
    case emptyPlaylist
    case parseError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidFormat:
            return "Invalid M3U format. The file doesn't appear to be a valid M3U playlist."
        case .emptyPlaylist:
            return "The playlist is empty or could not be downloaded."
        case .parseError(let message):
            return "Parse error: \(message)"
        }
    }
}
