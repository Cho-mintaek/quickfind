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
        case .modifiedDesc: return "최근 수정순"
        case .nameAsc: return "이름순"
        case .sizeDesc: return "크기순"
        case .lastUsedAsc: return "오래 사용 안 한 순"
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
