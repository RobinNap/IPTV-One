//
//  NetworkService.swift
//  IPTV One
//
//  Created by Robin Nap on 21/01/2026.
//

import Foundation

actor NetworkService {
    static let shared = NetworkService()
    
    private let session: URLSession
    private let fastSession: URLSession  // Optimized for speed
    private let streamSession: URLSession  // Optimized for IPTV stream testing
    private let cache = NSCache<NSString, NSData>()
    
    private init() {
        // Standard session for large downloads (playlists, etc.)
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 180
        config.waitsForConnectivity = false
        config.httpMaximumConnectionsPerHost = 6
        config.urlCache = nil  // Disable URL cache for fresh data
        config.httpAdditionalHeaders = [
            "User-Agent": "VLC/3.0.20 LibVLC/3.0.20",  // VLC User-Agent for better compatibility
            "Accept": "*/*",
            "Accept-Language": "en-US,en;q=0.9",
            "Accept-Encoding": "gzip, deflate",
            "Connection": "keep-alive"
        ]
        self.session = URLSession(configuration: config)
        
        // Fast session for quick API calls
        let fastConfig = URLSessionConfiguration.default
        fastConfig.timeoutIntervalForRequest = 15
        fastConfig.timeoutIntervalForResource = 30
        fastConfig.waitsForConnectivity = false
        fastConfig.httpMaximumConnectionsPerHost = 8
        fastConfig.requestCachePolicy = .reloadIgnoringLocalCacheData
        fastConfig.urlCache = nil
        fastConfig.httpAdditionalHeaders = [
            "User-Agent": "VLC/3.0.20 LibVLC/3.0.20",
            "Accept": "application/json, */*",
            "Connection": "keep-alive"
        ]
        self.fastSession = URLSession(configuration: fastConfig)
        
        // Stream session optimized for testing IPTV connectivity
        let streamConfig = URLSessionConfiguration.default
        streamConfig.timeoutIntervalForRequest = 10  // Quick timeout for stream tests
        streamConfig.timeoutIntervalForResource = 20
        streamConfig.waitsForConnectivity = false
        streamConfig.httpMaximumConnectionsPerHost = 4
        streamConfig.requestCachePolicy = .reloadIgnoringLocalCacheData
        streamConfig.urlCache = nil
        streamConfig.httpShouldSetCookies = false
        streamConfig.httpAdditionalHeaders = [
            "User-Agent": "VLC/3.0.20 LibVLC/3.0.20",
            "Accept": "*/*",
            "Accept-Encoding": "identity",  // Don't compress streams
            "Connection": "keep-alive",
            "Icy-MetaData": "1"
        ]
        self.streamSession = URLSession(configuration: streamConfig)
        
        // Configure in-memory cache
        cache.countLimit = 100
        cache.totalCostLimit = 50 * 1024 * 1024 // 50MB
    }
    
    func fetchData(from url: URL, useCache: Bool = true, verbose: Bool = true, fast: Bool = false) async throws -> Data {
        let cacheKey = url.absoluteString as NSString
        
        // Check cache first
        if useCache, let cachedData = cache.object(forKey: cacheKey) {
            if verbose {
                print("[NetworkService] Cache hit for: \(url.absoluteString)")
            }
            return cachedData as Data
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.cachePolicy = .reloadIgnoringLocalCacheData
        
        if verbose {
            print("[NetworkService] Fetching\(fast ? " (fast)" : ""): \(url.absoluteString)")
        }
        
        // Use fast session for API calls, regular for large downloads
        let activeSession = fast ? fastSession : session
        
        do {
            let (data, response) = try await activeSession.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("[NetworkService] Error: Invalid response type")
                throw NetworkError.invalidResponse
            }
            
            if verbose {
                print("[NetworkService] Received \(data.count) bytes")
                print("[NetworkService] HTTP Status: \(httpResponse.statusCode)")
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                print("[NetworkService] Error: HTTP \(httpResponse.statusCode)")
                throw NetworkError.httpError(statusCode: httpResponse.statusCode)
            }
            
            if data.isEmpty {
                print("[NetworkService] Warning: Received empty response")
                throw NetworkError.noData
            }
            
            // Cache the response
            if useCache {
                cache.setObject(data as NSData, forKey: cacheKey, cost: data.count)
            }
            
            return data
            
        } catch let error as NetworkError {
            throw error
        } catch {
            print("[NetworkService] Network error: \(error.localizedDescription)")
            throw NetworkError.connectionFailed(error.localizedDescription)
        }
    }
    
    /// Fast fetch for API calls - shorter timeouts, optimized for speed
    func fetchDataFast(from url: URL, useCache: Bool = false) async throws -> Data {
        try await fetchData(from: url, useCache: useCache, verbose: false, fast: true)
    }
    
    func fetchString(from url: URL, useCache: Bool = true) async throws -> String {
        let data = try await fetchData(from: url, useCache: useCache)
        
        print("[NetworkService] Converting \(data.count) bytes to string")
        
        // Try UTF-8 first
        if let string = String(data: data, encoding: .utf8) {
            print("[NetworkService] Successfully decoded as UTF-8")
            return string
        }
        
        // Try ISO Latin 1 (common for European IPTV providers)
        if let string = String(data: data, encoding: .isoLatin1) {
            print("[NetworkService] Successfully decoded as ISO Latin 1")
            return string
        }
        
        // Try Windows 1252
        if let string = String(data: data, encoding: .windowsCP1252) {
            print("[NetworkService] Successfully decoded as Windows-1252")
            return string
        }
        
        // Try ASCII as last resort
        if let string = String(data: data, encoding: .ascii) {
            print("[NetworkService] Successfully decoded as ASCII")
            return string
        }
        
        print("[NetworkService] Error: Could not decode data with any encoding")
        throw NetworkError.decodingError
    }
    
    func clearCache() {
        cache.removeAllObjects()
    }
    
    /// Test if a stream URL is reachable (for IPTV stream validation)
    func testStreamURL(_ url: URL) async -> Bool {
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"  // Just check headers, don't download
        request.timeoutInterval = 8
        
        do {
            let (_, response) = try await streamSession.data(for: request)
            if let httpResponse = response as? HTTPURLResponse {
                return (200...399).contains(httpResponse.statusCode)
            }
            return false
        } catch {
            // Try GET with range header as fallback (some servers don't support HEAD)
            var getRequest = URLRequest(url: url)
            getRequest.httpMethod = "GET"
            getRequest.setValue("bytes=0-1", forHTTPHeaderField: "Range")
            getRequest.timeoutInterval = 8
            
            do {
                let (_, response) = try await streamSession.data(for: getRequest)
                if let httpResponse = response as? HTTPURLResponse {
                    return (200...399).contains(httpResponse.statusCode)
                }
            } catch {
                return false
            }
            return false
        }
    }
}

enum NetworkError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int)
    case decodingError
    case noData
    case connectionFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .httpError(let statusCode):
            return "Server error (HTTP \(statusCode))"
        case .decodingError:
            return "Failed to decode response - unsupported encoding"
        case .noData:
            return "Server returned empty response"
        case .connectionFailed(let reason):
            return "Connection failed: \(reason)"
        }
    }
}
