import Foundation

/// 저장공간 정리용 사전 정의 검색. 검색어 없이도 조건만으로 조회한다.
enum CleanupPreset: String, CaseIterable, Identifiable {
    case largeFiles
    case unusedFiles
    case oldDownloads
    case diskImages

    var id: String { rawValue }

    var label: String {
        switch self {
        case .largeFiles: return tr("대용량 파일", "Large Files")
        case .unusedFiles: return tr("오래 사용 안 한 파일", "Unused Files")
        case .oldDownloads: return tr("오래된 다운로드", "Old Downloads")
        case .diskImages: return tr("설치 파일·디스크 이미지", "Installers & Disk Images")
        }
    }

    var systemImage: String {
        switch self {
        case .largeFiles: return "internaldrive"
        case .unusedFiles: return "clock.arrow.circlepath"
        case .oldDownloads: return "arrow.down.circle.dotted"
        case .diskImages: return "opticaldiscdrive"
        }
    }

    var help: String {
        switch self {
        case .largeFiles: return tr("100MB 이상 파일을 크기순으로 보여줍니다", "Files over 100MB, sorted by size")
        case .unusedFiles: return tr("1년 이상 열지 않은 1MB 이상 파일", "Files over 1MB not opened in a year")
        case .oldDownloads: return tr("다운로드 폴더에 6개월 이상 방치된 파일", "Files sitting in Downloads for 6+ months")
        case .diskImages: return tr("dmg·pkg·iso 등 설치 후 지워도 되는 파일", "dmg, pkg, iso — usually safe to delete after install")
        }
    }

    /// 프리셋 선택 시 함께 적용할 기본 정렬
    var defaultSort: SortOption {
        switch self {
        case .unusedFiles: return .lastUsedAsc
        default: return .sizeDesc
        }
    }

    /// 프리셋이 검색 범위를 강제하는 경우 (예: 오래된 다운로드)
    var scopeOverride: SearchScope? {
        self == .oldDownloads ? .downloads : nil
    }

    var predicate: NSPredicate {
        let oneYearAgo = Date(timeIntervalSinceNow: -365 * 24 * 3600) as NSDate
        let sixMonthsAgo = Date(timeIntervalSinceNow: -182 * 24 * 3600) as NSDate
        switch self {
        case .largeFiles:
            return NSPredicate(format: "kMDItemFSSize >= 100000000")
        case .unusedFiles:
            return NSCompoundPredicate(andPredicateWithSubpredicates: [
                NSPredicate(format: "kMDItemLastUsedDate < %@", oneYearAgo),
                NSPredicate(format: "kMDItemFSSize >= 1000000"),
            ])
        case .oldDownloads:
            return NSPredicate(format: "kMDItemDateAdded < %@", sixMonthsAgo)
        case .diskImages:
            return NSCompoundPredicate(orPredicateWithSubpredicates: [
                NSPredicate(format: "kMDItemContentTypeTree == 'com.apple.disk-image'"),
                NSPredicate(format: "kMDItemContentTypeTree == 'com.apple.installer-package-archive'"),
                NSPredicate(format: "kMDItemContentTypeTree == 'public.iso-image'"),
            ])
        }
    }
}
