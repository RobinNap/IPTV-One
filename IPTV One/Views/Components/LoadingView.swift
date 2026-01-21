//
//  LoadingView.swift
//  IPTV One
//
//  Created by Robin Nap on 21/01/2026.
//

import SwiftUI

struct LoadingView: View {
    var message: String = "Loading..."
    
    @State private var isAnimating = false
    
    var body: some View {
        VStack(spacing: 24) {
            // Animated loader
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.1), lineWidth: 4)
                    .frame(width: 50, height: 50)
                
                Circle()
                    .trim(from: 0, to: 0.7)
                    .stroke(
                        LinearGradient.accentGradient,
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .frame(width: 50, height: 50)
                    .rotationEffect(.degrees(isAnimating ? 360 : 0))
                    .animation(
                        .linear(duration: 1)
                        .repeatForever(autoreverses: false),
                        value: isAnimating
                    )
            }
            
            Text(message)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.darkBackground)
        .onAppear {
            isAnimating = true
        }
    }
}

struct EmptyStateView: View {
    var icon: String = "tray"
    var title: String
    var message: String
    var actionTitle: String?
    var action: (() -> Void)?
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            
            Text(title)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white)
            
            Text(message)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            if let actionTitle, let action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(
                            LinearGradient.accentGradient
                        )
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.darkBackground)
    }
}

#Preview("Loading") {
    LoadingView(message: "Loading channels...")
}

#Preview("Empty State") {
    EmptyStateView(
        icon: "antenna.radiowaves.left.and.right",
        title: "No Channels",
        message: "Add a source to start watching live TV",
        actionTitle: "Add Source"
    ) {}
}
