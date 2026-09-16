//
//  ForYouView.swift
//  Pari
//
//  Personalised discovery: wines to try next, ranked by taste affinity and what the
//  user's taste twins scored. Backed by the recommend_wines RPC.
//

import SwiftUI

@MainActor
@Observable
final class ForYouViewModel {
    var recommendations: [WineRecommendation] = []
    /// Shown when the recommender has nothing to say yet. A person with a name beats
    /// a worse algorithm.
    var collections: [CuratedCollection] = []
    var openTonight: [CellarBottle] = []
    var isLoading = false
    /// True once a load has finished, so an empty list can be distinguished from "not loaded yet".
    var hasLoaded = false

    func load() async {
        isLoading = true
        async let recs = RecommendationService.fetchRecommendations()
        async let cols = CuratedCollectionService.collections(limit: 5)
        async let cellar = CellarBottleService.openTonight(limit: 3)
        recommendations = await recs
        collections = await cols
        openTonight = await cellar
        isLoading = false
        hasLoaded = true
    }
}

struct ForYouView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var viewModel = ForYouViewModel()
    @State private var showListScan = false
    @State private var showTable = false
    let currentUserId: UUID?

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.recommendations.isEmpty {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(PariTheme.accent(for: colorScheme))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.hasLoaded && viewModel.recommendations.isEmpty
                        && viewModel.collections.isEmpty && viewModel.openTonight.isEmpty {
                emptyState
            } else {
                list
            }
        }
        .task {
            if !viewModel.hasLoaded { await viewModel.load() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .pariTastingCreated)) { _ in
            // A new tasting moves the taste vector, so the ranking is now stale.
            Task { await viewModel.load() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .pariCellarInventoryChanged)) { _ in
            Task { await viewModel.load() }
        }
        .fullScreenCover(isPresented: $showListScan) {
            WineListScanView(isPresented: $showListScan, currentUserId: currentUserId)
        }
        .fullScreenCover(isPresented: $showTable) {
            TastingSessionView(isPresented: $showTable, currentUserId: currentUserId)
        }
    }

    /// Discovery is where someone goes when they have to choose. The two hardest
    /// versions of that are a restaurant list and a table of people who do not
    /// agree, so both live here.
    private var listScanButton: some View {
        HStack(alignment: .top, spacing: 20) {
            serviceLink("Wine list", detail: "Read the menu") { showListScan = true }
            Rectangle().fill(PariTheme.divider(for: colorScheme)).frame(width: 1)
            serviceLink("The table", detail: "Choose together") { showTable = true }
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(.vertical, 18)
        .overlay(alignment: .top) { PariRule() }
        .overlay(alignment: .bottom) { PariRule() }
        .padding(.horizontal, 24)
    }

    private func serviceLink(_ title: String, detail: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 7) {
                HStack {
                    Text(title).font(.subheadline.weight(.medium))
                    Spacer(minLength: 4)
                    Image(systemName: "arrow.up.right").font(.system(size: 12))
                }
                .foregroundStyle(PariTheme.accent(for: colorScheme))
                Text(detail).font(.caption).foregroundStyle(PariTheme.textSecondary(for: colorScheme))
            }
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var list: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 0) {
                header
                listScanButton
                    .padding(.bottom, 16)

                // Bottles you already own come before bottles you might buy. A wine
                // closing its window is a decision with a deadline.
                if !viewModel.openTonight.isEmpty {
                    sectionHeading("From your cellar")
                    ForEach(viewModel.openTonight) { bottle in
                        cellarRow(bottle)
                        Divider().padding(.leading, 24)
                    }
                }

                if !viewModel.collections.isEmpty {
                    sectionHeading("Chosen by people")
                    ForEach(viewModel.collections) { collection in
                        collectionRow(collection)
                        Divider().padding(.leading, 24)
                    }
                }

                if !viewModel.recommendations.isEmpty {
                    sectionHeading("Matched to your palate")
                }
                ForEach(Array(viewModel.recommendations.enumerated()), id: \.element.id) { index, rec in
                    NavigationLink {
                        WineCardView(wine: rec.wine, activityId: nil, currentUserId: currentUserId)
                    } label: {
                        row(rec, position: index + 1)
                    }
                    .buttonStyle(.plain)
                    Divider()
                        .padding(.leading, 24)
                }
            }
            .padding(.bottom, 24)
        }
        .refreshable { await viewModel.load() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("For your next bottle.")
                .font(PariTheme.editorialFont(size: 34))
                .foregroundStyle(PariTheme.textPrimary(for: colorScheme))
                .fixedSize(horizontal: false, vertical: true)
            Text("From the wines you remember.")
                .font(.subheadline)
                .foregroundStyle(PariTheme.textSecondary(for: colorScheme))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .padding(.vertical, 28)
    }

    private func sectionHeading(_ text: String) -> some View {
        Text(text)
            .font(PariTheme.uiFont(size: 12, weight: .semibold))
            .foregroundStyle(PariTheme.textTertiary(for: colorScheme))
            .textCase(.uppercase)
            .kerning(0.6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 8)
    }

    private func cellarRow(_ bottle: CellarBottle) -> some View {
        HStack(spacing: 14) {
            wineThumbnail(bottle.wine)
            VStack(alignment: .leading, spacing: 3) {
                Text(bottle.wine.producer)
                    .font(.caption)
                    .foregroundStyle(PariTheme.textTertiary(for: colorScheme))
                    .lineLimit(1)
                Text(bottle.vintage.map { "\($0) \(bottle.wine.name)" } ?? bottle.wine.name)
                    .font(PariTheme.wineNameFont(for: colorScheme))
                    .foregroundStyle(PariTheme.textPrimary(for: colorScheme))
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                HStack(spacing: 6) {
                    Text(bottle.urgency.label)
                        .font(PariTheme.uiFont(size: 11, weight: .medium))
                        .foregroundStyle(bottle.urgency == .past || bottle.urgency == .drinkNow
                                         ? PariTheme.accent(for: colorScheme)
                                         : PariTheme.textTertiary(for: colorScheme))
                    if bottle.quantity > 1 {
                        Text("· \(bottle.quantity) bottles")
                            .font(PariTheme.uiFont(size: 11))
                            .foregroundStyle(PariTheme.textTertiary(for: colorScheme))
                    }
                }
                .padding(.top, 2)
            }
            Spacer(minLength: 8)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
    }

    private func collectionRow(_ collection: CuratedCollection) -> some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text(collection.title)
                    .font(PariTheme.wineNameFont(for: colorScheme))
                    .foregroundStyle(PariTheme.textPrimary(for: colorScheme))
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                if let subtitle = collection.subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(PariTheme.textSecondary(for: colorScheme))
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                }
                // The signature is the whole point of this section.
                Text(collection.attribution)
                    .font(PariTheme.uiFont(size: 11))
                    .foregroundStyle(PariTheme.accent(for: colorScheme))
                    .padding(.top, 2)
            }
            Spacer(minLength: 8)
            Text("\(collection.wineCount)")
                .font(.system(.body, design: .serif))
                .foregroundStyle(PariTheme.textTertiary(for: colorScheme))
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
    }

    private func row(_ rec: WineRecommendation, position: Int) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Text(String(format: "%02d", position))
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(PariTheme.textSecondary(for: colorScheme))
                .frame(width: 25, alignment: .leading)
                .padding(.top, 4)

            VStack(alignment: .leading, spacing: 3) {
                Text(rec.wine.producer)
                    .font(.caption)
                    .foregroundStyle(PariTheme.textTertiary(for: colorScheme))
                    .lineLimit(1)

                Text(rec.wine.name)
                    .font(PariTheme.wineNameFont(for: colorScheme))
                    .foregroundStyle(PariTheme.textPrimary(for: colorScheme))
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                    .multilineTextAlignment(.leading)

                if let region = rec.wine.region {
                    Text(region)
                        .font(.caption)
                        .foregroundStyle(PariTheme.textSecondary(for: colorScheme))
                        .lineLimit(1)
                }

                if let explanation = rec.explanation {
                    Text(explanation)
                        .font(.caption)
                        .foregroundStyle(PariTheme.accent(for: colorScheme))
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 5)
                }
            }

            Spacer(minLength: 8)

            if let rating = rec.headlineRating {
                VStack(spacing: 1) {
                    Text(String(format: "%.1f", rating))
                        .font(.system(.body, design: .serif, weight: .medium))
                        .foregroundStyle(PariTheme.ratingColorAdaptive(rating: rating, for: colorScheme))
                    Text(rec.reason == .twins ? "twins" : "avg")
                        .font(PariTheme.uiFont(size: 10))
                        .foregroundStyle(PariTheme.textTertiary(for: colorScheme))
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private func wineThumbnail(_ wine: Wine) -> some View {
        let tint = WineColorResolver.resolveWineDisplayColor(wine: wine)
        return Group {
            if let urlString = wine.labelImageURL, let url = URL(string: urlString) {
                CachedAsyncImage(url: url) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    glassPlaceholder(tint)
                }
            } else {
                glassPlaceholder(tint)
            }
        }
        .frame(width: 48, height: 64)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func glassPlaceholder(_ tint: Color) -> some View {
        ZStack {
            PariTheme.backgroundSecondary(for: colorScheme)
            Image(systemName: "wineglass.fill")
                .font(.system(size: 22, weight: .light))
                .foregroundStyle(tint.opacity(0.55))
        }
    }

    private var emptyState: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                PariEmptyNote(title: "A palate takes shape.", message: "Record a few wines to start finding bottles through your own taste.")
                    .padding(.horizontal, 24)
                listScanButton
            }
        }
    }
}
