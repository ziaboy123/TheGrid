import Foundation
import SwiftData

@Model
final class BoardItem {
    var text: String = ""
    var isChecklist: Bool = false
    var isChecked: Bool = false
    var isDivider: Bool = false
    var rtfData: Data?
    var order: Int = 0
    var createdAt: Date = Date.now
    var uuid: UUID = UUID()
    /// The original filename shown to the user (e.g. "receipt.jpg").
    var attachmentName: String?
    /// The actual filename on disk in Documents/Attachments/, UUID-based to
    /// avoid collisions between items that share an original filename.
    var attachmentStorageName: String?
    var board: Board?

    init(text: String, isChecklist: Bool = false, order: Int = 0) {
        self.text = text
        self.isChecklist = isChecklist
        self.isChecked = false
        self.order = order
        self.createdAt = .now
    }
}
