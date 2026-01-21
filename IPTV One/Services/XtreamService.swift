//
//  XtreamService.swift
//  IPTV One
//
//  Created by Robin Nap on 21/01/2026.
//

import Foundation

// MARK: - Flexible Decoding Helpers

/// Decodes a value that could be either a String or an Int as an Int
struct FlexibleInt: Codable, Sendable {
    let value: Int?
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let intValue = try? container.decode(Int.self) {
            value = intValue
        } else if let stringValue = try? container.decode(String.self) {
            value = Int(stringValue)
        } else {
            value = nil
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(value)
    }
}

/// Decodes a value that could be either a String or a Double as a Double
struct FlexibleDouble: Codable, Sendable {
    let value: Double?
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let doubleValue = try? container.decode(Double.self) {
            value = doubleValue
        } else if let stringValue = try? container.decode(String.self) {
            value = Double(stringValue)
        } else if let intValue = try? container.decode(Int.self) {
            value = Double(intValue)
        } else {
            value = nil
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(value)
    }
}

// MARK: - Xtream API Response Models

struct XtreamUserInfo: Codable, Sendable {
    let username: String?
    let password: String?
    let status: String?
    let expDate: String?
    let isTrial: String?
    let activeCons: String?
    let createdAt: String?
    let maxConnections: String?
    let allowedOutputFormats: [String]?
    
    enum CodingKeys: String, CodingKey {
        case username, password, status
        case expDate = "exp_date"
        case isTrial = "is_trial"
        case activeCons = "active_cons"
        case createdAt = "created_at"
        case maxConnections = "max_connections"
        case allowedOutputFormats = "allowed_output_formats"
    }
}

struct XtreamServerInfo: Codable, Sendable {
    let url: String?
    let port: String?
    let httpsPort: String?
    let serverProtocol: String?
    let rtmpPort: String?
    let timezone: String?
    let timestampNow: FlexibleInt?
    let timeNow: String?
    
    enum CodingKeys: String, CodingKey {
        case url, port, timezone
        case httpsPort = "https_port"
        case serverProtocol = "server_protocol"
        case rtmpPort = "rtmp_port"
        case timestampNow = "timestamp_now"
        case timeNow = "time_now"
    }
}

struct XtreamAuthResponse: Codable, Sendable {
    let userInfo: XtreamUserInfo?
    let serverInfo: XtreamServerInfo?
    
    enum CodingKeys: String, CodingKey {
        case userInfo = "user_info"
        case serverInfo = "server_info"
    }
}

struct XtreamCategory: Codable, Sendable {
    let categoryId: String?
    let categoryName: String?
    let parentId: FlexibleInt?
    
    enum CodingKeys: String, CodingKey {
        case categoryId = "category_id"
        case categoryName = "category_name"
        case parentId = "parent_id"
    }
}

struct XtreamLiveStream: Codable, Sendable {
    let num: FlexibleInt?
    let name: String?
    let streamType: String?
    let streamId: FlexibleInt?
    let streamIcon: String?
    let epgChannelId: String?
    let added: String?
    let categoryId: String?
    let customSid: String?
    let tvArchive: FlexibleInt?
    let directSource: String?
    let tvArchiveDuration: FlexibleInt?
    
    enum CodingKeys: String, CodingKey {
        case num, name, added
        case streamType = "stream_type"
        case streamId = "stream_id"
        case streamIcon = "stream_icon"
        case epgChannelId = "epg_channel_id"
        case categoryId = "category_id"
        case customSid = "custom_sid"
        case tvArchive = "tv_archive"
        case directSource = "direct_source"
        case tvArchiveDuration = "tv_archive_duration"
    }
}

struct XtreamVodStream: Codable, Sendable {
    let num: FlexibleInt?
    let name: String?
    let streamType: String?
    let streamId: FlexibleInt?
    let streamIcon: String?
    let rating: String?
    let rating5based: FlexibleDouble?
    let added: String?
    let categoryId: String?
    let containerExtension: String?
    let customSid: String?
    let directSource: String?
    
    enum CodingKeys: String, CodingKey {
        case num, name, rating, added
        case streamType = "stream_type"
        case streamId = "stream_id"
        case streamIcon = "stream_icon"
        case rating5based = "rating_5based"
        case categoryId = "category_id"
        case containerExtension = "container_extension"
        case customSid = "custom_sid"
        case directSource = "direct_source"
    }
}

struct XtreamSeries: Codable, Sendable {
    let num: FlexibleInt?
    let name: String?
    let seriesId: FlexibleInt?
    let cover: String?
    let plot: String?
    let cast: String?
    let director: String?
    let genre: String?
    let releaseDate: String?
    let lastModified: String?
    let rating: String?
    let rating5based: FlexibleDouble?
    let backdropPath: [String]?
    let youtubeTrailer: String?
    let episodeRunTime: String?
    let categoryId: String?
    
    enum CodingKeys: String, CodingKey {
        case num, name, cover, plot, cast, director, genre, rating
        case seriesId = "series_id"
        case releaseDate = "releaseDate"
        case lastModified = "last_modified"
        case rating5based = "rating_5based"
        case backdropPath = "backdrop_path"
        case youtubeTrailer = "youtube_trailer"
        case episodeRunTime = "episode_run_time"
        case categoryId = "category_id"
    }
}

struct XtreamSeriesInfo: Codable, Sendable {
    let seasons: [XtreamSeasonInfo]?
    let info: XtreamSeriesDetails?
    let episodes: [String: [XtreamEpisode]]?
}

struct XtreamSeasonInfo: Codable, Sendable {
    let airDate: String?
    let episodeCount: FlexibleInt?
    let id: FlexibleInt?
    let name: String?
    let overview: String?
    let seasonNumber: FlexibleInt?
    let cover: String?
    let coverBig: String?
    
    enum CodingKeys: String, CodingKey {
        case id, name, overview, cover
        case airDate = "air_date"
        case episodeCount = "episode_count"
        case seasonNumber = "season_number"
        case coverBig = "cover_big"
    }
}

struct XtreamSeriesDetails: Codable, Sendable {
    let name: String?
    let cover: String?
    let plot: String?
    let cast: String?
    let director: String?
    let genre: String?
    let releaseDate: String?
    let rating: String?
    let rating5based: FlexibleDouble?
    let backdropPath: [String]?
    let youtubeTrailer: String?
    let episodeRunTime: String?
    let categoryId: String?
    
    enum CodingKeys: String, CodingKey {
        case name, cover, plot, cast, director, genre, rating
        case releaseDate = "releaseDate"
        case rating5based = "rating_5based"
        case backdropPath = "backdrop_path"
        case youtubeTrailer = "youtube_trailer"
        case episodeRunTime = "episode_run_time"
        case categoryId = "category_id"
    }
}

struct XtreamEpisode: Codable, Sendable {
    let id: String?
    let episodeNum: FlexibleInt?
    let title: String?
    let containerExtension: String?
    let info: XtreamEpisodeInfo?
    let customSid: String?
    let added: String?
    let season: FlexibleInt?
    let directSource: String?
    
    enum CodingKeys: String, CodingKey {
        case id, title, info, added, season
        case episodeNum = "episode_num"
        case containerExtension = "container_extension"
        case customSid = "custom_sid"
        case directSource = "direct_source"
    }
}

struct XtreamEpisodeInfo: Codable, Sendable {
    let movieImage: String?
    let plot: String?
    let releasedate: String?
    let rating: FlexibleDouble?
    let name: String?
    let duration: String?
    let durationSecs: FlexibleInt?
    let bitrate: FlexibleInt?
    
    enum CodingKeys: String, CodingKey {
        case plot, releasedate, rating, name, duration, bitrate
        case movieImage = "movie_image"
        case durationSecs = "duration_secs"
    }
}

// MARK: - Xtream Service

actor XtreamService {
    static let shared = XtreamService()
    
    private init() {}
    
    struct XtreamCredentials: Sendable {
        let serverURL: String
        let username: String
        let password: String
        
        var baseURL: String {
            var url = serverURL.trimmingCharacters(in: .whitespacesAndNewlines)
            // Remove trailing slash
            while url.hasSuffix("/") {
                url = String(url.dropLast())
            }
            // Ensure http/https prefix
            if !url.lowercased().hasPrefix("http://") && !url.lowercased().hasPrefix("https://") {
                url = "http://" + url
            }
            return url
        }
        
        var apiURL: String {
            "\(baseURL)/player_api.php?username=\(username)&password=\(password)"
        }
        
        func liveStreamURL(streamId: Int, format: String = "m3u8") -> String {
            "\(baseURL)/live/\(username)/\(password)/\(streamId).\(format)"
        }
        
        /// Returns the live stream URL - tries .ts format which is more universally supported
        func liveStreamURLTS(streamId: Int) -> String {
            "\(baseURL)/live/\(username)/\(password)/\(streamId).ts"
        }
        
        func vodStreamURL(streamId: Int, extension ext: String) -> String {
            "\(baseURL)/movie/\(username)/\(password)/\(streamId).\(ext)"
        }
        
        func seriesStreamURL(streamId: Int, extension ext: String) -> String {
            "\(baseURL)/series/\(username)/\(password)/\(streamId).\(ext)"
        }
    }
    
    nonisolated func authenticate(credentials: XtreamCredentials) async throws -> XtreamAuthResponse {
        guard let url = URL(string: credentials.apiURL) else {
            throw XtreamError.invalidURL
        }
        
        print("[XtreamService] Authenticating with: \(credentials.baseURL)")
        
        // Use fast fetch for API calls
        let data = try await NetworkService.shared.fetchDataFast(from: url)
        
        let decoder = JSONDecoder()
        do {
            let response = try decoder.decode(XtreamAuthResponse.self, from: data)
            
            guard response.userInfo?.status == "Active" else {
                throw XtreamError.accountInactive
            }
            
            print("[XtreamService] Authentication successful")
            return response
        } catch let error as XtreamError {
            throw error
        } catch {
            print("[XtreamService] Decoding error: \(error)")
            throw XtreamError.invalidResponse
        }
    }
    
    nonisolated func getLiveCategories(credentials: XtreamCredentials) async throws -> [XtreamCategory] {
        let urlString = "\(credentials.apiURL)&action=get_live_categories"
        guard let url = URL(string: urlString) else {
            throw XtreamError.invalidURL
        }
        
        print("[XtreamService] Fetching live categories")
        let data = try await NetworkService.shared.fetchDataFast(from: url)
        return try JSONDecoder().decode([XtreamCategory].self, from: data)
    }
    
    nonisolated func getVodCategories(credentials: XtreamCredentials) async throws -> [XtreamCategory] {
        let urlString = "\(credentials.apiURL)&action=get_vod_categories"
        guard let url = URL(string: urlString) else {
            throw XtreamError.invalidURL
        }
        
        print("[XtreamService] Fetching VOD categories")
        let data = try await NetworkService.shared.fetchDataFast(from: url)
        return try JSONDecoder().decode([XtreamCategory].self, from: data)
    }
    
    nonisolated func getSeriesCategories(credentials: XtreamCredentials) async throws -> [XtreamCategory] {
        let urlString = "\(credentials.apiURL)&action=get_series_categories"
        guard let url = URL(string: urlString) else {
            throw XtreamError.invalidURL
        }
        
        print("[XtreamService] Fetching series categories")
        let data = try await NetworkService.shared.fetchDataFast(from: url)
        return try JSONDecoder().decode([XtreamCategory].self, from: data)
    }
    
    nonisolated func getLiveStreams(credentials: XtreamCredentials) async throws -> [XtreamLiveStream] {
        let urlString = "\(credentials.apiURL)&action=get_live_streams"
        guard let url = URL(string: urlString) else {
            throw XtreamError.invalidURL
        }
        
        print("[XtreamService] Fetching live streams")
        // This can return a lot of data, use regular fetch
        let data = try await NetworkService.shared.fetchData(from: url, useCache: false, verbose: false)
        return try JSONDecoder().decode([XtreamLiveStream].self, from: data)
    }
    
    nonisolated func getVodStreams(credentials: XtreamCredentials) async throws -> [XtreamVodStream] {
        let urlString = "\(credentials.apiURL)&action=get_vod_streams"
        guard let url = URL(string: urlString) else {
            throw XtreamError.invalidURL
        }
        
        print("[XtreamService] Fetching VOD streams")
        // This can return a lot of data, use regular fetch
        let data = try await NetworkService.shared.fetchData(from: url, useCache: false, verbose: false)
        return try JSONDecoder().decode([XtreamVodStream].self, from: data)
    }
    
    nonisolated func getSeries(credentials: XtreamCredentials) async throws -> [XtreamSeries] {
        let urlString = "\(credentials.apiURL)&action=get_series"
        guard let url = URL(string: urlString) else {
            throw XtreamError.invalidURL
        }
        
        print("[XtreamService] Fetching series")
        // This can return a lot of data, use regular fetch
        let data = try await NetworkService.shared.fetchData(from: url, useCache: false, verbose: false)
        return try JSONDecoder().decode([XtreamSeries].self, from: data)
    }
    
    nonisolated func getSeriesInfo(credentials: XtreamCredentials, seriesId: Int) async throws -> XtreamSeriesInfo {
        let urlString = "\(credentials.apiURL)&action=get_series_info&series_id=\(seriesId)"
        guard let url = URL(string: urlString) else {
            throw XtreamError.invalidURL
        }
        
        print("[XtreamService] Fetching series info for ID: \(seriesId)")
        let data = try await NetworkService.shared.fetchDataFast(from: url)
        return try JSONDecoder().decode(XtreamSeriesInfo.self, from: data)
    }
}

enum XtreamError: LocalizedError {
    case invalidURL
    case invalidResponse
    case authenticationFailed
    case accountInactive
    case accountExpired
    case networkError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid server URL"
        case .invalidResponse:
            return "Invalid response from server. Please check your credentials."
        case .authenticationFailed:
            return "Authentication failed. Please check your username and password."
        case .accountInactive:
            return "Your account is not active. Please contact your provider."
        case .accountExpired:
            return "Your account has expired. Please renew your subscription."
        case .networkError(let message):
            return "Network error: \(message)"
        }
    }
}
