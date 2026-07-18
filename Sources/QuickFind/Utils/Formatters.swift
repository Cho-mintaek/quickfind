import Foundation

enum Formatters {
    static let fileSize: ByteCountFormatter = {
        let f = ByteCountFormatter()
        f.countStyle = .file
        return f
    }()

    static let dateTime: DateFormatter = {
        let f = DateFormatter()
        f.locale = .autoupdatingCurrent
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    static let relativeDate: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.locale = .autoupdatingCurrent
        f.unitsStyle = .short
        return f
    }()

    static let count: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        return f
    }()

    static func size(_ bytes: Int64?) -> String {
        guard let bytes else { return "—" }
        return fileSize.string(fromByteCount: bytes)
    }

    static func relative(_ date: Date?) -> String {
        guard let date else { return "—" }
        return relativeDate.localizedString(for: date, relativeTo: Date())
    }

    static func absolute(_ date: Date?) -> String {
        guard let date else { return "—" }
        return dateTime.string(from: date)
    }

    static func count(_ value: Int) -> String {
        count.string(from: NSNumber(value: value)) ?? String(value)
    }
}
