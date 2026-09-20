import Foundation

struct NDISource: Identifiable, Hashable, Sendable, Codable {
    let id: UUID
    let name: String
    let urlAddress: String

    init(name: String, urlAddress: String) {
        self.id = UUID()
        self.name = name
        self.urlAddress = urlAddress
    }

    func hash(into hasher: inout Hasher) { hasher.combine(name) }
    static func == (lhs: NDISource, rhs: NDISource) -> Bool { lhs.name == rhs.name }
}
