//
//  ProfileContentView.swift
//  Pari
//
//  Personal wine journal: identity, taste notes and a dated tasting ledger.
//

import SwiftUI

struct ProfileContentView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    var viewModel: ProfileViewModel
    var isOwn: Bool
    var isFollowing: Bool
    var isTogglingFollow: Bool = false
    var followError: String?
    var tasteSimilarity: TasteSimilarity?
    var tasteTwins: [TasteTwin] = []
    var onEdit: (() -> Void)?
    var onFollowToggle: (() -> Void)?
    var onSignOut: (() -> Void)?
    var onDismiss: (() -> Void)?
    var onActivityTap: ((FeedItem) -> Void)?
    var onFollowChanged: (() -> Void)?
    var onFollowersTap: (() -> Void)?
    var onFollowingTap: (() -> Void)?
    var onRegionTap: ((String) -> Void)?
    var onGrapeTap: ((String) -> Void)?
    var onRatedTap: (() -> Void)?
    var onWantToTryTap: (() -> Void)?
    var onAddWishlistSearch: (() -> Void)?
    var onWantToTryToggle: ((CellarItem) async -> Void)?
    var onRemoveWishlistItem: ((CellarItem) async -> Void)?
    var onMarkAsTasted: ((CellarItem) -> Void)?
    var onTwinTap: ((UUID) -> Void)?

    enum MainTab: String, CaseIterable { case recentActivity = "Recent"; case tasteProfile = "Taste"; case wantToTry = "Reserve List" }
    enum TasteSubTab: String, CaseIterable { case regions = "Regions"; case grapes = "Grapes" }

    @State private var mainTab: MainTab = .recentActivity
    @State private var tasteSubTab: TasteSubTab = .regions

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if let err = viewModel.errorMessage, !viewModel.isLoading {
                    Text(err)
                        .font(PariTheme.uiFont(size: 13))
                        .foregroundStyle(.red)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(PariTheme.dangerMuted(for: colorScheme).opacity(0.15))
                }
                if let p = viewModel.profile {
                    header(p)
                    tasteSnapshotCard(p)
                    if isOwn, !tasteTwins.isEmpty {
                        WineTwinsView(
                            userId: viewModel.userId,
                            twins: tasteTwins,
                            onTwinTap: onTwinTap
                        )
                    }
                    tabs
                    tabContent
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 40)
        }
    }

    private func wantToTrySearchBar(onTap: @escaping () -> Void) -> some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16))
                    .foregroundStyle(PariTheme.secondaryText(for: colorScheme))
                Text("Search wines to add")
                    .font(PariTheme.uiFont(size: 16))
                    .foregroundStyle(PariTheme.secondaryText(for: colorScheme))
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(PariTheme.secondaryElevated(for: colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .padding(.bottom, 16)
    }

    private func header(_ p: Profile) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .top, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    PariEyebrow(isOwn ? "Personal wine journal" : "Wine journal")
                    Text(p.displayName)
                        .font(PariTheme.editorialFont(size: 32))
                        .foregroundStyle(PariTheme.textPrimary(for: colorScheme))
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 8) {
                        Text("@\(p.username)").font(.subheadline)
                            .foregroundStyle(PariTheme.textSecondary(for: colorScheme))
                        if let h = p.instagramHandle?.trimmingCharacters(in: .whitespacesAndNewlines), !h.isEmpty {
                            InstagramIconButton(handle: h)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                avatar(p)
            }
            if let bio = p.bioTrimmed, !bio.isEmpty {
                Text(bio).font(.subheadline).lineSpacing(3)
                    .foregroundStyle(PariTheme.textSecondary(for: colorScheme))
                    .fixedSize(horizontal: false, vertical: true)
            }
            statsRow
            if !isOwn {
                primaryButton(p)
                if let sim = tasteSimilarity { TasteTwinBadge(similarity: sim) }
            }
        }
    }

    private func avatar(_ p: Profile) -> some View {
        Group {
            if let u = p.avatarURL, let url = URL(string: u) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let img): img.resizable().aspectRatio(contentMode: .fill)
                    default: avatarPlaceholder(p)
                    }
                }
            } else {
                avatarPlaceholder(p)
            }
        }
        .frame(width: 56, height: 56)
        .clipShape(Circle())
    }

    private func avatarPlaceholder(_ p: Profile) -> some View {
        Circle()
            .fill(PariTheme.placeholderBackground(for: colorScheme))
            .overlay(
                Text(String(p.displayName.prefix(1)).uppercased())
                    .font(PariTheme.editorialFont(size: 27))
                    .foregroundStyle(PariTheme.secondaryText(for: colorScheme))
            )
    }

    private var statsRow: some View {
        HStack(spacing: 16) {
            Button {
                onRatedTap?()
            } label: {
                statItem(value: "\(viewModel.ratedCount)", label: "Tastings")
            }
            .buttonStyle(.plain)
            Button {
                onFollowersTap?()
            } label: {
                statItem(value: "\(viewModel.followersCount)", label: "Followers")
            }
            .buttonStyle(.plain)
            Button {
                onFollowingTap?()
            } label: {
                statItem(value: "\(viewModel.followingCount)", label: "Following")
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
    }

    private func statItem(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            PariRule()
            VStack(alignment: .leading, spacing: 4) {
                Text(value).font(PariTheme.editorialFont(size: 24))
                    .foregroundStyle(PariTheme.textPrimary(for: colorScheme))
                Text(label).font(.caption)
                    .foregroundStyle(PariTheme.textSecondary(for: colorScheme))
            }
            .padding(.top, 7)
        }
        .frame(maxWidth: .infinity, minHeight: 50, alignment: .leading)
    }

    private func primaryButton(_ p: Profile) -> some View {
        Group {
            if isGuestProfile(p) {
                Text("User not found")
                    .font(PariTheme.uiFont(size: 15, weight: .medium))
                    .foregroundStyle(PariTheme.secondaryText(for: colorScheme))
            } else {
                VStack(spacing: 4) {
                    Button {
                        onFollowToggle?()
                    } label: {
                        Text(isFollowing ? "Following" : "Follow")
                            .font(PariTheme.uiFont(size: 15, weight: .medium))
                            .foregroundStyle(isFollowing ? PariTheme.secondaryText(for: colorScheme) : .white)
                            .padding(.horizontal, 28)
                            .padding(.vertical, 12)
                            .background(isFollowing ? PariTheme.placeholderBackground(for: colorScheme) : PariTheme.actionFill(for: colorScheme))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .disabled(isTogglingFollow)
                    if let e = followError {
                        Text(e)
                            .font(PariTheme.uiFont(size: 13))
                            .foregroundStyle(.red)
                    }
                }
            }
        }
    }

    private func isGuestProfile(_ p: Profile) -> Bool {
        p.username.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "guest"
    }


    @ViewBuilder
    private func tasteSnapshotCard(_ p: Profile) -> some View {
        let note = HStack(alignment: .top, spacing: 12) {
            Rectangle().fill(PariTheme.accent(for: colorScheme)).frame(width: 2)
            VStack(alignment: .leading, spacing: 7) {
                tasteLine("Loves ·", TasteSnapshotOptions.labelForLoves(id: p.tasteSnapshotLoves))
                tasteLine("Avoids ·", TasteSnapshotOptions.labelForAvoids(id: p.tasteSnapshotAvoids))
                tasteLine("Mood ·", TasteSnapshotOptions.labelForMood(id: p.tasteSnapshotMood))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if isOwn {
                Image(systemName: "pencil").font(.system(size: 13))
                    .foregroundStyle(PariTheme.textSecondary(for: colorScheme))
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(.vertical, 2)
        if isOwn, let onEdit {
            Button(action: onEdit) { note }.buttonStyle(.plain)
                .accessibilityHint("Edit your taste preferences")
        } else { note }
    }

    private func tasteLine(_ label: String, _ value: String) -> some View {
        (Text(label + " ").foregroundColor(PariTheme.textSecondary(for: colorScheme))
         + Text(value).foregroundColor(PariTheme.textPrimary(for: colorScheme)))
            .font(.subheadline)
            .multilineTextAlignment(.leading)
    }

    private var tabs: some View {
        VStack(spacing: 0) {
            PariTabStrip {
                ForEach(MainTab.allCases, id: \.self) { tab in
                    PariSectionTab(title: tab.rawValue, selected: mainTab == tab) { mainTab = tab }
                }
            }
            PariRule()
        }
    }

    @ViewBuilder
    private var tabContent: some View {
        switch mainTab {
        case .recentActivity:
            recentActivityList
        case .tasteProfile:
            tasteProfileContent
        case .wantToTry:
            wantToTryTabContent
        }
    }

    @ViewBuilder
    private var wantToTryTabContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            if isOwn, let onSearch = onAddWishlistSearch {
                wantToTrySearchBar(onTap: onSearch)
            }
            if !viewModel.wishlistVisible {
                Text("Wishlist is visible to friends.")
                    .font(PariTheme.uiFont(size: 15))
                    .foregroundStyle(PariTheme.secondaryText(for: colorScheme))
                    .multilineTextAlignment(.center)
                    .padding(.vertical, 24)
                    .frame(maxWidth: .infinity)
            } else if viewModel.wishlistPreview.isEmpty {
                Text(isOwn
                    ? "No wines saved yet. Tap the bookmark on any feed post to add."
                    : "No wines in their list.")
                    .font(PariTheme.uiFont(size: 15))
                    .foregroundStyle(PariTheme.secondaryText(for: colorScheme))
                    .multilineTextAlignment(.center)
                    .padding(.vertical, 24)
                    .frame(maxWidth: .infinity)
            } else {
                ForEach(Array(viewModel.wishlistPreview.prefix(5))) { item in
                    wantToTryRow(item, onRemove: isOwn ? { item in Task { await onRemoveWishlistItem?(item) } } : nil)
                    Rectangle().fill(PariTheme.border(for: colorScheme)).frame(height: 1).padding(.leading, 0)
                }
                if let onTap = onWantToTryTap {
                    Button {
                        onTap()
                    } label: {
                        Text("Open full list")
                            .font(PariTheme.uiFont(size: 15, weight: .medium))
                            .foregroundStyle(PariTheme.accent(for: colorScheme))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 8)
                }
            }
        }
    }

    private func wantToTryRow(_ item: CellarItem, onRemove: ((CellarItem) -> Void)?) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.wine.producer)
                    .font(.caption)
                    .foregroundStyle(colorScheme == .dark ? PariTheme.textTertiary(for: colorScheme) : PariTheme.secondaryText(for: colorScheme))
                Text(PariTheme.displayWineName(item.wine.name))
                    .font(PariTheme.wineNameFont(for: colorScheme))
                    .foregroundStyle(PariTheme.textPrimary(for: colorScheme))
                if let r = item.wine.region, !r.isEmpty {
                    Text(r)
                        .font(PariTheme.uiFont(size: 12))
                        .foregroundStyle(PariTheme.secondaryText(for: colorScheme))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if isOwn {
                Button("Mark as Tasted") {
                    onMarkAsTasted?(item)
                }
                .font(PariTheme.uiFont(size: 14, weight: .medium))
                .foregroundStyle(PariTheme.accent(for: colorScheme))
            } else if let onToggle = onWantToTryToggle {
                Button {
                    Task { await onToggle(item) }
                } label: {
                    Image(systemName: viewModel.myWishlistWineIds.contains(item.wineId) ? "bookmark.fill" : "bookmark")
                        .font(.system(size: 18))
                        .foregroundStyle(viewModel.myWishlistWineIds.contains(item.wineId) ? PariTheme.accentWine(for: colorScheme) : PariTheme.secondaryText(for: colorScheme))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .swipeActions(edge: .leading, allowsFullSwipe: false) {
            if isOwn, onMarkAsTasted != nil {
                Button {
                    onMarkAsTasted?(item)
                } label: {
                    Label("Tasted", systemImage: "checkmark.circle")
                }
                .tint(PariTheme.accent(for: colorScheme))
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            if let onRemove = onRemove {
                Button(role: .destructive) {
                    onRemove(item)
                } label: {
                    Label("Remove", systemImage: "trash")
                }
            }
        }
        .contextMenu {
            if let onRemove = onRemove {
                Button(role: .destructive) {
                    onRemove(item)
                } label: {
                    Label("Remove", systemImage: "trash")
                }
            }
        }
    }

    private var recentActivityList: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !viewModel.activityVisible {
                Text("Activity is visible to friends.")
                    .font(PariTheme.uiFont(size: 15))
                    .foregroundStyle(PariTheme.secondaryText(for: colorScheme))
                    .multilineTextAlignment(.center)
                    .padding(.vertical, 24)
                    .frame(maxWidth: .infinity)
            } else {
                if let error = viewModel.tastingsErrorMessage {
                    VStack(spacing: 12) {
                        Text(error)
                            .font(PariTheme.uiFont(size: 15))
                            .foregroundStyle(PariTheme.secondaryText(for: colorScheme))
                        Button("Retry") { Task { await viewModel.reloadTastings() } }
                            .disabled(viewModel.isLoadingTastings)
                            .accessibilityIdentifier("profile.retryTastings")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                }
                if viewModel.isLoadingTastings {
                    ProgressView("Loading tastings…")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                } else if viewModel.showsEmptyTastings {
                    Text("No tastings yet.")
                        .font(PariTheme.uiFont(size: 15))
                        .foregroundStyle(PariTheme.secondaryText(for: colorScheme))
                        .padding(.vertical, 24)
                        .frame(maxWidth: .infinity)
                } else {
                    ForEach(viewModel.recentTastingsTop5) { tasting in
                        tastingActivityRow(tasting)
                        Rectangle().fill(PariTheme.border(for: colorScheme)).frame(height: 1)
                    }
                }
            }
        }
    }

    private func tastingActivityRow(_ tasting: Tasting) -> some View {
        let cheersCount = viewModel.tastingCheersCounts[tasting.id] ?? 0
        return NavigationLink(destination: WineCardView(wine: tasting.wine, activityId: nil, currentUserId: viewModel.userId, sourceUserId: viewModel.userId, sourceContext: "profile")) {
            HStack(alignment: .top, spacing: 14) {
                if !dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 3) {
                    Text(tasting.createdAt.formatted(.dateTime.month(.abbreviated)).uppercased())
                        .font(.system(.caption2, design: .monospaced))
                    Text(tasting.createdAt.formatted(.dateTime.day()))
                        .font(PariTheme.editorialFont(size: 25))
                    Text(tasting.createdAt.formatted(.dateTime.year())).font(.system(.caption2, design: .monospaced))
                }
                .foregroundStyle(PariTheme.textSecondary(for: colorScheme))
                .frame(width: 38, alignment: .leading)
                }
                VStack(alignment: .leading, spacing: 6) {
                    if dynamicTypeSize.isAccessibilitySize {
                        Text(tasting.createdAt.formatted(date: .abbreviated, time: .omitted)).font(.caption)
                            .foregroundStyle(PariTheme.textSecondary(for: colorScheme))
                    }
                    Text(tasting.wine.producer).font(.caption)
                        .foregroundStyle(PariTheme.textSecondary(for: colorScheme))
                    Text(tasting.wine.name).font(PariTheme.wineNameFont(for: colorScheme))
                        .foregroundStyle(PariTheme.textPrimary(for: colorScheme))
                        .fixedSize(horizontal: false, vertical: true)
                    if let vintage = tasting.displayVintage {
                        Text("Vintage \(String(vintage))").font(.caption.monospacedDigit())
                            .foregroundStyle(PariTheme.textSecondary(for: colorScheme))
                    }
                    if let comment = tasting.comment, !comment.isEmpty {
                        Text(comment).font(.subheadline).lineLimit(2)
                            .foregroundStyle(PariTheme.textSecondary(for: colorScheme))
                    }
                    HStack(spacing: 8) {
                        if cheersCount > 0 { Label("\(cheersCount)", systemImage: "wineglass").font(.caption2) }
                    }
                    .foregroundStyle(PariTheme.textSecondary(for: colorScheme))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                PariScore(value: tasting.rating)
            }
            .padding(.vertical, 18)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func recentActivityRow(_ item: FeedItem) -> some View {
        let parts = item.statementParts()
        return HStack(alignment: .top, spacing: 12) {
            avatarCircle(item)
            (Text(parts.before)
                .font(PariTheme.uiFont(size: 15))
                .foregroundStyle(colorScheme == .dark ? PariTheme.textPrimary(for: colorScheme) : .primary)
            + Text(parts.name)
                .font(PariTheme.wineNameFont(for: colorScheme))
                .foregroundStyle(colorScheme == .dark ? PariTheme.wineNameColor(for: colorScheme) : WineColorResolver.resolveWineDisplayColor(category: item.wineCategory, wineName: item.wineName, variety: item.wineVariety, debugPostId: item.id))
            + Text(parts.after)
                .font(PariTheme.uiFont(size: 15))
                .foregroundStyle(colorScheme == .dark ? PariTheme.textPrimary(for: colorScheme) : .primary))
            .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .onTapGesture { onActivityTap?(item) }
    }

    private func cellarAvatarCircle() -> some View {
        Group {
            if let p = viewModel.profile, let u = p.avatarURL, let url = URL(string: u) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let img): img.resizable().aspectRatio(contentMode: .fill)
                    default: cellarAvatarPlaceholder()
                    }
                }
            } else {
                cellarAvatarPlaceholder()
            }
        }
        .frame(width: 28, height: 28)
        .clipShape(Circle())
    }

    private func cellarAvatarPlaceholder() -> some View {
        Circle()
            .fill(PariTheme.placeholderBackground(for: colorScheme))
            .overlay(
                Text(String(viewModel.profile?.displayName.prefix(1) ?? "U").uppercased())
                    .font(PariTheme.uiFont(size: 14, weight: .medium))
                    .foregroundStyle(PariTheme.secondaryText(for: colorScheme))
            )
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private func avatarCircle(_ item: FeedItem) -> some View {
        Group {
            if let u = item.avatarURL, let url = URL(string: u) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let img): img.resizable().aspectRatio(contentMode: .fill)
                    default: circlePlaceholder(item)
                    }
                }
            } else {
                circlePlaceholder(item)
            }
        }
        .frame(width: 36, height: 36)
        .clipShape(Circle())
    }

    private func circlePlaceholder(_ item: FeedItem) -> some View {
        Circle()
            .fill(PariTheme.placeholderBackground(for: colorScheme))
            .overlay(
                Text(String(item.username.prefix(1)).uppercased())
                    .font(PariTheme.uiFont(size: 14, weight: .medium))
                    .foregroundStyle(PariTheme.secondaryText(for: colorScheme))
            )
    }

    private var tasteProfileContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Spacer()
                ForEach(TasteSubTab.allCases, id: \.self) { tab in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            tasteSubTab = tab
                        }
                    } label: {
                        Text(tab.rawValue)
                            .font(PariTheme.uiFont(size: 14, weight: .medium))
                            .foregroundStyle(PariTheme.textSecondary(for: colorScheme))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(PariTheme.surfaceElevated(for: colorScheme))
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(tasteSubTab == tab ? PariTheme.accentWine(for: colorScheme) : Color.clear, lineWidth: 1)
                            )
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }
            tasteProfileList
        }
    }

    @ViewBuilder
    private var tasteProfileList: some View {
        let items: [TasteProfileItem] = {
            switch tasteSubTab {
            case .regions: return viewModel.tasteRegions
            case .grapes: return viewModel.tasteGrapes
            }
        }()
        if items.isEmpty {
            Text("No data yet. Rate wines to build your taste profile.")
                .font(PariTheme.uiFont(size: 15))
                .foregroundStyle(PariTheme.secondaryText(for: colorScheme))
                .padding(.vertical, 24)
                .frame(maxWidth: .infinity)
        } else {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(items) { it in
                    tasteProfileRow(it)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if tasteSubTab == .regions {
                                onRegionTap?(it.name)
                            } else {
                                onGrapeTap?(it.name)
                            }
                        }
                    Rectangle().fill(PariTheme.border(for: colorScheme)).frame(height: 1)
                }
            }
        }
    }

    private func tasteProfileRow(_ it: TasteProfileItem) -> some View {
        let nameColor: Color = colorScheme == .dark ? PariTheme.wineNameColor(for: colorScheme) : (tasteSubTab == .grapes ? WineColorResolver.resolveWineDisplayColor(category: nil, wineName: it.name, variety: it.name) : Color.primary)
        return HStack {
            Text(it.name)
                .font(PariTheme.uiFont(size: 15, weight: .medium))
                .foregroundStyle(nameColor)
            Spacer()
            HStack(spacing: 8) {
                if let avgRating = it.averageRating {
                    Text(String(format: "%.1f", avgRating))
                        .font(PariTheme.uiFont(size: 14, weight: .medium))
                        .foregroundStyle(colorScheme == .dark ? PariTheme.ratingColor(for: colorScheme) : WineColorResolver.resolveWineDisplayColor(category: nil, wineName: it.name, variety: it.name))
                    Text("·")
                        .font(PariTheme.uiFont(size: 14))
                        .foregroundStyle(PariTheme.textTertiary(for: colorScheme))
                }
                Text("\(it.count) \(it.count == 1 ? "tasting" : "tastings")")
                    .font(PariTheme.uiFont(size: 14))
                    .foregroundStyle(PariTheme.textTertiary(for: colorScheme))
            }
        }
        .padding(.vertical, 12)
    }
}

// MARK: - Instagram icon button (app or Safari)

private struct InstagramIconButton: View {
    @Environment(\.colorScheme) private var colorScheme
    let handle: String
    @Environment(\.openURL) private var openURL

    var body: some View {
        Button {
            openInstagram(handle: handle)
        } label: {
            Image(systemName: "camera.fill")
                .font(.system(size: 14))
                .foregroundStyle(PariTheme.secondaryText(for: colorScheme))
        }
        .buttonStyle(.plain)
    }

    private func openInstagram(handle: String) {
        let escaped = handle.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? handle
        let appURL = URL(string: "instagram://user?username=\(escaped)")
        let webURL = URL(string: "https://www.instagram.com/\(escaped)/")
        if let appURL, UIApplication.shared.canOpenURL(appURL) {
            openURL(appURL)
        } else if let webURL {
            openURL(webURL)
        }
    }
}
