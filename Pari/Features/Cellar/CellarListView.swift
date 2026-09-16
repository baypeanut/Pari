//
//  CellarListView.swift
//  Pari
//
//  Reusable cellar list component with category tabs and tasting rows
//

import SwiftUI

struct CellarListView: View {
    @Environment(\.colorScheme) private var colorScheme
    let groupedTastings: [(category: String, tastings: [Tasting])]
    let currentUserId: UUID?
    let allowSwipeToDelete: Bool
    var onDelete: ((Tasting) async -> Void)?
    
    @State private var selectedCategory: String = ""
    
    var body: some View {
        VStack(spacing: 0) {
            if groupedTastings.count > 1 {
                categoryTabs
                Rectangle().fill(PariTheme.divider(for: colorScheme)).frame(height: 1)
            }
            categoryContent
        }
        .onAppear {
            updateSelectedCategory()
        }
        .onChange(of: groupedTastings.count) { _, _ in
            updateSelectedCategory()
        }
    }
    
    private var categoryTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(groupedTastings, id: \.category) { group in
                    Button {
                        selectedCategory = group.category
                    } label: {
                        Text(group.category)
                            .font(PariTheme.uiFont(size: 15, weight: selectedCategory == group.category ? .semibold : .regular))
                            .foregroundStyle(selectedCategory == group.category ? PariTheme.accentWine(for: colorScheme) : (colorScheme == .dark ? PariTheme.textTertiary(for: colorScheme) : PariTheme.textSecondary(for: colorScheme)))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
        }
    }
    
    @ViewBuilder
    private var categoryContent: some View {
        if let currentGroup = groupedTastings.first(where: { $0.category == selectedCategory }) {
            List {
                ForEach(currentGroup.tastings) { tasting in
                    tastingRow(tasting)
                        .listRowInsets(EdgeInsets(top: 0, leading: 24, bottom: 0, trailing: 24))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .listRowSpacing(0)
                        .if(allowSwipeToDelete && onDelete != nil) { view in
                            view.swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    Task { await onDelete?(tasting) }
                                } label: {
                                    Label("Remove", systemImage: "trash")
                                }
                            }
                        }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(PariTheme.backgroundPrimary(for: colorScheme))
        } else {
            Text("No wines in this category.")
                .font(PariTheme.uiFont(size: 15))
                .foregroundStyle(PariTheme.textSecondary(for: colorScheme))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
    
    private func tastingRow(_ tasting: Tasting) -> some View {
        ZStack {
            NavigationLink(destination: WineCardView(wine: tasting.wine, activityId: nil, currentUserId: currentUserId)) {
                EmptyView()
            }
            .opacity(0)

            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 7) {
                    Text(tasting.wine.producer).font(.caption)
                        .foregroundStyle(PariTheme.textSecondary(for: colorScheme))
                    Text(tasting.wine.name).font(PariTheme.wineNameFont(for: colorScheme))
                        .foregroundStyle(PariTheme.textPrimary(for: colorScheme))
                        .fixedSize(horizontal: false, vertical: true)
                    if let comment = tasting.comment, !comment.isEmpty {
                        Text(comment).font(.subheadline).lineLimit(2)
                            .foregroundStyle(PariTheme.textSecondary(for: colorScheme))
                    }
                    HStack(spacing: 8) {
                        if let vintage = tasting.displayVintage { Text("Vintage \(String(vintage))") }
                        Text(PariTheme.compactTimestamp(tasting.createdAt))
                    }
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(PariTheme.textSecondary(for: colorScheme))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                PariScore(value: tasting.rating)
            }
            .padding(.vertical, 22)
            .overlay(alignment: .bottom) { PariRule() }
        }
    }

    private func updateSelectedCategory() {
        if selectedCategory.isEmpty || !groupedTastings.contains(where: { $0.category == selectedCategory }) {
            selectedCategory = groupedTastings.first?.category ?? ""
        }
    }
}

// Helper extension for conditional view modifiers
extension View {
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}
