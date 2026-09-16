import SwiftUI

struct AddBottlesSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var results: [Wine] = []
    @State private var selectedWine: Wine?
    @State private var isSearching = false
    @State private var hasSearched = false
    @State private var searchError: String?
    @State private var quantity = 1
    @State private var vintageText = ""
    @State private var location = ""
    @State private var pending: AddBottlesRequest?
    @State private var isSaving = false
    @State private var saveError: String?
    var onSaved: () -> Void

    var body: some View {
        NavigationStack {
            Group {
                if let wine = selectedWine { details(wine) } else { search }
            }
            .navigationTitle("Add bottles")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.disabled(isSaving)
                }
                if selectedWine != nil {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(pending == nil ? "Add" : "Retry") { Task { await save() } }
                            .disabled(isSaving)
                    }
                }
            }
            .interactiveDismissDisabled(isSaving)
            .alert("Couldn't add bottles", isPresented: Binding(
                get: { saveError != nil }, set: { if !$0 { saveError = nil } }
            )) {
                Button("OK") { saveError = nil }
            } message: { Text(saveError ?? "") }
        }
    }

    private var search: some View {
        VStack(spacing: 12) {
            TextField("Search wine or producer", text: $query)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal)
                .padding(.top)
                .accessibilityLabel("Search wine or producer")
            if isSearching { ProgressView("Searching wines…") }
            if let searchError {
                ContentUnavailableView("Search unavailable", systemImage: "wifi.exclamationmark",
                    description: Text(searchError))
                Button("Retry search") { Task { await searchWines() } }
            } else if hasSearched && results.isEmpty {
                ContentUnavailableView.search(text: query)
            } else if query.trimmingCharacters(in: .whitespacesAndNewlines).count < 2 {
                ContentUnavailableView("Find your bottle", systemImage: "wineglass",
                    description: Text("Search the catalog, then choose the vintage and how many you own."))
            } else {
                List(results) { wine in
                    Button {
                        selectedWine = wine
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(wine.name).font(.headline)
                            Text(wine.producer).font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                    .foregroundStyle(.primary)
                }
                .listStyle(.plain)
            }
            Spacer(minLength: 0)
        }
        .task(id: query) { await searchWines() }
    }

    private func details(_ wine: Wine) -> some View {
        Form {
            Section {
                Text(wine.name).font(.headline)
                Text(wine.producer).foregroundStyle(.secondary)
                Button("Choose another wine") { selectedWine = nil }
            }
            .disabled(isSaving || pending != nil)
            Section {
                Stepper("\(quantity) \(quantity == 1 ? "bottle" : "bottles")", value: $quantity, in: 1...100)
                TextField("Vintage (optional)", text: $vintageText).keyboardType(.numberPad)
                TextField("Location (optional)", text: $location)
                    .onChange(of: location) { _, value in location = String(value.prefix(200)) }
            } footer: {
                Text("Leave vintage blank if you don't know it. Bottles of the same wine and vintage are counted together.")
            }
            .disabled(isSaving || pending != nil)
            if isSaving { ProgressView("Saving bottles…") }
            if pending != nil && !isSaving {
                Section {
                    Text("Your original bottle details are kept. Tap Retry to confirm this addition without adding them twice.")
                        .font(.footnote)
                }
            }
        }
    }

    @MainActor
    private func searchWines() async {
        let request = query
        let term = request.trimmingCharacters(in: .whitespacesAndNewlines)
        results = []
        searchError = nil
        hasSearched = false
        guard term.count >= 2 else { isSearching = false; return }
        isSearching = true
        defer { if query == request { isSearching = false } }
        do {
            try await Task.sleep(for: .milliseconds(300))
            let wines = try await WineService.searchCatalog(query: term, limit: 50)
            guard query == request, !Task.isCancelled else { return }
            results = wines
            hasSearched = true
        } catch {
            guard query == request, !Task.isCancelled else { return }
            searchError = ErrorMessage.userFacing(for: error)
        }
    }

    @MainActor
    private func save() async {
        guard !isSaving, let wine = selectedWine else { return }
        let session = AuthStore.shared.sessionGeneration
        guard AuthStore.shared.currentUserId != nil else { saveError = ErrorMessage.unauthorized; return }
        isSaving = true
        defer { isSaving = false }
        do {
            if pending == nil {
                pending = AddBottlesRequest(requestId: UUID(), wineId: wine.id, quantity: quantity,
                    vintage: try BottleInput.vintage(from: vintageText),
                    location: location.trimmingCharacters(in: .whitespacesAndNewlines))
            }
            guard let request = pending else { return }
            _ = try await CellarBottleService.addBottles(request)
            guard session == AuthStore.shared.sessionGeneration else { return }
            NotificationCenter.default.post(name: .pariCellarInventoryChanged, object: nil)
            onSaved()
            dismiss()
        } catch {
            guard session == AuthStore.shared.sessionGeneration else { return }
            saveError = error is BottleInput.ValidationError ? error.localizedDescription : ErrorMessage.userFacing(for: error)
        }
    }
}
