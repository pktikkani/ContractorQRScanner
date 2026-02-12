import Combine
import Foundation

class ScanHistoryManager: ObservableObject {
    static let shared = ScanHistoryManager()

    @Published private(set) var entries: [ScanHistoryEntry] = []

    private let storageKey = "scan_history"
    private let maxEntries = 500

    private init() {
        loadEntries()
    }

    func addEntry(_ entry: ScanHistoryEntry) {
        entries.insert(entry, at: 0)
        if entries.count > maxEntries {
            entries = Array(entries.prefix(maxEntries))
        }
        saveEntries()
    }

    func clearHistory() {
        entries.removeAll()
        saveEntries()
    }

    private func loadEntries() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        entries = (try? decoder.decode([ScanHistoryEntry].self, from: data)) ?? []
    }

    private func saveEntries() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(entries) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}
