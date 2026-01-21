//
//  IPTV_OneTests.swift
//  IPTV OneTests
//
//  Created by Robin Nap on 21/01/2026.
//

import Testing
@testable import IPTV_One

struct IPTV_OneTests {
    
    @Test func testM3UParsing() async throws {
        let sampleM3U = """
        #EXTM3U url-tvg="http://example.com/epg.xml"
        #EXTINF:-1 tvg-id="cnn.us" tvg-name="CNN" tvg-logo="http://example.com/cnn.png" group-title="News",CNN International
        http://example.com/cnn/stream.m3u8
        #EXTINF:-1 tvg-id="espn.us" tvg-name="ESPN" tvg-logo="http://example.com/espn.png" group-title="Sports",ESPN HD
        http://example.com/espn/stream.m3u8
        #EXTINF:-1 tvg-logo="http://example.com/movie.jpg" group-title="VOD Movies",The Matrix (1999)
        http://example.com/vod/matrix.mp4
        """
        
        let parser = M3UParser.shared
        let result = try await parser.parseContent(sampleM3U)
        
        #expect(result.epgURL == "http://example.com/epg.xml")
        #expect(result.items.count == 3)
        
        let cnn = result.items[0]
        #expect(cnn.name == "CNN International")
        #expect(cnn.groupTitle == "News")
        #expect(cnn.tvgID == "cnn.us")
        #expect(cnn.contentType == .live)
        
        let movie = result.items[2]
        #expect(movie.groupTitle == "VOD Movies")
        #expect(movie.contentType == .movie)
    }
    
    @Test func testSeriesNameExtraction() {
        let name1 = "Breaking Bad S01E02 - Cat's in the Bag"
        let result1 = name1.extractSeriesInfo()
        
        #expect(result1?.seriesName == "Breaking Bad")
        #expect(result1?.season == 1)
        #expect(result1?.episode == 2)
        
        let name2 = "Game of Thrones Season 3 Episode 9"
        let result2 = name2.extractSeriesInfo()
        
        #expect(result2?.seriesName == "Game of Thrones")
        #expect(result2?.season == 3)
        #expect(result2?.episode == 9)
    }
    
    @Test func testDateFormatting() {
        let date = Date()
        let timeString = date.timeString()
        
        #expect(!timeString.isEmpty)
        #expect(timeString.contains(":"))
    }
}
