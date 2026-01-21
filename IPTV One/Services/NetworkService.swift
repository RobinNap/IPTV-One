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
    private let cache = NSCache<NSString, NSData>()
    
    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 300 // 5 minutes for large playlists
        config.waitsForConnectivity = true
        config.httpAdditionalHeaders = [
            "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1",
            "Accept": "*/*",
            "Accept-Language": "en-US,en;q=0.9",
            "Accept-Encoding": "gzip, deflate",
            "Connection": "keep-alive"
        ]
        self.session = URLSession(configuration: config)
        
        // Configure cache
        cache.countLimit = 100
        cache.totalCostLimit = 50 * 1024 * 1024 // 50MB
    }
    
    func fetchData(from url: URL, useCache: Bool = true, verbose: Bool = true) async throws -> Data {
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
            print("[NetworkService] Fetching: \(url.absoluteString)")
        }
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("[NetworkService] Error: Invalid response type")
                throw NetworkError.invalidResponse
            }
            
            if verbose {
                print("[NetworkService] Received \(data.count) bytes")
                print("[NetworkService] HTTP Status: \(httpResponse.statusCode)")
                print("[NetworkService] Content-Type: \(httpResponse.value(forHTTPHeaderField: "Content-Type") ?? "unknown")")
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
