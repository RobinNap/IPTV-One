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
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 120
        config.waitsForConnectivity = true
        self.session = URLSession(configuration: config)
        
        // Configure cache
        cache.countLimit = 100
        cache.totalCostLimit = 50 * 1024 * 1024 // 50MB
    }
    
    func fetchData(from url: URL, useCache: Bool = true) async throws -> Data {
        let cacheKey = url.absoluteString as NSString
        
        // Check cache first
        if useCache, let cachedData = cache.object(forKey: cacheKey) {
            return cachedData as Data
        }
        
        let (data, response) = try await session.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw NetworkError.httpError(statusCode: httpResponse.statusCode)
        }
        
        // Cache the response
        if useCache {
            cache.setObject(data as NSData, forKey: cacheKey, cost: data.count)
        }
        
        return data
    }
    
    func fetchString(from url: URL, useCache: Bool = true) async throws -> String {
        let data = try await fetchData(from: url, useCache: useCache)
        
        guard let string = String(data: data, encoding: .utf8) else {
            throw NetworkError.decodingError
        }
        
        return string
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
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .httpError(let statusCode):
            return "HTTP Error: \(statusCode)"
        case .decodingError:
            return "Failed to decode response"
        case .noData:
            return "No data received"
        }
    }
}
