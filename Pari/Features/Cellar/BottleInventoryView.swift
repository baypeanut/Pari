import SwiftUI

struct BottleInventoryView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase
    @State private var model = BottleInventoryViewModel()
    @State private var showAddBottles = false

    var body: some View {
        Group {
            if AuthStore.shared.currentUserId == nil {
                ContentUnavailableView("Your bottles", systemImage: "wineglass",
                    description: Text("Sign in to keep track of the bottles you own."))
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(model.totalBottles) bottles").font(PariTheme.editorialFont(size: 25)).monospacedDigit()
                                Text("At home, ready for another occasion.").font(.subheadline).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button { showAddBottles = true } label: { Label("Add", systemImage: "plus").font(.subheadline.weight(.medium)).frame(minHeight: 44) }
                                .accessibilityLabel("Add bottles to your cellar")
                        }
                        if let error = model.errorMessage {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Couldn't refresh your bottles. \(error)").font(.subheadline)
                                Button("Retry refresh") { Task { await model.load() } }
                            }
                        }
                        if let error = model.mutationError {
                            Text(error).font(.subheadline).foregroundStyle(.red)
                        }
                        if model.isLoading { ProgressView("Loading bottles…").frame(maxWidth: .infinity) }
                        if !model.isLoading && model.errorMessage == nil && model.bottles.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                PariEmptyNote(title: "Room for a first bottle.", message: "Add what is on your wine rack. Keep the vintage, location and count in one place.")
                                Button("Add bottles") { showAddBottles = true }
                                    .font(.subheadline.weight(.medium)).frame(minHeight: 44)
                            }
                        }
                        LazyVStack(spacing: 16) {
                            ForEach(model.bottles) { bottle in bottleRow(bottle) }
                        }
                    }
                    .padding(24)
                }
                .refreshable { await model.load() }
            }
        }
        .tint(PariTheme.accent(for: colorScheme))
        .task { if AuthStore.shared.currentUserId != nil { await model.load() } }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active && AuthStore.shared.currentUserId != nil { Task { await model.load() } }
        }
        .sheet(isPresented: $showAddBottles) {
            AddBottlesSheet { Task { await model.load() } }
        }
    }

    private func bottleRow(_ bottle: OwnedBottle) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            NavigationLink {
                WineCardView(wine: bottle.wine, activityId: nil, currentUserId: AuthStore.shared.currentUserId)
            } label: {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(bottle.wine.name).font(PariTheme.wineNameFont(for: colorScheme)).foregroundStyle(PariTheme.textPrimary(for: colorScheme))
                        Text(bottle.wine.producer).font(.subheadline).foregroundStyle(.secondary)
                        Text(bottle.vintage.map(String.init) ?? "Vintage unknown").font(.subheadline).foregroundStyle(.secondary)
                        if let location = bottle.location, !location.isEmpty {
                            Label(location, systemImage: "mappin").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
            HStack {
                Text("\(bottle.quantity) \(bottle.quantity == 1 ? "bottle" : "bottles") left").font(.subheadline.weight(.medium))
                Spacer()
                if model.activeBottleId == bottle.id { ProgressView() }
                Button(model.isAwaitingConfirmation(bottle.id) ? "Retry" : "Opened one", systemImage: "minus.circle") {
                    Task { await model.openOne(bottle) }
                }
                .buttonStyle(.bordered)
                .disabled(model.activeBottleId != nil || model.isLoading || model.errorMessage != nil)
                .accessibilityLabel(model.isAwaitingConfirmation(bottle.id)
                    ? "Retry opening one bottle of \(bottle.wine.name)"
                    : "Remove one opened bottle of \(bottle.wine.name)")
            }
        }
        .padding(.vertical, 18)
        .overlay(alignment: .bottom) { PariRule() }
    }
}
