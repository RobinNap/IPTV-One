//
//  EPGBar.swift
//  IPTV One
//
//  Created by Robin Nap on 21/01/2026.
//

import SwiftUI

struct EPGBar: View {
    let currentProgram: EPGProgramData?
    let nextProgram: EPGProgramData?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let current = currentProgram {
                // Now playing
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 8, height: 8)
                        
                        Text("NOW")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.red)
                        
                        Spacer()
                        
                        Text("\(current.startTime.timeString()) - \(current.endTime.timeString())")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    
                    Text(current.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    
                    // Progress
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.white.opacity(0.2))
                            
                            RoundedRectangle(cornerRadius: 2)
                                .fill(LinearGradient.accentGradient)
                                .frame(width: geo.size.width * progress(for: current))
                        }
                    }
                    .frame(height: 4)
                }
                
                // Up next
                if let next = nextProgram {
                    Divider()
                        .background(Color.white.opacity(0.1))
                    
                    HStack(spacing: 8) {
                        Text("NEXT")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.secondary)
                        
                        Text(next.title)
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.8))
                            .lineLimit(1)
                        
                        Spacer()
                        
                        Text(next.startTime.timeString())
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                Text("No program information available")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(Color.darkCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
    
    private func progress(for program: EPGProgramData) -> Double {
        let now = Date()
        guard program.startTime <= now && program.endTime > now else { return 0 }
        let total = program.endTime.timeIntervalSince(program.startTime)
        let elapsed = now.timeIntervalSince(program.startTime)
        return elapsed / total
    }
}

#Preview {
    ZStack {
        Color.darkBackground.ignoresSafeArea()
        
        EPGBar(
            currentProgram: EPGProgramData(
                channelID: "1",
                title: "Breaking News Tonight with Anderson Cooper",
                startTime: Date().addingTimeInterval(-1800),
                endTime: Date().addingTimeInterval(1800)
            ),
            nextProgram: EPGProgramData(
                channelID: "1",
                title: "The Late Show",
                startTime: Date().addingTimeInterval(1800),
                endTime: Date().addingTimeInterval(5400)
            )
        )
        .padding()
    }
}
