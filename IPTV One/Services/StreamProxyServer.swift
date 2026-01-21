//
//  StreamProxyServer.swift
//  IPTV One
//
//  Created by Robin Nap on 21/01/2026.
//
//  Local HTTP proxy server that bypasses ATS restrictions.
//  Key insight from nodecast-tv: Use proper HTTP/1.0 over plain TCP
//  with forced IPv4 and FFmpeg-compatible headers.
//

import Foundation
import Network
import Combine
import Security

/// A local HTTP proxy server for streaming IPTV content
/// Uses NWConnection with explicit IPv4 to bypass ATS
final class StreamProxyServer: ObservableObject, @unchecked Sendable {
    static let shared = StreamProxyServer()
    
    @MainActor @Published private(set) var isRunning = false
    @MainActor @Published private(set) var port: UInt16 = 0
    
    private var listener: NWListener?
    private var connections: [ObjectIdentifier: NWConnection] = [:]
    private let queue = DispatchQueue(label: "com.iptvone.proxyserver", qos: .userInitiated)
    private let lock = NSLock()
    
    /// Cache for redirect URLs to avoid repeated 302 lookups
    /// Key: original URL path, Value: (redirect URL, timestamp)
    private var redirectCache: [String: (url: String, timestamp: Date)] = [:]
    private let redirectCacheTTL: TimeInterval = 2 // 2 seconds - tokens expire quickly!
    
    /// The base URL for proxied streams
    @MainActor
    var baseURL: String {
        "http://127.0.0.1:\(port)"
    }
    
    private init() {}
    
    /// Get cached redirect URL if available and not expired
    private func getCachedRedirect(for path: String) -> String? {
        lock.lock()
        defer { lock.unlock() }
        
        guard let cached = redirectCache[path] else { return nil }
        
        // Check if cache entry is still valid
        if Date().timeIntervalSince(cached.timestamp) < redirectCacheTTL {
            print("[StreamProxy] Using cached redirect for: \(path.prefix(50))...")
            return cached.url
        } else {
            // Expired, remove from cache
            redirectCache.removeValue(forKey: path)
            return nil
        }
    }
    
    /// Cache a redirect URL
    private func cacheRedirect(for path: String, redirectURL: String) {
        lock.lock()
        defer { lock.unlock() }
        
        redirectCache[path] = (url: redirectURL, timestamp: Date())
        print("[StreamProxy] Cached redirect for: \(path.prefix(50))...")
    }
    
    /// Start the proxy server on an available port
    @MainActor
    func start() async throws {
        guard !isRunning else { return }
        
        let startPort: UInt16 = 9080
        var lastError: Error?
        
        for portAttempt in 0..<10 {
            let tryPort = startPort + UInt16(portAttempt)
            do {
                try await startListener(on: tryPort)
                return
            } catch {
                lastError = error
                print("[StreamProxy] Port \(tryPort) unavailable, trying next...")
            }
        }
        
        throw lastError ?? ProxyError.failedToStart
    }
    
    @MainActor
    private func startListener(on portNum: UInt16) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async { [self] in
                do {
                    let params = NWParameters.tcp
                    params.allowLocalEndpointReuse = true
                    
                    guard let nwPort = NWEndpoint.Port(rawValue: portNum) else {
                        continuation.resume(throwing: ProxyError.failedToStart)
                        return
                    }
                    
                    let newListener = try NWListener(using: params, on: nwPort)
                    self.listener = newListener
                    
                    var didResume = false
                    
                    newListener.stateUpdateHandler = { state in
                        switch state {
                        case .ready:
                            Task { @MainActor [self] in
                                self.isRunning = true
                                self.port = portNum
                            }
                            print("[StreamProxy] ✓ Server started on port \(portNum)")
                            if !didResume {
                                didResume = true
                                continuation.resume()
                            }
                        case .failed(let error):
                            Task { @MainActor [self] in
                                self.isRunning = false
                            }
                            if !didResume {
                                didResume = true
                                continuation.resume(throwing: error)
                            }
                        case .cancelled:
                            Task { @MainActor [self] in
                                self.isRunning = false
                            }
                        default:
                            break
                        }
                    }
                    
                    newListener.newConnectionHandler = { [self] connection in
                        self.handleIncomingConnection(connection)
                    }
                    
                    newListener.start(queue: self.queue)
                    
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    /// Stop the proxy server
    @MainActor
    func stop() {
        listener?.cancel()
        listener = nil
        
        lock.lock()
        let conns = Array(connections.values)
        connections.removeAll()
        lock.unlock()
        
        for conn in conns {
            conn.cancel()
        }
        
        isRunning = false
        port = 0
        print("[StreamProxy] Server stopped")
    }
    
    /// Generate a proxy URL for the given stream URL
    @MainActor
    func proxyURL(for originalURL: String, credentials: (username: String, password: String)? = nil) -> String {
        guard isRunning else { 
            print("[StreamProxy] Warning: Proxy not running, returning original URL")
            return originalURL 
        }
        
        var components = URLComponents()
        components.scheme = "http"
        components.host = "127.0.0.1"
        components.port = Int(port)
        components.path = "/stream"
        
        var queryItems = [URLQueryItem(name: "url", value: originalURL)]
        
        if let creds = credentials {
            queryItems.append(URLQueryItem(name: "user", value: creds.username))
            queryItems.append(URLQueryItem(name: "pass", value: creds.password))
        }
        
        components.queryItems = queryItems
        
        let result = components.url?.absoluteString ?? originalURL
        print("[StreamProxy] Generated proxy URL: \(result)")
        return result
    }
    
    // MARK: - Connection Handling
    
    private func handleIncomingConnection(_ connection: NWConnection) {
        let connId = ObjectIdentifier(connection)
        
        lock.lock()
        connections[connId] = connection
        lock.unlock()
        
        connection.stateUpdateHandler = { [weak self] state in
            if case .cancelled = state {
                self?.lock.lock()
                self?.connections.removeValue(forKey: connId)
                self?.lock.unlock()
            } else if case .failed = state {
                self?.lock.lock()
                self?.connections.removeValue(forKey: connId)
                self?.lock.unlock()
            }
        }
        
        connection.start(queue: queue)
        receiveRequest(from: connection)
    }
    
    private func receiveRequest(from connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, _, error in
            guard let self = self else { return }
            
            if let error = error {
                print("[StreamProxy] Client receive error: \(error)")
                connection.cancel()
                return
            }
            
            guard let data = data, !data.isEmpty,
                  let requestString = String(data: data, encoding: .utf8) else {
                connection.cancel()
                return
            }
            
            self.processRequest(requestString, from: connection)
        }
    }
    
    private func processRequest(_ requestString: String, from clientConnection: NWConnection) {
        // Parse HTTP request
        let lines = requestString.components(separatedBy: "\r\n")
        guard let requestLine = lines.first else {
            sendErrorResponse(to: clientConnection, statusCode: 400, message: "Bad Request")
            return
        }
        
        // Parse request headers
        var requestHeaders: [String: String] = [:]
        for line in lines.dropFirst() {
            if line.isEmpty { break }
            if let colonIdx = line.firstIndex(of: ":") {
                let key = String(line[..<colonIdx]).lowercased()
                let value = String(line[line.index(after: colonIdx)...]).trimmingCharacters(in: .whitespaces)
                requestHeaders[key] = value
            }
        }
        
        // Extract stream URL from path
        let parts = requestLine.components(separatedBy: " ")
        guard parts.count >= 2 else {
            sendErrorResponse(to: clientConnection, statusCode: 400, message: "Bad Request")
            return
        }
        
        let path = parts[1]
        guard let urlComponents = URLComponents(string: "http://localhost\(path)"),
              let streamURLString = urlComponents.queryItems?.first(where: { $0.name == "url" })?.value,
              let streamURL = URL(string: streamURLString),
              let host = streamURL.host else {
            sendErrorResponse(to: clientConnection, statusCode: 400, message: "Invalid URL")
            return
        }
        
        let username = urlComponents.queryItems?.first(where: { $0.name == "user" })?.value
        let password = urlComponents.queryItems?.first(where: { $0.name == "pass" })?.value
        
        // Determine port and whether to use TLS
        // Note: Many IPTV CDNs redirect HTTP to HTTPS, so we try HTTPS first
        let isHTTPS = streamURL.scheme?.lowercased() == "https"
        let port: UInt16
        if let urlPort = streamURL.port {
            port = UInt16(urlPort)
        } else {
            port = isHTTPS ? 443 : 80
        }
        
        print("[StreamProxy] Proxying: \(host):\(port)\(streamURL.path) (TLS: \(isHTTPS))")
        
        // Only cache redirects for HLS live streams (not movies/series - their tokens are single-use)
        let isLiveHLS = streamURL.path.contains("/live/") && 
                        (streamURL.path.hasSuffix(".m3u8") || streamURL.path.hasSuffix(".m3u"))
        let cacheKey = streamURL.path
        
        if isLiveHLS, let cachedRedirect = getCachedRedirect(for: cacheKey),
           let cachedURL = URL(string: cachedRedirect),
           let cachedHost = cachedURL.host {
            // Use cached redirect - connect directly to CDN (only for HLS live)
            let cachedPort: UInt16 = UInt16(cachedURL.port ?? 80)
            print("[StreamProxy] Using cached redirect to: \(cachedHost):\(cachedPort)")
            
            connectToUpstreamDirect(
                host: cachedHost,
                port: cachedPort,
                streamURL: cachedURL,
                rangeHeader: requestHeaders["range"],
                clientConnection: clientConnection
            )
            return
        }
        
        // Create upstream connection with FORCED IPv4
        connectToUpstream(
            host: host,
            port: port,
            streamURL: streamURL,
            username: username,
            password: password,
            rangeHeader: requestHeaders["range"],
            originalPath: cacheKey,
            clientConnection: clientConnection
        )
    }
    
    /// Connect directly to a CDN server (for cached redirects)
    private func connectToUpstreamDirect(
        host: String,
        port: UInt16,
        streamURL: URL,
        rangeHeader: String?,
        clientConnection: NWConnection
    ) {
        // Simple direct connection - no redirect handling needed
        let tcpOptions = NWProtocolTCP.Options()
        tcpOptions.connectionTimeout = 30
        tcpOptions.noDelay = true
        
        let params = NWParameters(tls: nil, tcp: tcpOptions)
        params.prohibitExpensivePaths = false
        params.prohibitConstrainedPaths = false
        
        let hostEntry = NWEndpoint.Host(host)
        guard let portEntry = NWEndpoint.Port(rawValue: port) else {
            sendErrorResponse(to: clientConnection, statusCode: 502, message: "Invalid port")
            return
        }
        
        let endpoint = NWEndpoint.hostPort(host: hostEntry, port: portEntry)
        let connection = NWConnection(to: endpoint, using: params)
        let connId = ObjectIdentifier(connection)
        
        lock.lock()
        connections[connId] = connection
        lock.unlock()
        
        connection.stateUpdateHandler = { [weak self] state in
            guard let self = self else { return }
            switch state {
            case .ready:
                self.sendDirectRequest(
                    to: connection,
                    streamURL: streamURL,
                    host: host,
                    port: port,
                    rangeHeader: rangeHeader,
                    clientConnection: clientConnection
                )
            case .failed(let error):
                print("[StreamProxy] ✗ Direct connection failed: \(error.localizedDescription)")
                self.sendErrorResponse(to: clientConnection, statusCode: 502, message: "Connection failed")
                self.lock.lock()
                self.connections.removeValue(forKey: connId)
                self.lock.unlock()
            case .cancelled:
                self.lock.lock()
                self.connections.removeValue(forKey: connId)
                self.lock.unlock()
            default:
                break
            }
        }
        
        connection.start(queue: queue)
    }
    
    /// Send a direct request (no redirect handling)
    private func sendDirectRequest(
        to connection: NWConnection,
        streamURL: URL,
        host: String,
        port: UInt16,
        rangeHeader: String?,
        clientConnection: NWConnection
    ) {
        var path = streamURL.path
        if path.isEmpty { path = "/" }
        if let query = streamURL.query {
            path += "?\(query)"
        }
        
        // Check if this is an HLS playlist request
        let isHLSPlaylist = path.lowercased().contains(".m3u8") || path.lowercased().contains(".m3u")
        
        var httpRequest = "GET \(path) HTTP/1.1\r\n"
        httpRequest += "Host: \(host)\r\n"
        httpRequest += "User-Agent: VLC/3.0.20 LibVLC/3.0.20\r\n"
        httpRequest += "Accept: */*\r\n"
        httpRequest += "Icy-MetaData: 1\r\n"
        httpRequest += "Connection: close\r\n"
        
        if let range = rangeHeader {
            httpRequest += "Range: \(range)\r\n"
        }
        
        httpRequest += "\r\n"
        
        guard let requestData = httpRequest.data(using: .utf8) else {
            sendErrorResponse(to: clientConnection, statusCode: 500, message: "Internal Error")
            return
        }
        
        connection.send(content: requestData, completion: .contentProcessed { [weak self] error in
            if let error = error {
                print("[StreamProxy] ✗ Direct request failed: \(error.localizedDescription)")
                self?.sendErrorResponse(to: clientConnection, statusCode: 502, message: "Request failed")
                return
            }
            
            if isHLSPlaylist {
                // For HLS playlists, accumulate and rewrite URLs
                let baseURL = "http://\(host):\(port)"
                self?.receiveHLSResponse(
                    from: connection,
                    to: clientConnection,
                    baseURL: baseURL
                )
            } else {
                // Stream response directly (no redirect handling)
                self?.receiveAndForwardResponse(
                    from: connection,
                    to: clientConnection,
                    isFirstChunk: true,
                    rangeHeader: rangeHeader
                )
            }
        })
    }
    
    private func connectToUpstream(
        host: String,
        port: UInt16,
        streamURL: URL,
        username: String?,
        password: String?,
        rangeHeader: String?,
        originalPath: String,
        clientConnection: NWConnection
    ) {
        let isHTTPS = (port == 443) || (streamURL.scheme?.lowercased() == "https")
        
        if isHTTPS {
            // For HTTPS, don't bypass DNS - TLS needs proper hostname for certificate validation
            print("[StreamProxy] Using HTTPS - connecting directly to hostname for TLS")
            self.createConnection(
                to: host,
                originalHost: host,
                port: port,
                streamURL: streamURL,
                username: username,
                password: password,
                rangeHeader: rangeHeader,
                originalPath: originalPath,
                clientConnection: clientConnection
            )
        } else {
            // For HTTP, try to resolve the hostname to an IP address manually
            // This bypasses DNS HTTPS/SVCB records that cause automatic HTTPS upgrades
            resolveHostToIP(host: host) { [weak self] resolvedIP in
                guard let self = self else { return }
                
                let targetHost: String
                if let ip = resolvedIP {
                    print("[StreamProxy] Resolved \(host) -> \(ip)")
                    targetHost = ip
                } else {
                    print("[StreamProxy] DNS resolution failed, using hostname directly")
                    targetHost = host
                }
                
                self.createConnection(
                    to: targetHost,
                    originalHost: host,
                    port: port,
                    streamURL: streamURL,
                    username: username,
                    password: password,
                    rangeHeader: rangeHeader,
                    originalPath: originalPath,
                    clientConnection: clientConnection
                )
            }
        }
    }
    
    private func resolveHostToIP(host: String, completion: @escaping (String?) -> Void) {
        // Use CFHost for manual DNS resolution to get plain A/AAAA records
        // This bypasses HTTPS/SVCB DNS records
        queue.async {
            var hints = addrinfo()
            hints.ai_family = AF_INET  // Force IPv4
            hints.ai_socktype = SOCK_STREAM
            hints.ai_protocol = IPPROTO_TCP
            
            var result: UnsafeMutablePointer<addrinfo>?
            let status = getaddrinfo(host, nil, &hints, &result)
            
            defer { freeaddrinfo(result) }
            
            guard status == 0, let info = result else {
                print("[StreamProxy] DNS resolution failed: \(String(cString: gai_strerror(status)))")
                completion(nil)
                return
            }
            
            // Get the first IPv4 address
            if info.pointee.ai_family == AF_INET,
               let addr = info.pointee.ai_addr {
                var ipBuffer = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
                addr.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { sockaddr in
                    var inAddr = sockaddr.pointee.sin_addr
                    inet_ntop(AF_INET, &inAddr, &ipBuffer, socklen_t(INET_ADDRSTRLEN))
                }
                let ipString = String(cString: ipBuffer)
                completion(ipString)
            } else {
                completion(nil)
            }
        }
    }
    
    private func createConnection(
        to targetHost: String,
        originalHost: String,
        port: UInt16,
        streamURL: URL,
        username: String?,
        password: String?,
        rangeHeader: String?,
        originalPath: String,
        clientConnection: NWConnection
    ) {
        // Create TCP options
        let tcpOptions = NWProtocolTCP.Options()
        tcpOptions.connectionTimeout = 30
        tcpOptions.noDelay = true
        
        // Use TLS for port 443, plain TCP for port 80
        // Many IPTV CDNs redirect to HTTPS, so we need to handle both
        let useTLS = (port == 443)
        let params: NWParameters
        if useTLS {
            // Create TLS options with the original hostname for SNI
            let tlsOptions = NWProtocolTLS.Options()
            sec_protocol_options_set_tls_server_name(tlsOptions.securityProtocolOptions, originalHost)
            params = NWParameters(tls: tlsOptions, tcp: tcpOptions)
            print("[StreamProxy] Using TLS with SNI: \(originalHost)")
        } else {
            params = NWParameters(tls: nil, tcp: tcpOptions)
        }
        params.prohibitExpensivePaths = false
        params.prohibitConstrainedPaths = false
        
        // Create endpoint with explicit IP and port
        let hostEntry = NWEndpoint.Host(targetHost)
        guard let portEntry = NWEndpoint.Port(rawValue: port) else {
            print("[StreamProxy] ✗ Invalid port: \(port)")
            sendErrorResponse(to: clientConnection, statusCode: 500, message: "Invalid port")
            return
        }
        
        let endpoint = NWEndpoint.hostPort(host: hostEntry, port: portEntry)
        let upstreamConnection = NWConnection(to: endpoint, using: params)
        let connId = ObjectIdentifier(upstreamConnection)
        
        lock.lock()
        connections[connId] = upstreamConnection
        lock.unlock()
        
        print("[StreamProxy] Connecting to \(targetHost):\(port) (TCP)...")
        
        upstreamConnection.stateUpdateHandler = { [weak self] state in
            guard let self = self else { return }
            
            switch state {
            case .ready:
                let localDesc = upstreamConnection.currentPath?.localEndpoint?.debugDescription ?? "?"
                let remoteDesc = upstreamConnection.currentPath?.remoteEndpoint?.debugDescription ?? "?"
                print("[StreamProxy] ✓ Connected: \(localDesc) -> \(remoteDesc)")
                
                // Use ORIGINAL host in Host header (important for virtual hosts)
                self.sendHTTPRequest(
                    to: upstreamConnection,
                    streamURL: streamURL,
                    host: originalHost,
                    port: port,
                    username: username,
                    password: password,
                    rangeHeader: rangeHeader,
                    originalPath: originalPath,
                    clientConnection: clientConnection
                )
                
            case .waiting(let error):
                print("[StreamProxy] Waiting: \(error.localizedDescription)")
                
            case .failed(let error):
                print("[StreamProxy] ✗ Connection failed: \(error.localizedDescription)")
                self.sendErrorResponse(to: clientConnection, statusCode: 502, message: "Connection failed")
                self.lock.lock()
                self.connections.removeValue(forKey: connId)
                self.lock.unlock()
                
            case .cancelled:
                self.lock.lock()
                self.connections.removeValue(forKey: connId)
                self.lock.unlock()
                
            default:
                break
            }
        }
        
        upstreamConnection.start(queue: queue)
    }
    
    private func sendHTTPRequest(
        to upstreamConnection: NWConnection,
        streamURL: URL,
        host: String,
        port: UInt16,
        username: String?,
        password: String?,
        rangeHeader: String?,
        originalPath: String,
        clientConnection: NWConnection
    ) {
        var path = streamURL.path
        if path.isEmpty { path = "/" }
        if let query = streamURL.query {
            path += "?\(query)"
        }
        
        // Check if credentials are already in the URL path (Xtream format: /live/user/pass/...)
        let credentialsInPath = path.contains("/live/") || path.contains("/movie/") || path.contains("/series/")
        
        // Build Host header - always include port for non-standard ports
        var hostHeader = host
        if port != 80 && port != 443 {
            hostHeader = "\(host):\(port)"
        }
        
        // Build minimal HTTP/1.0 request - mimicking VLC exactly
        // HTTP/1.0 is more compatible with older IPTV servers
        // Too many headers can trigger CDN bot detection
        var httpRequest = "GET \(path) HTTP/1.0\r\n"
        httpRequest += "Host: \(hostHeader)\r\n"
        
        // VLC-compatible User-Agent - critical for IPTV servers
        httpRequest += "User-Agent: VLC/3.0.20 LibVLC/3.0.20\r\n"
        
        // Minimal headers that VLC sends
        httpRequest += "Accept: */*\r\n"
        httpRequest += "Accept-Language: en_US\r\n"
        
        // Icy-MetaData for IPTV streams (VLC always sends this)
        httpRequest += "Icy-MetaData: 1\r\n"
        
        // Connection header
        httpRequest += "Connection: close\r\n"
        
        // Only add Basic Auth if credentials NOT already in URL path
        if !credentialsInPath, let user = username, let pass = password {
            let authString = "\(user):\(pass)"
            if let authData = authString.data(using: .utf8) {
                let base64Auth = authData.base64EncodedString()
                httpRequest += "Authorization: Basic \(base64Auth)\r\n"
            }
        }
        
        // VLC always sends Range header for streaming
        if let range = rangeHeader {
            httpRequest += "Range: \(range)\r\n"
        } else {
            // Default Range header like VLC
            httpRequest += "Range: bytes=0-\r\n"
        }
        
        httpRequest += "\r\n"
        
        print("[StreamProxy] HTTP Request:\n\(httpRequest.replacingOccurrences(of: "\r\n", with: "\\r\\n "))")
        
        guard let requestData = httpRequest.data(using: .utf8) else {
            sendErrorResponse(to: clientConnection, statusCode: 500, message: "Internal Error")
            return
        }
        
        upstreamConnection.send(content: requestData, completion: .contentProcessed { [weak self] error in
            if let error = error {
                print("[StreamProxy] ✗ Failed to send request: \(error.localizedDescription)")
                self?.sendErrorResponse(to: clientConnection, statusCode: 502, message: "Bad Gateway")
                return
            }
            
            print("[StreamProxy] Request sent, waiting for response...")
            self?.receiveAndForwardResponse(
                from: upstreamConnection,
                to: clientConnection,
                isFirstChunk: true,
                rangeHeader: rangeHeader,
                originalPath: originalPath
            )
        })
    }
    
    private func receiveAndForwardResponse(
        from upstreamConnection: NWConnection,
        to clientConnection: NWConnection,
        isFirstChunk: Bool,
        originalHost: String? = nil,
        headerBuffer: Data = Data(),
        rangeHeader: String? = nil,
        originalPath: String? = nil
    ) {
        upstreamConnection.receive(minimumIncompleteLength: 1, maximumLength: 262144) { [weak self] data, _, isComplete, error in
            guard let self = self else { return }
            
            if let error = error {
                print("[StreamProxy] ✗ Upstream error: \(error.localizedDescription)")
                upstreamConnection.cancel()
                clientConnection.cancel()
                return
            }
            
            if let data = data, !data.isEmpty {
                var currentData = headerBuffer + data
                
                // Check for HTTP redirect on first chunk
                if isFirstChunk {
                    if let responseStr = String(data: currentData.prefix(1000), encoding: .utf8) {
                        print("[StreamProxy] Response (\(currentData.count) bytes):\n\(responseStr.prefix(500))")
                        
                        // Check for 302/301 redirect
                        if responseStr.contains("HTTP/1.1 302") || responseStr.contains("HTTP/1.1 301") ||
                           responseStr.contains("HTTP/1.0 302") || responseStr.contains("HTTP/1.0 301") {
                            // Extract Location header
                            if let locationRange = responseStr.range(of: "Location: "),
                               let endRange = responseStr.range(of: "\r\n", range: locationRange.upperBound..<responseStr.endIndex) {
                                let redirectURL = String(responseStr[locationRange.upperBound..<endRange.lowerBound])
                                print("[StreamProxy] 🔄 Following redirect to: \(redirectURL)")
                                
                                // Only cache redirects for HLS live streams (movie/series tokens are single-use)
                                if let path = originalPath,
                                   path.contains("/live/"),
                                   (path.hasSuffix(".m3u8") || path.hasSuffix(".m3u")) {
                                    self.cacheRedirect(for: path, redirectURL: redirectURL)
                                }
                                
                                // Close current connection and follow redirect
                                upstreamConnection.cancel()
                                
                                // Follow the redirect, passing along the Range header
                                self.followRedirect(
                                    to: redirectURL,
                                    clientConnection: clientConnection,
                                    rangeHeader: rangeHeader
                                )
                                return
                            }
                        }
                    }
                }
                
                // Forward data to client
                clientConnection.send(content: currentData, completion: .contentProcessed { [weak self] sendError in
                    if let sendError = sendError {
                        print("[StreamProxy] ✗ Client send error: \(sendError.localizedDescription)")
                        upstreamConnection.cancel()
                        clientConnection.cancel()
                        return
                    }
                    
                    if !isComplete {
                        self?.receiveAndForwardResponse(
                            from: upstreamConnection,
                            to: clientConnection,
                            isFirstChunk: false,
                            originalHost: originalHost,
                            rangeHeader: rangeHeader,
                            originalPath: originalPath
                        )
                    } else {
                        print("[StreamProxy] Stream complete")
                        upstreamConnection.cancel()
                        clientConnection.cancel()
                    }
                })
            } else if isComplete {
                print("[StreamProxy] Upstream closed connection")
                upstreamConnection.cancel()
                clientConnection.cancel()
            } else {
                self.receiveAndForwardResponse(
                    from: upstreamConnection,
                    to: clientConnection,
                    isFirstChunk: isFirstChunk,
                    originalHost: originalHost,
                    headerBuffer: headerBuffer,
                    rangeHeader: rangeHeader,
                    originalPath: originalPath
                )
            }
        }
    }
    
    private func followRedirect(to urlString: String, clientConnection: NWConnection, rangeHeader: String? = nil) {
        guard let url = URL(string: urlString),
              let host = url.host else {
            print("[StreamProxy] ✗ Invalid redirect URL: \(urlString)")
            sendErrorResponse(to: clientConnection, statusCode: 502, message: "Invalid redirect")
            return
        }
        
        let port: UInt16 = UInt16(url.port ?? 80)
        
        // Create connection to redirect target
        let tcpOptions = NWProtocolTCP.Options()
        tcpOptions.connectionTimeout = 30
        tcpOptions.noDelay = true
        
        let params = NWParameters(tls: nil, tcp: tcpOptions)
        params.prohibitExpensivePaths = false
        params.prohibitConstrainedPaths = false
        
        let hostEntry = NWEndpoint.Host(host)
        guard let portEntry = NWEndpoint.Port(rawValue: port) else {
            sendErrorResponse(to: clientConnection, statusCode: 502, message: "Invalid port")
            return
        }
        
        let endpoint = NWEndpoint.hostPort(host: hostEntry, port: portEntry)
        let redirectConnection = NWConnection(to: endpoint, using: params)
        let connId = ObjectIdentifier(redirectConnection)
        
        lock.lock()
        connections[connId] = redirectConnection
        lock.unlock()
        
        print("[StreamProxy] Connecting to redirect target: \(host):\(port)")
        
        redirectConnection.stateUpdateHandler = { [weak self] state in
            guard let self = self else { return }
            
            switch state {
            case .ready:
                print("[StreamProxy] ✓ Connected to redirect target")
                self.sendRedirectRequest(
                    to: redirectConnection,
                    url: url,
                    host: host,
                    clientConnection: clientConnection,
                    rangeHeader: rangeHeader
                )
                
            case .failed(let error):
                print("[StreamProxy] ✗ Redirect connection failed: \(error.localizedDescription)")
                self.sendErrorResponse(to: clientConnection, statusCode: 502, message: "Redirect failed")
                self.lock.lock()
                self.connections.removeValue(forKey: connId)
                self.lock.unlock()
                
            case .cancelled:
                self.lock.lock()
                self.connections.removeValue(forKey: connId)
                self.lock.unlock()
                
            default:
                break
            }
        }
        
        redirectConnection.start(queue: queue)
    }
    
    private func sendRedirectRequest(
        to connection: NWConnection,
        url: URL,
        host: String,
        clientConnection: NWConnection,
        rangeHeader: String? = nil
    ) {
        var path = url.path
        if path.isEmpty { path = "/" }
        if let query = url.query {
            path += "?\(query)"
        }
        
        // HTTP/1.1 request for the redirect target (1.1 for proper Range support)
        var httpRequest = "GET \(path) HTTP/1.1\r\n"
        httpRequest += "Host: \(host)\r\n"
        httpRequest += "User-Agent: VLC/3.0.20 LibVLC/3.0.20\r\n"
        httpRequest += "Accept: */*\r\n"
        httpRequest += "Icy-MetaData: 1\r\n"
        httpRequest += "Connection: close\r\n"
        
        // Forward Range header if present (important for seeking and partial requests)
        if let range = rangeHeader {
            httpRequest += "Range: \(range)\r\n"
            print("[StreamProxy] Forwarding Range header: \(range)")
        }
        
        httpRequest += "\r\n"
        
        print("[StreamProxy] Sending redirect request to \(host)")
        
        guard let requestData = httpRequest.data(using: .utf8) else {
            sendErrorResponse(to: clientConnection, statusCode: 500, message: "Internal Error")
            return
        }
        
        // Check if this is an HLS playlist that needs URL rewriting
        let isHLSPlaylist = path.lowercased().contains(".m3u8") || path.lowercased().contains(".m3u")
        
        connection.send(content: requestData, completion: .contentProcessed { [weak self] error in
            if let error = error {
                print("[StreamProxy] ✗ Failed to send redirect request: \(error.localizedDescription)")
                self?.sendErrorResponse(to: clientConnection, statusCode: 502, message: "Redirect request failed")
                return
            }
            
            if isHLSPlaylist {
                // For HLS playlists, accumulate and rewrite URLs
                let port = url.port ?? 80
                let baseURL = "http://\(host):\(port)"
                self?.receiveHLSResponse(
                    from: connection,
                    to: clientConnection,
                    baseURL: baseURL
                )
            } else {
                // For everything else (video files, segments), stream directly
                print("[StreamProxy] Streaming content directly (not HLS playlist)")
                self?.receiveAndForwardResponse(
                    from: connection,
                    to: clientConnection,
                    isFirstChunk: true,
                    rangeHeader: rangeHeader
                )
            }
        })
    }
    
    private func receiveHLSResponse(
        from upstreamConnection: NWConnection,
        to clientConnection: NWConnection,
        baseURL: String,
        accumulatedData: Data = Data()
    ) {
        upstreamConnection.receive(minimumIncompleteLength: 1, maximumLength: 262144) { [weak self] data, _, isComplete, error in
            guard let self = self else { return }
            
            if let error = error {
                print("[StreamProxy] ✗ HLS receive error: \(error.localizedDescription)")
                upstreamConnection.cancel()
                clientConnection.cancel()
                return
            }
            
            var currentData = accumulatedData
            if let data = data {
                currentData.append(data)
            }
            
            if isComplete {
                // All data received - check if it's an HLS playlist
                if let responseStr = String(data: currentData, encoding: .utf8) {
                    // Separate HTTP headers from body (split at \r\n\r\n)
                    if let headerEndRange = responseStr.range(of: "\r\n\r\n") {
                        let headers = String(responseStr[..<headerEndRange.lowerBound])
                        let body = String(responseStr[headerEndRange.upperBound...])
                        
                        // Check if body is an HLS playlist
                        if body.contains("#EXTM3U") || body.contains("#EXTINF") {
                            print("[StreamProxy] Rewriting HLS playlist URLs...")
                            let rewrittenBody = self.rewriteHLSPlaylist(body, baseURL: baseURL)
                            
                            // Rebuild response with updated Content-Length
                            var newHeaders = headers
                            // Remove old Content-Length and add new one
                            let headerLines = headers.components(separatedBy: "\r\n")
                            var filteredHeaders: [String] = []
                            for line in headerLines {
                                if !line.lowercased().hasPrefix("content-length:") {
                                    filteredHeaders.append(line)
                                }
                            }
                            newHeaders = filteredHeaders.joined(separator: "\r\n")
                            
                            // Build complete response
                            let bodyData = rewrittenBody.data(using: .utf8) ?? Data()
                            let fullResponse = "\(newHeaders)\r\nContent-Length: \(bodyData.count)\r\n\r\n"
                            
                            var responseData = fullResponse.data(using: .utf8) ?? Data()
                            responseData.append(bodyData)
                            
                            clientConnection.send(content: responseData, completion: .contentProcessed { _ in
                                print("[StreamProxy] HLS playlist sent (\(bodyData.count) bytes)")
                                upstreamConnection.cancel()
                                clientConnection.cancel()
                            })
                            return
                        }
                    }
                }
                
                // Not an HLS playlist or no header separator, forward as-is
                clientConnection.send(content: currentData, completion: .contentProcessed { _ in
                    print("[StreamProxy] Response forwarded")
                    upstreamConnection.cancel()
                    clientConnection.cancel()
                })
            } else {
                // Keep accumulating data
                self.receiveHLSResponse(
                    from: upstreamConnection,
                    to: clientConnection,
                    baseURL: baseURL,
                    accumulatedData: currentData
                )
            }
        }
    }
    
    private func rewriteHLSPlaylist(_ playlist: String, baseURL: String) -> String {
        // Split into lines
        let lines = playlist.components(separatedBy: "\n")
        var rewrittenLines: [String] = []
        
        // Use fixed proxy port (we start on 9080)
        let proxyPort: UInt16 = 9080
        var rewriteCount = 0
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Skip empty lines and comments (but keep them)
            if trimmedLine.isEmpty || trimmedLine.hasPrefix("#") {
                rewrittenLines.append(line)
                continue
            }
            
            // This is a URL line - rewrite it
            var absoluteURL: String
            
            if trimmedLine.hasPrefix("http://") || trimmedLine.hasPrefix("https://") {
                // Already absolute URL
                absoluteURL = trimmedLine
            } else if trimmedLine.hasPrefix("/") {
                // Root-relative URL
                absoluteURL = baseURL + trimmedLine
            } else {
                // Relative URL - append to base
                absoluteURL = baseURL + "/" + trimmedLine
            }
            
            // Wrap through our proxy
            if let encodedURL = absoluteURL.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
                let proxyURL = "http://127.0.0.1:\(proxyPort)/stream?url=\(encodedURL)"
                rewrittenLines.append(proxyURL)
                rewriteCount += 1
            } else {
                rewrittenLines.append(line)
            }
        }
        
        print("[StreamProxy] Rewrote \(rewriteCount) URLs in HLS playlist")
        return rewrittenLines.joined(separator: "\n")
    }
    
    private func sendErrorResponse(to connection: NWConnection, statusCode: Int, message: String) {
        let body = "<html><body><h1>\(statusCode) \(message)</h1></body></html>"
        let response = """
        HTTP/1.1 \(statusCode) \(message)\r
        Content-Type: text/html\r
        Content-Length: \(body.utf8.count)\r
        Connection: close\r
        \r
        \(body)
        """
        
        if let data = response.data(using: .utf8) {
            connection.send(content: data, completion: .contentProcessed { _ in
                connection.cancel()
            })
        } else {
            connection.cancel()
        }
    }
}

enum ProxyError: LocalizedError {
    case failedToStart
    case invalidURL
    case connectionFailed
    
    var errorDescription: String? {
        switch self {
        case .failedToStart:
            return "Failed to start proxy server"
        case .invalidURL:
            return "Invalid stream URL"
        case .connectionFailed:
            return "Connection to stream failed"
        }
    }
}
