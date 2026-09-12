import Foundation
import SwiftData

@Model
final class Board {
    var title: String = ""
    var order: Int = 0
    var createdAt: Date = Date.now
    var uuid: UUID = UUID()
    var deletedAt: Date?
    var isPinned: Bool = false

    @Relationship(deleteRule: .cascade, inverse: \BoardItem.board)
    var items: [BoardItem]? = []

    init(title: String, order: Int = 0) {
        self.title = title
        self.order = order
        self.createdAt = .now
    }
}
