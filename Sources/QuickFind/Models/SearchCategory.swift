import Foundation

/// 사이드바에서 선택하는 파일 종류 필터.
/// Spotlight 의 kMDItemContentTypeTree(UTI 계층)로 매칭한다.
enum SearchCategory: String, CaseIterable, Identifiable {
    case all
    case folder
    case document
    case pdf
    case image
    case video
    case audio
    case archive
    case application

    var id: String { rawValue }

    var label: String {
        switch self {
        case .all: return tr("전체", "All")
        case .folder: return tr("폴더", "Folders")
        case .document: return tr("문서", "Documents")
        case .pdf: return "PDF"
        case .image: return tr("이미지", "Images")
        case .video: return tr("동영상", "Videos")
        case .audio: return tr("음악", "Music")
        case .archive: return tr("압축 파일", "Archives")
        case .application: return tr("응용 프로그램", "Applications")
        }
    }

    var systemImage: String {
        switch self {
        case .all: return "square.grid.2x2"
        case .folder: return "folder"
        case .document: return "doc.text"
        case .pdf: return "doc.richtext"
        case .image: return "photo"
        case .video: return "film"
        case .audio: return "music.note"
        case .archive: return "archivebox"
        case .application: return "app.badge"
        }
    }

    /// nil 이면 종류 제한 없음(전체)
    var contentTypePredicate: NSPredicate? {
        func tree(_ uti: String) -> NSPredicate {
            NSPredicate(format: "kMDItemContentTypeTree == %@", uti)
        }
        switch self {
        case .all:
            return nil
        case .folder:
            return tree("public.folder")
        case .document:
            return NSCompoundPredicate(orPredicateWithSubpredicates: [
                tree("public.text"),
                tree("public.composite-content"),
                tree("public.presentation"),
                tree("public.spreadsheet"),
            ])
        case .pdf:
            return tree("com.adobe.pdf")
        case .image:
            return tree("public.image")
        case .video:
            return tree("public.movie")
        case .audio:
            return tree("public.audio")
        case .archive:
            return tree("public.archive")
        case .application:
            return tree("com.apple.application")
        }
    }
}
