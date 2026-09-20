import Foundation

enum SlotCount: Int, CaseIterable, Codable {
    case four = 4
    case five = 5
    case six  = 6

    var columns: Int { self == .four ? 2 : 3 }
    var label: String { "\(rawValue) sources" }
}

@Observable @MainActor
final class AppSettings {
    static let shared = AppSettings()

    var slotCount: SlotCount = .six

    private init() { load() }

    func load() {
        let d = UserDefaults.standard
        slotCount = SlotCount(rawValue: d.integer(forKey: "s_slotcount")) ?? .six
    }

    func save() {
        let d = UserDefaults.standard
        d.set(slotCount.rawValue, forKey: "s_slotcount")
    }
}
