//
//  BackgroundLoadingBanner.swift
//  IPTV One
//
//  Created by Robin Nap on 21/01/2026.
//

import SwiftUI

/// A subtle banner that shows when content is loading in the background
/// Allows users to continue browsing while more content loads
struct BackgroundLoadingBanner: View {
    let message: String
    
    var body: some View {
        HStack(spacing: 10) {
            ProgressView()
                .scaleEffect(0.8)
                .tint(.white)
            
            Text(message.isEmpty ? "Loading..." : message)
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.9))
            
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.primaryAccent.opacity(0.85))
        }
        .padding(.horizontal, 16)
    }
}

#Preview {
    VStack {
        BackgroundLoadingBanner(message: "Loading movies...")
        BackgroundLoadingBanner(message: "")
    }
    .padding()
    .background(Color.darkBackground)
}
