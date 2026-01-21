//
//  CategoryPicker.swift
//  IPTV One
//
//  Created by Robin Nap on 21/01/2026.
//

import SwiftUI

struct CategoryPicker: View {
    let categories: [String]
    @Binding var selectedCategory: String?
    var showAllOption: Bool = true
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                if showAllOption {
                    CategoryChip(
                        title: "All",
                        isSelected: selectedCategory == nil
                    ) {
                        withAnimation(.smoothSpring) {
                            selectedCategory = nil
                        }
                    }
                }
                
                ForEach(categories, id: \.self) { category in
                    CategoryChip(
                        title: category,
                        isSelected: selectedCategory == category
                    ) {
                        withAnimation(.smoothSpring) {
                            selectedCategory = category
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }
}

struct CategoryChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(isSelected ? .white : .secondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background {
                    Capsule()
                        .fill(isSelected ? Color.primaryAccent : Color.darkCardBackground)
                }
                .overlay {
                    Capsule()
                        .strokeBorder(isSelected ? Color.clear : Color.white.opacity(0.1), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ZStack {
        Color.darkBackground.ignoresSafeArea()
        VStack {
            CategoryPicker(
                categories: ["Sports", "Movies", "News", "Entertainment", "Music", "Kids"],
                selectedCategory: .constant("Sports")
            )
        }
    }
}
