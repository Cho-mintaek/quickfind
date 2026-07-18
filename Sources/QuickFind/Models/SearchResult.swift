import Foundation

/// NSMetadataItem 에서 UI 표시에 필요한 값만 뽑아낸 불변 스냅샷.
struct SearchResult: Identifiable, Hashable {
    let id: String
    let url: URL
    let name: String
    let parentPath: String
    let size: Int64?
    let modified: Date?
    let created: Date?
    let lastUsed: Date?
    let kind: String?
    let isDirectory: Bool

    init?(item: NSMetadataItem) {
        guard let path = item.value(forAttribute: NSMetadataItemPathKey) as? String else {
            return nil
        }
        let url = URL(fileURLWithPath: path)
        self.id = path
        self.url = url
        self.name = (item.value(forAttribute: NSMetadataItemDisplayNameKey) as? String)
            ?? url.lastPathComponent
        self.parentPath = url.deletingLastPathComponent().path
        self.size = (item.value(forAttribute: NSMetadataItemFSSizeKey) as? NSNumber)?.int64Value
        self.modified = item.value(forAttribute: NSMetadataItemFSContentChangeDateKey) as? Date
        self.created = item.value(forAttribute: NSMetadataItemContentCreationDateKey) as? Date
        self.lastUsed = item.value(forAttribute: NSMetadataItemLastUsedDateKey) as? Date
        self.kind = item.value(forAttribute: NSMetadataItemKindKey) as? String

        let contentType = item.value(forAttribute: NSMetadataItemContentTypeKey) as? String
        self.isDirectory = contentType == "public.folder"
    }

    /// 휴지통 등 Spotlight 인덱스 밖의 파일을 직접 읽어 만든다
    init?(trashItemAt url: URL) {
        let keys: Set<URLResourceKey> = [
            .fileSizeKey, .totalFileSizeKey, .contentModificationDateKey,
            .creationDateKey, .contentAccessDateKey, .isDirectoryKey,
            .localizedTypeDescriptionKey, .localizedNameKey,
        ]
        guard let values = try? url.resourceValues(forKeys: keys) else { return nil }
        self.id = url.path
        self.url = url
        self.name = values.localizedName ?? url.lastPathComponent
        self.parentPath = url.deletingLastPathComponent().path
        self.size = (values.totalFileSize ?? values.fileSize).map(Int64.init)
        self.modified = values.contentModificationDate
        self.created = values.creationDate
        self.lastUsed = values.contentAccessDate
        self.kind = values.localizedTypeDescription
        self.isDirectory = values.isDirectory ?? false
    }

    /// 실제 디스크 점유 크기. Spotlight 의 크기(kMDItemFSSize)는 논리 크기라
    /// Docker.raw 같은 sparse 파일은 크게 부풀려 보인다.
    func allocatedSize() -> Int64? {
        guard !isDirectory else { return nil }
        let values = try? url.resourceValues(forKeys: [.totalFileAllocatedSizeKey])
        return values?.totalFileAllocatedSize.map(Int64.init)
    }

    /// 홈 디렉토리를 ~ 로 줄인 표시용 경로
    var displayParentPath: String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if parentPath.hasPrefix(home) {
            return "~" + parentPath.dropFirst(home.count)
        }
        return parentPath
    }
}
