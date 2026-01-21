//
//  Extensions.swift
//  IPTV One
//
//  Created by Robin Nap on 21/01/2026.
//

import SwiftUI

// MARK: - Color Extensions

extension Color {
    static let background = Color("Background")
    static let cardBackground = Color("CardBackground")
    static let accentGradientStart = Color("AccentGradientStart")
    static let accentGradientEnd = Color("AccentGradientEnd")
    
    // Fallback colors
    static let darkBackground = Color(red: 0.07, green: 0.07, blue: 0.09)
    static let darkCardBackground = Color(red: 0.12, green: 0.12, blue: 0.14)
    static let primaryAccent = Color(red: 0.98, green: 0.24, blue: 0.24)
    static let secondaryAccent = Color(red: 1.0, green: 0.45, blue: 0.25)
}

// MARK: - View Extensions

extension View {
    func cardStyle() -> some View {
        self
            .background(Color.darkCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
    
    func glowEffect(color: Color = .primaryAccent, radius: CGFloat = 10) -> some View {
        self.shadow(color: color.opacity(0.5), radius: radius, x: 0, y: 0)
    }
    
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

// MARK: - String Extensions

extension String {
    func extractSeriesInfo() -> (seriesName: String, season: Int?, episode: Int?)? {
        // Pattern: "Series Name S01E02" or "Series Name - S01 E02"
        let patterns = [
            #"(.+?)\s*[Ss](\d+)\s*[Ee](\d+)"#,
            #"(.+?)\s*-\s*[Ss](\d+)\s*[Ee](\d+)"#,
            #"(.+?)\s*Season\s*(\d+)\s*Episode\s*(\d+)"#
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []),
               let match = regex.firstMatch(in: self, options: [], range: NSRange(location: 0, length: utf16.count)),
               match.numberOfRanges >= 4 {
                
                let nsString = self as NSString
                let seriesName = nsString.substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespaces)
                let season = Int(nsString.substring(with: match.range(at: 2)))
                let episode = Int(nsString.substring(with: match.range(at: 3)))
                
                return (seriesName, season, episode)
            }
        }
        
        return nil
    }
}

// MARK: - Date Extensions

extension Date {
    func formatted(as format: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = format
        return formatter.string(from: self)
    }
    
    func timeString() -> String {
        formatted(as: "HH:mm")
    }
    
    func relativeTimeString() -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}

// MARK: - Animation Extensions

extension Animation {
    static let smoothSpring = Animation.spring(response: 0.35, dampingFraction: 0.8)
    static let quickSpring = Animation.spring(response: 0.25, dampingFraction: 0.7)
}

// MARK: - Gradient Extensions

extension LinearGradient {
    static let accentGradient = LinearGradient(
        colors: [.primaryAccent, .secondaryAccent],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let fadeToBlack = LinearGradient(
        colors: [.clear, .black.opacity(0.8)],
        startPoint: .top,
        endPoint: .bottom
    )
    
    static let cardOverlay = LinearGradient(
        colors: [.clear, .black.opacity(0.6)],
        startPoint: .center,
        endPoint: .bottom
    )
}
