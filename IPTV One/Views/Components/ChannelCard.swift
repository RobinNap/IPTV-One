//
//  ChannelCard.swift
//  IPTV One
//
//  Created by Robin Nap on 21/01/2026.
//

import SwiftUI

struct ChannelCard: View {
    let channel: Channel
    var currentProgram: EPGProgramData?
    var onTap: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                // Logo area
                ZStack {
                    Color.darkCardBackground
                    
                    if let logoURL = channel.logoURL, let url = URL(string: logoURL) {
                        CachedAsyncImage(url: url) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .padding(16)
                        } placeholder: {
                            channelInitials
                        }
                    } else {
                        channelInitials
                    }
                }
                .frame(height: 100)
                .overlay(alignment: .topTrailing) {
                    if channel.isFavorite {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(.red)
                            .padding(8)
                    }
                }
                
                // Info area
                VStack(alignment: .leading, spacing: 4) {
                    Text(channel.name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    
                    if let program = currentProgram {
                        EPGInfoBar(program: program)
                    } else {
                        Text(channel.categoryName)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.darkCardBackground.opacity(0.8))
            }
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(
                        isHovered ? Color.primaryAccent : Color.white.opacity(0.08),
                        lineWidth: isHovered ? 2 : 1
                    )
            }
            .scaleEffect(isHovered ? 1.02 : 1.0)
            .shadow(color: isHovered ? Color.primaryAccent.opacity(0.3) : .clear, radius: 12)
            .animation(.smoothSpring, value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
    
    private var channelInitials: some View {
        Text(String(channel.name.prefix(2)).uppercased())
            .font(.system(size: 28, weight: .bold, design: .rounded))
            .foregroundStyle(
                LinearGradient.accentGradient
            )
    }
}

struct EPGInfoBar: View {
    let program: EPGProgramData
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Circle()
                    .fill(Color.red)
                    .frame(width: 6, height: 6)
                
                Text("LIVE")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.red)
            }
            
            Text(program.title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.9))
                .lineLimit(1)
            
            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.white.opacity(0.2))
                    
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.primaryAccent)
                        .frame(width: geo.size.width * progress)
                }
            }
            .frame(height: 3)
        }
    }
    
    private var progress: CGFloat {
        let now = Date()
        guard program.startTime <= now && program.endTime > now else { return 0 }
        let total = program.endTime.timeIntervalSince(program.startTime)
        let elapsed = now.timeIntervalSince(program.startTime)
        return CGFloat(elapsed / total)
    }
}

#Preview {
    ZStack {
        Color.darkBackground.ignoresSafeArea()
        
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 160))], spacing: 16) {
            ChannelCard(
                channel: Channel(
                    name: "CNN International",
                    streamURL: "http://example.com",
                    logoURL: nil,
                    categoryName: "News"
                ),
                currentProgram: EPGProgramData(
                    channelID: "1",
                    title: "Breaking News Tonight",
                    startTime: Date().addingTimeInterval(-1800),
                    endTime: Date().addingTimeInterval(1800)
                )
            ) {}
            
            ChannelCard(
                channel: Channel(
                    name: "ESPN",
                    streamURL: "http://example.com",
                    categoryName: "Sports",
                    isFavorite: true
                )
            ) {}
        }
        .padding()
    }
}
