//
//  GlassCard.swift
//  IPTV One
//
//  Created by Robin Nap on 21/01/2026.
//

import SwiftUI

struct GlassCard<Content: View>: View {
    @ViewBuilder var content: () -> Content
    
    var body: some View {
        content()
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .background {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.darkCardBackground.opacity(0.8))
                    }
            }
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [.white.opacity(0.2), .white.opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

#Preview {
    ZStack {
        LinearGradient(
            colors: [.purple, .blue],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
        
        GlassCard {
            VStack(spacing: 12) {
                Image(systemName: "play.tv")
                    .font(.system(size: 32))
                Text("IPTV One")
                    .font(.title2.bold())
            }
            .foregroundStyle(.white)
            .padding(32)
        }
    }
}
