import Foundation

/// 검색 범위. NSMetadataQuery.searchScopes 값으로 변환된다.
enum SearchScope: String, CaseIterable, Identifiable {
    case computer
    case home
    case desktop
    case documents
    case downloads

    var id: String { rawValue }

    var label: String {
        switch self {
        case .computer: return tr("전체 Mac", "Entire Mac")
        case .home: return tr("홈 폴더", "Home")
        case .desktop: return tr("데스크탑", "Desktop")
        case .documents: return tr("문서", "Documents")
        case .downloads: return tr("다운로드", "Downloads")
        }
    }

    var systemImage: String {
        switch self {
        case .computer: return "desktopcomputer"
        case .home: return "house"
        case .desktop: return "menubar.dock.rectangle"
        case .documents: return "folder.badge.person.crop"
        case .downloads: return "arrow.down.circle"
        }
    }

    var scopes: [Any] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        switch self {
        case .computer: return [NSMetadataQueryLocalComputerScope]
        case .home: return [home]
        case .desktop: return [home.appendingPathComponent("Desktop")]
        case .documents: return [home.appendingPathComponent("Documents")]
        case .downloads: return [home.appendingPathComponent("Downloads")]
        }
    }
}
