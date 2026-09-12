import Foundation
import SwiftData

enum MailProvider: String, CaseIterable, Identifiable, Codable {
    case icloud

    var id: String { rawValue }

    var displayName: String { "iCloud" }

    var imapHost: String { "imap.mail.me.com" }

    var imapPort: UInt16 { 993 }
}

@Model
final class MailAccount {
    var email: String = ""
    var providerRaw: String = MailProvider.icloud.rawValue
    var order: Int = 0
    var uuid: UUID = UUID()

    var provider: MailProvider {
        get { MailProvider(rawValue: providerRaw) ?? .icloud }
        set { providerRaw = newValue.rawValue }
    }

    init(email: String, provider: MailProvider, order: Int = 0) {
        self.email = email
        self.providerRaw = provider.rawValue
        self.order = order
    }
}
