import SwiftUI
import AppKit

struct ResultListView: View {
    @ObservedObject var engine: SearchEngine
    @Binding var selection: Set<SearchResult.ID>
    let requestTrash: ([SearchResult]) -> Void

    /// ⇧클릭 범위 선택의 기준점
    @State private var selectionAnchor: SearchResult.ID?

    var body: some View {
        Group {
            if !engine.isActive {
                EmptyStateView.initial
            } else if engine.showingTrash && engine.trashAccessDenied {
                EmptyStateView.trashAccessDenied { engine.refresh() }
            } else if engine.results.isEmpty && engine.isSearching {
                EmptyStateView.loading
            } else if engine.results.isEmpty && engine.showingTrash && !engine.hasQuery {
                EmptyStateView.trashEmpty
            } else if engine.results.isEmpty {
                EmptyStateView.noResults(query: engine.queryText)
            } else {
                resultList
            }
        }
        .frame(minWidth: 340, maxWidth: .infinity, maxHeight: .infinity)
        // 리스트가 아직 마운트되기 전의 결과 변화도 놓치지 않도록 상위에 둔다
        .onChange(of: engine.results) { _, newResults in
            let ids = Set(newResults.map(\.id))
            let surviving = selection.intersection(ids)
            if surviving.isEmpty {
                selection = newResults.first.map { [$0.id] } ?? []
                selectionAnchor = newResults.first?.id
            } else if surviving != selection {
                selection = surviving
            }
        }
    }

    private var resultList: some View {
        List(selection: $selection) {
            ForEach(engine.results) { result in
                ResultRowView(
                    result: result,
                    showLastUsed: engine.sortOption == .lastUsedAsc
                )
                .tag(result.id)
                // onTapGesture(count: 2)는 List 의 단일 클릭 선택을 삼키므로
                // 단일 클릭(교체/⌘토글/⇧범위)을 simultaneousGesture 로 직접 처리한다
                .gesture(TapGesture(count: 2).onEnded {
                    FileActions.open(result)
                })
                .simultaneousGesture(TapGesture().onEnded {
                    handleClick(on: result)
                })
                .onDrag {
                    NSItemProvider(object: result.url as NSURL)
                }
                .contextMenu {
                    let targets = actionTargets(for: result)
                    let countPrefix = targets.count > 1 ? "\(targets.count)개 항목 " : ""
                    Button("\(countPrefix)열기") {
                        targets.forEach(FileActions.open)
                    }
                    Button("Finder에서 보기") { FileActions.revealInFinder(targets) }
                    Divider()
                    Button("경로 복사") { FileActions.copyPath(result) }
                    Button("파일 복사") { FileActions.copyFile(result) }
                    Divider()
                    Button(
                        engine.showingTrash
                            ? "\(countPrefix)영구 삭제"
                            : "\(countPrefix)휴지통으로 이동",
                        role: .destructive
                    ) {
                        requestTrash(targets)
                    }
                }
            }
        }
        .listStyle(.inset)
        .onKeyPress(phases: .down) { press in
            handleKey(press)
        }
    }

    private func handleClick(on result: SearchResult) {
        let modifiers = NSEvent.modifierFlags
        if modifiers.contains(.command) {
            if selection.contains(result.id) {
                selection.remove(result.id)
            } else {
                selection.insert(result.id)
                selectionAnchor = result.id
            }
        } else if modifiers.contains(.shift), let anchor = selectionAnchor,
                  let anchorIndex = engine.results.firstIndex(where: { $0.id == anchor }),
                  let clickedIndex = engine.results.firstIndex(where: { $0.id == result.id }) {
            let range = min(anchorIndex, clickedIndex)...max(anchorIndex, clickedIndex)
            selection = Set(engine.results[range].map(\.id))
        } else {
            selection = [result.id]
            selectionAnchor = result.id
        }
    }

    private func handleKey(_ press: KeyPress) -> KeyPress.Result {
        let selected = selectedResults
        guard !selected.isEmpty else { return .ignored }
        if press.key == .return {
            if press.modifiers.contains(.command) {
                FileActions.revealInFinder(selected)
            } else {
                selected.forEach(FileActions.open)
            }
            return .handled
        }
        if press.key == .delete && press.modifiers.contains(.command) {
            requestTrash(selected)
            return .handled
        }
        return .ignored
    }

    private var selectedResults: [SearchResult] {
        engine.results.filter { selection.contains($0.id) }
    }

    /// 컨텍스트 메뉴 대상: 우클릭한 행이 선택에 포함되면 선택 전체, 아니면 그 행만
    private func actionTargets(for result: SearchResult) -> [SearchResult] {
        if selection.contains(result.id) {
            return selectedResults
        }
        return [result]
    }
}
