import Foundation

/// Stores attachment bytes in the app's own Documents/Attachments/ folder
/// (not the shared App Group — attachments are app-only, no need for a
/// widget to see them). Files are named by the owning BoardItem's uuid to
/// avoid collisions between items that share an original filename.
enum AttachmentService {
    private static var attachmentsDirectory: URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Attachments", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    @discardableResult
    static func save(data: Data, originalName: String, uuid: UUID) -> String {
        let ext = (originalName as NSString).pathExtension
        let storageName = ext.isEmpty ? uuid.uuidString : "\(uuid.uuidString).\(ext)"
        let url = attachmentsDirectory.appendingPathComponent(storageName)
        try? data.write(to: url, options: .atomic)
        return storageName
    }

    static func url(for storageName: String) -> URL {
        attachmentsDirectory.appendingPathComponent(storageName)
    }

    static func delete(storageName: String) {
        try? FileManager.default.removeItem(at: url(for: storageName))
    }
}
