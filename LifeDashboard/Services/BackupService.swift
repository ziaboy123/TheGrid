import Foundation
import SwiftData

enum BackupError: LocalizedError {
    case iCloudUnavailable
    case encodingFailed
    case writeFailed
    case readFailed
    case decodingFailed

    var errorDescription: String? {
        switch self {
        case .iCloudUnavailable:
            return "iCloud Drive isn't available yet. Sign into iCloud — and Xcode, for this development build — with your Apple ID, then try again."
        case .encodingFailed: return "Couldn't prepare your data for backup."
        case .writeFailed: return "Couldn't write the backup file."
        case .readFailed: return "Couldn't find a backup file to restore from."
        case .decodingFailed: return "That backup file looks corrupted or from an incompatible version."
        }
    }
}

private struct BackupPayload: Codable {
    var version = 1
    let exportedAt: Date
    let boards: [BackupBoard]
    let mailAccounts: [BackupMailAccount]
}

private struct BackupBoard: Codable {
    let uuid: UUID
    let title: String
    let order: Int
    let createdAt: Date
    let items: [BackupItem]
}

private struct BackupItem: Codable {
    let text: String
    let isChecklist: Bool
    let isChecked: Bool
    let isDivider: Bool
    let rtfData: Data?
    let order: Int
    let createdAt: Date
}

private struct BackupMailAccount: Codable {
    let uuid: UUID
    let email: String
    let provider: String
    let order: Int
}

/// Backs up Board/BoardItem data (and mail account *metadata* only — never the
/// Keychain password) to a JSON file in the app's iCloud Drive folder, visible
/// in the Files app. This is a simple file-based backup, not real-time sync —
/// it only updates when "Back Up Now" is tapped.
enum BackupService {
    private static let containerID = "iCloud.uk.co.daniyalzia.LifeDashboard"
    private static let backupFilename = "LifeDashboardBackup.json"
    private static let lastBackupDateKey = "lastBackupDate"

    static var isICloudAvailable: Bool {
        FileManager.default.url(forUbiquityContainerIdentifier: containerID) != nil
    }

    static var lastBackupDate: Date? {
        UserDefaults.standard.object(forKey: lastBackupDateKey) as? Date
    }

    private static func backupFileURL() throws -> URL {
        guard let containerURL = FileManager.default.url(forUbiquityContainerIdentifier: containerID) else {
            throw BackupError.iCloudUnavailable
        }
        let documentsURL = containerURL.appendingPathComponent("Documents", isDirectory: true)
        try? FileManager.default.createDirectory(at: documentsURL, withIntermediateDirectories: true)
        return documentsURL.appendingPathComponent(backupFilename)
    }

    @discardableResult
    static func backup(boards: [Board], mailAccounts: [MailAccount]) throws -> Date {
        let payload = BackupPayload(
            exportedAt: .now,
            boards: boards.map { board in
                BackupBoard(
                    uuid: board.uuid,
                    title: board.title,
                    order: board.order,
                    createdAt: board.createdAt,
                    items: (board.items ?? []).map { item in
                        BackupItem(
                            text: item.text,
                            isChecklist: item.isChecklist,
                            isChecked: item.isChecked,
                            isDivider: item.isDivider,
                            rtfData: item.rtfData,
                            order: item.order,
                            createdAt: item.createdAt
                        )
                    }
                )
            },
            mailAccounts: mailAccounts.map { account in
                BackupMailAccount(uuid: account.uuid, email: account.email, provider: account.provider.rawValue, order: account.order)
            }
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(payload) else {
            throw BackupError.encodingFailed
        }

        let url = try backupFileURL()
        do {
            try data.write(to: url, options: .atomic)
        } catch {
            throw BackupError.writeFailed
        }
        let now = Date.now
        UserDefaults.standard.set(now, forKey: lastBackupDateKey)
        return now
    }

    /// Additive restore — boards whose `uuid` already exists locally are
    /// skipped, so restoring the same backup twice doesn't duplicate data.
    /// Returns the number of boards actually imported.
    @discardableResult
    static func restore(into context: ModelContext, existingBoards: [Board]) throws -> Int {
        let url = try backupFileURL()
        guard let data = try? Data(contentsOf: url) else {
            throw BackupError.readFailed
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let payload = try? decoder.decode(BackupPayload.self, from: data) else {
            throw BackupError.decodingFailed
        }

        let existingUUIDs = Set(existingBoards.map { $0.uuid })
        var importedCount = 0

        for backupBoard in payload.boards where !existingUUIDs.contains(backupBoard.uuid) {
            let board = Board(title: backupBoard.title, order: backupBoard.order)
            board.uuid = backupBoard.uuid
            board.createdAt = backupBoard.createdAt
            context.insert(board)

            for backupItem in backupBoard.items {
                let item = BoardItem(text: backupItem.text, isChecklist: backupItem.isChecklist, order: backupItem.order)
                item.isChecked = backupItem.isChecked
                item.isDivider = backupItem.isDivider
                item.rtfData = backupItem.rtfData
                item.createdAt = backupItem.createdAt
                item.board = board
                context.insert(item)
            }
            importedCount += 1
        }
        return importedCount
    }
}
