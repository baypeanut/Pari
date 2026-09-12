import Foundation

@MainActor
@Observable
final class BottleInventoryViewModel {
    var bottles: [OwnedBottle] = []
    var isLoading = false
    var errorMessage: String?
    var mutationError: String?
    private(set) var activeBottleId: UUID?
    private var pending: [UUID: DrinkBottleRequest] = [:]
    private var loadGeneration = UUID()
    private let fetch: @MainActor () async throws -> [OwnedBottle]
    private let drink: @MainActor (DrinkBottleRequest) async throws -> CellarStockResult
    private let session: @MainActor () -> UUID
    private let notify: @MainActor () -> Void

    init(
        fetch: @escaping @MainActor () async throws -> [OwnedBottle] = { try await CellarBottleService.fetchOwnedBottles() },
        drink: @escaping @MainActor (DrinkBottleRequest) async throws -> CellarStockResult = { try await CellarBottleService.drinkOne($0) },
        session: @escaping @MainActor () -> UUID = { AuthStore.shared.sessionGeneration },
        notify: @escaping @MainActor () -> Void = {
            NotificationCenter.default.post(name: .pariCellarInventoryChanged, object: nil)
        }
    ) {
        self.fetch = fetch
        self.drink = drink
        self.session = session
        self.notify = notify
    }

    var totalBottles: Int { bottles.reduce(0) { $0 + $1.quantity } }
    func isAwaitingConfirmation(_ id: UUID) -> Bool { pending[id] != nil }

    func load() async {
        let generation = UUID()
        loadGeneration = generation
        let userSession = session()
        isLoading = true
        defer { if generation == loadGeneration { isLoading = false } }
        do {
            let rows = try await fetch()
            guard generation == loadGeneration, session() == userSession, !Task.isCancelled else { return }
            bottles = rows
            errorMessage = nil
        } catch {
            guard generation == loadGeneration, session() == userSession, !Task.isCancelled else { return }
            errorMessage = ErrorMessage.userFacing(for: error)
        }
    }

    func openOne(_ bottle: OwnedBottle) async {
        guard activeBottleId == nil, !isLoading, errorMessage == nil else { return }
        let userSession = session()
        let request = pending[bottle.id] ?? DrinkBottleRequest(requestId: UUID(), bottleId: bottle.id)
        pending[bottle.id] = request
        activeBottleId = bottle.id
        mutationError = nil
        defer { activeBottleId = nil }
        do {
            let result = try await drink(request)
            guard session() == userSession else { return }
            pending[bottle.id] = nil
            bottles = bottles.compactMap { row in
                guard row.id == result.bottle_id else { return row }
                guard result.quantity > 0 else { return nil }
                return OwnedBottle(id: row.id, wine: row.wine, vintage: row.vintage,
                                   quantity: result.quantity, location: row.location)
            }
            notify()
            // A replayed receipt can predate another device's changes. Read current
            // stock; if refresh fails, disable further mutations until it succeeds.
            await load()
        } catch {
            guard session() == userSession else { return }
            if let stockError = error as? CellarBottleService.StockError, case .unavailable = stockError {
                pending[bottle.id] = nil
                await load()
                mutationError = stockError.localizedDescription
            } else {
                mutationError = "Couldn't confirm this change. Tap Retry on this bottle to finish the same request."
            }
        }
    }
}
