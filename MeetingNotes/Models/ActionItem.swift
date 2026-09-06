import Foundation
import SwiftData

/// One action item extracted from a transcript. Belongs to exactly one `Note`.
@Model
final class ActionItem {
    var id: UUID
    var text: String
    var done: Bool

    init(id: UUID = UUID(), text: String, done: Bool = false) {
        self.id = id
        self.text = text
        self.done = done
    }
}
