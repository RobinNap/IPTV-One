//
//  FavoriteButton.swift
//  IPTV One
//
//  Created by Robin Nap on 21/01/2026.
//

import SwiftUI

struct FavoriteButton: View {
    @Binding var isFavorite: Bool
    var size: CGFloat = 20
    
    @State private var isAnimating = false
    
    var body: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                isFavorite.toggle()
                isAnimating = true
            }
            
            // Reset animation state
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                isAnimating = false
            }
        } label: {
            Image(systemName: isFavorite ? "heart.fill" : "heart")
                .font(.system(size: size))
                .foregroundStyle(isFavorite ? .red : .white.opacity(0.7))
                .scaleEffect(isAnimating ? 1.3 : 1.0)
                .shadow(color: isFavorite ? .red.opacity(0.5) : .clear, radius: 4)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ZStack {
        Color.darkBackground.ignoresSafeArea()
        HStack(spacing: 32) {
            FavoriteButton(isFavorite: .constant(false))
            FavoriteButton(isFavorite: .constant(true))
        }
    }
}
