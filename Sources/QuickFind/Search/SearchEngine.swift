import Foundation
import Combine

/// Spotlight 인덱스(NSMetadataQuery) 기반 실시간 검색 엔진.
/// 조건이 바뀔 때마다 쿼리를 재시작하고, gathering 완료 + live update 를
/// 모두 반영한다. 입력 타이핑만 디바운스(250ms)한다.
@MainActor
final class SearchEngine: ObservableObject {

    static let maxResults = 500

    @Published var queryText: String = "" {
        didSet { if queryText != oldValue { scheduleRestart(debounced: true) } }
    }
    @Published var category: SearchCategory = .all {
        didSet {
            guard category != oldValue else { return }
            // 종류를 바꾸면 검색 범위·정리 프리셋·휴지통 선택을 초기 상태로 되돌린다
            if cleanupPreset != nil { cleanupPreset = nil }
            if showingTrash { showingTrash = false }
            if scope != .home { scope = .home }
            scheduleRestart(debounced: false)
        }
    }
    @Published var scope: SearchScope = .home {
        didSet { if scope != oldValue { scheduleRestart(debounced: false) } }
    }
    @Published var sortOption: SortOption = .modifiedDesc {
        didSet { if sortOption != oldValue { scheduleRestart(debounced: false) } }
    }
    @Published var searchContents: Bool = false {
        didSet { if searchContents != oldValue { scheduleRestart(debounced: false) } }
    }
    /// 저장공간 정리 프리셋. 선택되면 검색어 없이도 조회하고 기본 정렬을 적용한다.
    @Published var cleanupPreset: CleanupPreset? {
        didSet {
            guard cleanupPreset != oldValue else { return }
            if let preset = cleanupPreset {
                sortOption = preset.defaultSort
                if showingTrash { showingTrash = false }
            }
            scheduleRestart(debounced: false)
        }
    }
    /// 휴지통 보기. Spotlight 는 휴지통을 인덱싱하지 않으므로 폴더를 직접 읽는다.
    @Published var showingTrash: Bool = false {
        didSet {
            guard showingTrash != oldValue else { return }
            if showingTrash {
                cleanupPreset = nil
            }
            scheduleRestart(debounced: false)
        }
    }

    @Published private(set) var results: [SearchResult] = []
    @Published private(set) var isSearching = false
    @Published private(set) var totalCount = 0
    @Published private(set) var lastDuration: TimeInterval?
    /// 휴지통 폴더를 읽지 못함 (전체 디스크 접근 권한 필요)
    @Published private(set) var trashAccessDenied = false

    var hasQuery: Bool {
        !queryText.trimmingCharacters(in: .whitespaces).isEmpty
    }

    /// 검색어·정리 프리셋·휴지통 보기 중 하나라도 있으면 조회가 활성 상태
    var isActive: Bool {
        hasQuery || cleanupPreset != nil || showingTrash
    }

    /// 표시 중인 결과의 합계 크기(바이트)
    var displayedBytes: Int64 {
        results.reduce(0) { $0 + ($1.size ?? 0) }
    }

    private var query: NSMetadataQuery?
    private var observers: [NSObjectProtocol] = []
    private var debounceTask: Task<Void, Never>?
    private var startedAt: Date?
    private var probeObserver: NSObjectProtocol?

    init() {
        // 보호 폴더 접근 프로브가 끝나면 진행 중인 검색을 재시작해
        // 다운로드·데스크탑·문서 결과가 빠지지 않게 한다
        probeObserver = NotificationCenter.default.addObserver(
            forName: .qfFolderAccessProbed, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.isActive else { return }
                self.scheduleRestart(debounced: false)
            }
        }
    }

    private func scheduleRestart(debounced: Bool) {
        debounceTask?.cancel()
        debounceTask = Task { [weak self] in
            if debounced {
                try? await Task.sleep(nanoseconds: 250_000_000)
            }
            guard !Task.isCancelled else { return }
            // NSMetadataQuery.start()는 Swift Concurrency 잡 컨텍스트가 아닌
            // 일반 런루프 콜아웃에서 호출해야 앱 환경에서 정상 동작한다
            DispatchQueue.main.async { self?.restart() }
        }
    }

    /// 현재 조건으로 다시 조회 (휴지통 비우기 등 외부 변경 후 갱신용)
    func refresh() {
        scheduleRestart(debounced: false)
    }

    /// 삭제 성공한 항목을 결과에서 즉시 제거한다.
    /// Spotlight 인덱스 갱신(라이브 업데이트)을 기다리면 수 초간 남아 보인다.
    func removeFromResults(ids: Set<SearchResult.ID>) {
        guard !ids.isEmpty else { return }
        let remaining = results.filter { !ids.contains($0.id) }
        totalCount = max(0, totalCount - (results.count - remaining.count))
        results = remaining
    }

    private func restart() {
        stop()

        if showingTrash {
            loadTrashContents()
            return
        }

        let trimmed = queryText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty || cleanupPreset != nil else {
            results = []
            totalCount = 0
            lastDuration = nil
            isSearching = false
            return
        }

        let q = NSMetadataQuery()
        q.predicate = buildPredicate(for: trimmed)
        q.searchScopes = (cleanupPreset?.scopeOverride ?? scope).scopes
        q.sortDescriptors = sortOption.sortDescriptors
        q.notificationBatchingInterval = 0.15

        let nc = NotificationCenter.default
        observers.append(nc.addObserver(
            forName: .NSMetadataQueryDidFinishGathering, object: q, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.harvest(finished: true) }
        })
        observers.append(nc.addObserver(
            forName: .NSMetadataQueryDidUpdate, object: q, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.harvest(finished: false) }
        })

        // 초기 gathering 중에도 결과를 스트리밍해 첫 결과가 즉시 보이게 한다
        observers.append(nc.addObserver(
            forName: .NSMetadataQueryGatheringProgress, object: q, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.harvest(finished: false) }
        })

        query = q
        startedAt = Date()
        isSearching = true
        q.start()
    }

    private func harvest(finished: Bool) {
        guard let q = query else { return }
        q.disableUpdates()
        defer { q.enableUpdates() }

        let count = q.resultCount
        totalCount = count

        var mapped: [SearchResult] = []
        mapped.reserveCapacity(min(count, Self.maxResults))
        for index in 0..<min(count, Self.maxResults) {
            if let item = q.result(at: index) as? NSMetadataItem,
               let result = SearchResult(item: item) {
                mapped.append(result)
            }
        }
        results = mapped

        if finished {
            isSearching = false
            if let startedAt {
                lastDuration = Date().timeIntervalSince(startedAt)
            }
        }
    }

    private func buildPredicate(for text: String) -> NSPredicate {
        var predicates: [NSPredicate] = []

        if !text.isEmpty {
            let namePredicate = NSCompoundPredicate(orPredicateWithSubpredicates: [
                NSPredicate(format: "%K CONTAINS[cd] %@", NSMetadataItemFSNameKey, text),
                NSPredicate(format: "%K CONTAINS[cd] %@", NSMetadataItemDisplayNameKey, text),
            ])
            if searchContents {
                predicates.append(NSCompoundPredicate(orPredicateWithSubpredicates: [
                    namePredicate,
                    NSPredicate(format: "kMDItemTextContent CONTAINS[cd] %@", text),
                ]))
            } else {
                predicates.append(namePredicate)
            }
        }
        if let preset = cleanupPreset {
            predicates.append(preset.predicate)
        }
        if let typePredicate = category.contentTypePredicate {
            predicates.append(typePredicate)
        }
        // NSMetadataQuery 는 하위 조건이 1개인 복합 predicate 를 거부한다
        if predicates.count == 1 {
            return predicates[0]
        }
        return NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
    }

    private func stop() {
        if let q = query {
            q.stop()
        }
        for observer in observers {
            NotificationCenter.default.removeObserver(observer)
        }
        observers = []
        query = nil
    }

    /// 휴지통 폴더를 직접 읽어 결과로 변환한다 (검색어 필터·정렬 로컬 적용)
    private func loadTrashContents() {
        let started = Date()
        let trimmed = queryText.trimmingCharacters(in: .whitespaces)
        let keys: [URLResourceKey] = [
            .fileSizeKey, .totalFileSizeKey, .contentModificationDateKey,
            .creationDateKey, .contentAccessDateKey, .isDirectoryKey,
            .localizedTypeDescriptionKey, .localizedNameKey,
        ]
        let urls: [URL]
        do {
            urls = try FileManager.default.contentsOfDirectory(
                at: FileActions.trashURL, includingPropertiesForKeys: keys,
                options: [.skipsSubdirectoryDescendants]
            )
            trashAccessDenied = false
        } catch {
            trashAccessDenied = true
            results = []
            totalCount = 0
            isSearching = false
            lastDuration = nil
            return
        }

        var items = urls.compactMap { SearchResult(trashItemAt: $0) }
        if !trimmed.isEmpty {
            items = items.filter { $0.name.localizedCaseInsensitiveContains(trimmed) }
        }
        items.sort(by: sortComparator)

        totalCount = items.count
        results = Array(items.prefix(Self.maxResults))
        isSearching = false
        lastDuration = Date().timeIntervalSince(started)
    }

    private var sortComparator: (SearchResult, SearchResult) -> Bool {
        switch sortOption {
        case .modifiedDesc:
            return { ($0.modified ?? .distantPast) > ($1.modified ?? .distantPast) }
        case .nameAsc:
            return { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        case .sizeDesc:
            return { ($0.size ?? 0) > ($1.size ?? 0) }
        case .lastUsedAsc:
            return { ($0.lastUsed ?? .distantPast) < ($1.lastUsed ?? .distantPast) }
        }
    }
}
