import SwiftUI

/// 독립 검색 세션 하나(헤더 + 결과 + 미리보기 + 상태바 + 삭제 플로우).
/// 화면 분할·다중 창에서 각 패널이 이 뷰 하나로 완결된다.
struct SearchPaneView: View {
    @ObservedObject var engine: SearchEngine
    /// 사이드바 없이 쓰이는 패널이면 헤더에 범위·종류 피커를 노출
    var showsFilterPickers: Bool = false
    /// 전역 단축키 호출 시 검색창 포커스를 받을 대표 패널인지
    var respondsToGlobalFocus: Bool = false

    @State private var selection: Set<SearchResult.ID> = []
    @FocusState private var searchFocused: Bool

    @State private var removalCandidates: [SearchResult] = []
    @State private var removalIsPermanent = false
    @State private var showRemovalConfirm = false
    @State private var showEmptyTrashConfirm = false
    @State private var failureCount: Int?
    @State private var emptyTrashError: String?

    var body: some View {
        GeometryReader { geometry in
            // 패널이 좁을 때는 미리보기 컬럼을 숨겨 리스트가 뭉개지지 않게 한다
            let showsPreviewColumn = geometry.size.width >= 660

            VStack(spacing: 0) {
                SearchHeaderView(
                    engine: engine,
                    searchFocused: $searchFocused,
                    showsFilterPickers: showsFilterPickers,
                    requestEmptyTrash: { showEmptyTrashConfirm = true }
                )
                Divider()
                HSplitView {
                    ResultListView(
                        engine: engine,
                        selection: $selection,
                        requestTrash: requestRemoval
                    )
                    if showsPreviewColumn {
                        if selectedResults.count > 1 {
                            MultiSelectionPane(
                                results: selectedResults,
                                permanentDelete: engine.showingTrash,
                                requestTrash: requestRemoval
                            )
                        } else if let selected = selectedResults.first {
                            PreviewPane(
                                result: selected,
                                permanentDelete: engine.showingTrash,
                                requestTrash: requestRemoval
                            )
                        }
                    }
                }
                Divider()
                StatusBarView(
                    engine: engine,
                    selectionCount: selectedResults.count,
                    selectionBytes: selectedResults.reduce(0) { $0 + ($1.size ?? 0) }
                )
            }
        }
        .onAppear { searchFocused = true }
        .focusedSceneValue(\.focusSearchAction) {
            searchFocused = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .qfFocusSearch)) { _ in
            if respondsToGlobalFocus {
                searchFocused = true
            }
        }
        .alert(
            removalIsPermanent ? "영구 삭제" : "휴지통으로 이동",
            isPresented: $showRemovalConfirm
        ) {
            Button("취소", role: .cancel) {}
            Button(removalIsPermanent ? "삭제" : "이동", role: .destructive) {
                performRemoval()
            }
        } message: {
            Text(removalConfirmMessage)
        }
        .alert("휴지통 비우기", isPresented: $showEmptyTrashConfirm) {
            Button("취소", role: .cancel) {}
            Button("비우기", role: .destructive) { performEmptyTrash() }
        } message: {
            Text("휴지통의 모든 항목을 영구적으로 삭제합니다. 이 동작은 되돌릴 수 없습니다.")
        }
        .alert(
            "일부 항목을 처리하지 못했습니다",
            isPresented: Binding(
                get: { failureCount != nil },
                set: { if !$0 { failureCount = nil } }
            )
        ) {
            Button("확인", role: .cancel) {}
        } message: {
            Text("\(failureCount ?? 0)개 항목을 처리하지 못했습니다. 권한이나 파일 상태를 확인해주세요.")
        }
        .alert(
            "휴지통을 비우지 못했습니다",
            isPresented: Binding(
                get: { emptyTrashError != nil },
                set: { if !$0 { emptyTrashError = nil } }
            )
        ) {
            Button("확인", role: .cancel) {}
        } message: {
            Text(emptyTrashError ?? "")
        }
    }

    private var selectedResults: [SearchResult] {
        engine.results.filter { selection.contains($0.id) }
    }

    private var removalConfirmMessage: String {
        let count = removalCandidates.count
        let bytes = removalCandidates.reduce(Int64(0)) { $0 + ($1.size ?? 0) }
        let sizeText = bytes > 0 ? " (합계 \(Formatters.size(bytes)))" : ""
        if removalIsPermanent {
            return "\(count)개 항목\(sizeText)을 영구적으로 삭제합니다. 이 동작은 되돌릴 수 없습니다."
        }
        return "\(count)개 항목\(sizeText)을 휴지통으로 이동합니다. 휴지통에서 복원할 수 있습니다."
    }

    private func requestRemoval(_ results: [SearchResult]) {
        guard !results.isEmpty else { return }
        removalCandidates = results
        removalIsPermanent = engine.showingTrash
        showRemovalConfirm = true
    }

    private func performRemoval() {
        let outcome = removalIsPermanent
            ? FileActions.deletePermanently(removalCandidates)
            : FileActions.trash(removalCandidates)
        // Spotlight 라이브 업데이트를 기다리지 않고 성공 항목을 즉시 리스트에서 제거
        engine.removeFromResults(ids: outcome.succeeded)
        selection.subtract(outcome.succeeded)
        removalCandidates = []
        if outcome.failures > 0 {
            failureCount = outcome.failures
        }
    }

    private func performEmptyTrash() {
        emptyTrashError = FileActions.emptyTrash()
        selection = []
        engine.refresh()
    }
}
