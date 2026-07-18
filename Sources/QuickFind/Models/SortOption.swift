import Foundation

/// 결과 정렬. NSMetadataQuery.sortDescriptors 로 전달되어
/// 전체 결과 집합 기준으로 정렬된 뒤 상한(maxResults)만큼 표시된다.
enum SortOption: String, CaseIterable, Identifiable {
    case modifiedDesc
    case nameAsc
    case sizeDesc
    case lastUsedAsc

    var id: String { rawValue }

    var label: String {
        switch self {
        case .modifiedDesc: return tr("최근 수정순", "Recently Modified")
        case .nameAsc: return tr("이름순", "Name")
        case .sizeDesc: return tr("크기순", "Size")
        case .lastUsedAsc: return tr("오래 사용 안 한 순", "Least Recently Used")
        }
    }

    var sortDescriptors: [NSSortDescriptor] {
        switch self {
        case .modifiedDesc:
            return [NSSortDescriptor(key: NSMetadataItemFSContentChangeDateKey, ascending: false)]
        case .nameAsc:
            return [NSSortDescriptor(key: NSMetadataItemFSNameKey, ascending: true)]
        case .sizeDesc:
            return [NSSortDescriptor(key: NSMetadataItemFSSizeKey, ascending: false)]
        case .lastUsedAsc:
            return [NSSortDescriptor(key: NSMetadataItemLastUsedDateKey, ascending: true)]
        }
    }
}
