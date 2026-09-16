//
//  RootView.swift
//  Pari
//
//  Auth gate: phone OTP + profile setup. Restores session if available.
//

import SwiftUI

enum Tab {
    case social, cellar, notifications, profile
}

struct RootView: View {
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("appearance_preference") private var appearanceRaw = AppearanceOption.system.rawValue
    @AppStorage("pari_age_verified") private var ageVerified = false
    @AppStorage("pari_drink_responsibly_shown") private var drinkResponsiblyShown = false
    @State private var selectedTab: Tab = .social
    @State private var authStore = AuthStore.shared
    @State private var showAddWineFromCarousel = false
    @State private var showDrinkResponsibly = false
    @State private var showLabelScan = false
    @State private var deepLinkWine: Wine?
    @State private var deepLinkProfileUsername: String?
    @ObservedObject private var recovery = AuthRecoveryState.shared

    var body: some View {
        Group {
            if !ageVerified {
                AgeGateView {
                    ageVerified = true
                    if !drinkResponsiblyShown {
                        showDrinkResponsibly = true
                    }
                }
            } else if AppConstants.bypassLogin {
                mainContent
            } else {
                switch authStore.state {
                case .checking:
                    PariTheme.background(for: colorScheme).overlay {
                        ProgressView().tint(PariTheme.accent(for: colorScheme))
                    }
                    .ignoresSafeArea()
                case .unauthenticated:
                    PhoneEntryView()
                case .awaitingCode(let phone):
                    CodeEntryView(phoneDisplay: phone)
                case .authenticated(let userId):
                    if authStore.needsProfileSetup {
                        ProfileSetupView(userId: userId)
                    } else {
                        mainContent
                    }
                }
            }
        }
        .sheet(isPresented: $showDrinkResponsibly) {
            DrinkResponsiblyView {
                drinkResponsiblyShown = true
                showDrinkResponsibly = false
            }
            .interactiveDismissDisabled(true)
        }
        .task {
            if !authStore.sessionRestored {
                await authStore.restoreSession()
                if case .authenticated = authStore.state {
                    await ProfileStore.shared.load()
                }
            }
        }
        .onChange(of: authStore.state) { _, newState in
            if case .authenticated = newState {
                Task { await ProfileStore.shared.load() }
                if ageVerified, case .authenticated(let uid) = newState {
                    Task { try? await ProfileService.updateAgeVerified(userId: uid) }
                }
            }
        }
        .onChange(of: ageVerified) { _, newValue in
            if newValue, case .authenticated(let uid) = authStore.state {
                Task { try? await ProfileService.updateAgeVerified(userId: uid) }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .pariSwitchToCellarTab)) { _ in
            selectedTab = .cellar
        }
        .fullScreenCover(isPresented: Binding(
            get: { recovery.showNewPasswordView },
            set: { if !$0 { recovery.dismissRecovery() } }
        )) {
            NewPasswordView(onComplete: {
                recovery.dismissRecovery()
            })
        }
        .sheet(item: Binding(
            get: { authStore.authResultEvent },
            set: { authStore.authResultEvent = $0 }
        )) { event in
            ConfirmationSheetView(event: event) {
                authStore.authResultEvent = nil
            }
        }
        .preferredColorScheme(AppearanceStorage.resolvedColorScheme(for: appearanceRaw))
    }

    private var mainContent: some View {
        mainTabs
            .id(authStore.sessionGeneration)
            .onChange(of: DeepLinkRouter.shared.pendingRoute) { _, route in
                guard let route else { return }
                handleDeepLink(route)
            }
            .sheet(item: $deepLinkWine) { wine in
                NavigationStack {
                    WineCardView(wine: wine, activityId: nil, currentUserId: authStore.currentUserId)
                }
            }
            .sheet(isPresented: Binding(
                get: { deepLinkProfileUsername != nil },
                set: { if !$0 { deepLinkProfileUsername = nil } }
            )) {
                if let username = deepLinkProfileUsername {
                    DeepLinkProfileResolver(username: username) {
                        deepLinkProfileUsername = nil
                    }
                }
            }
            .fullScreenCover(isPresented: $showAddWineFromCarousel) {
                AddWineSheet(
                    isPresented: $showAddWineFromCarousel,
                    onWineAdded: { showAddWineFromCarousel = false }
                )
            }
            .fullScreenCover(isPresented: $showLabelScan) {
                WineLabelScanView(isPresented: $showLabelScan)
            }
    }

    private var mainTabs: some View {
        TabView(selection: $selectedTab) {
            SocialView().tag(Tab.social)
            NavigationStack { CellarView() }.tag(Tab.cellar)
            NotificationsView().tag(Tab.notifications)
            ProfileView(onSignOut: didSignOut).tag(Tab.profile)
        }
        .toolbar(.hidden, for: .tabBar)
        .tint(PariTheme.accent(for: colorScheme))
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 0) {
                PariRule()
                HStack(spacing: 0) {
                    destination(.social, title: "Discover", icon: "text.book.closed")
                    destination(.cellar, title: "Cellar", icon: "wineglass")
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        showLabelScan = true
                    } label: {
                        VStack(spacing: 5) {
                            Image(systemName: "viewfinder").font(.system(size: 21, weight: .regular))
                            Text("Scan").font(.system(.caption2, weight: .medium))
                        }
                        .foregroundStyle(PariTheme.accent(for: colorScheme))
                        .frame(maxWidth: .infinity, minHeight: 58)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Scan a wine label")
                    destination(.notifications, title: "Activity", icon: "bell")
                    destination(.profile, title: "Profile", icon: "person.crop.square")
                }
                .padding(.horizontal, 12)
                .padding(.top, 4)
                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
            }
            .background(PariTheme.background(for: colorScheme))
        }
    }

    private func destination(_ tab: Tab, title: String, icon: String) -> some View {
        Button { selectedTab = tab } label: {
            VStack(spacing: 5) {
                Image(systemName: icon).font(.system(size: 21, weight: selectedTab == tab ? .semibold : .regular))
                Text(title).font(.system(.caption2, weight: selectedTab == tab ? .semibold : .regular))
            }
            .foregroundStyle(selectedTab == tab ? PariTheme.accent(for: colorScheme) : PariTheme.textSecondary(for: colorScheme))
            .frame(maxWidth: .infinity, minHeight: 58)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selectedTab == tab ? .isSelected : [])
        .accessibilityIdentifier("tab.\(title.lowercased())")
    }

    private func handleDeepLink(_ route: DeepLinkRouter.Route) {
        _ = DeepLinkRouter.shared.consumeRoute()
        switch route {
        case .wine(let id):
            Task {
                guard let wine = try? await WineService.fetchWine(id: id) else { return }
                deepLinkWine = wine
            }
        case .profile(let username):
            deepLinkProfileUsername = username
        }
    }

    private func didSignOut() {
        AnalyticsService.reset()
        Task {
            await AuthStore.shared.signOut()
            ProfileStore.shared.clearForSignOut()
        }
    }
}

/// Resolves a username to a userId, then presents UserProfileView.
private struct DeepLinkProfileResolver: View {
    let username: String
    let onDismiss: () -> Void
    @State private var resolvedUserId: UUID?
    @State private var notFound = false

    var body: some View {
        NavigationStack {
            Group {
                if let userId = resolvedUserId {
                    UserProfileView(userId: userId, onDismiss: onDismiss)
                } else if notFound {
                    ContentUnavailableView("User not found", systemImage: "person.slash", description: Text("@\(username) doesn't exist."))
                } else {
                    ProgressView()
                }
            }
            .task {
                if let uid = await ProfileService.fetchUserId(byUsername: username) {
                    resolvedUserId = uid
                } else {
                    notFound = true
                }
            }
        }
    }
}
