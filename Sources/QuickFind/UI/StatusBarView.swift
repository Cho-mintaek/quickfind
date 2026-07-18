import SwiftUI

struct StatusBarView: View {
    @ObservedObject var engine: SearchEngine
    var selectionCount: Int = 0
    var selectionBytes: Int64 = 0

    var body: some View {
        HStack(spacing: 8) {
            if engine.isActive {
                Text(resultSummary)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                if engine.displayedBytes > 0 {
                    Text("·")
                        .foregroundStyle(.tertiary)
                    Text(tr("합계 ", "Total ") + Formatters.size(engine.displayedBytes))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                if let duration = engine.lastDuration {
                    Text("·")
                        .foregroundStyle(.tertiary)
                    Text(String(format: tr("%.2f초", "%.2fs"), duration))
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
                if selectionCount > 1 {
                    Text("·")
                        .foregroundStyle(.tertiary)
                    Text(tr("\(Formatters.count(selectionCount))개 선택 (\(Formatters.size(selectionBytes)))", "\(Formatters.count(selectionCount)) selected (\(Formatters.size(selectionBytes)))"))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.accentColor)
                }
            } else {
                Text(tr("검색 범위: ", "Scope: ") + engine.scope.label)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(tr("↩ 열기 · ⌘↩ Finder · ⌘⌫ 휴지통 · ⌘/⇧클릭 다중 선택", "↩ Open · ⌘↩ Finder · ⌘⌫ Trash · ⌘/⇧click Multi-select"))
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(.bar)
    }

    private var resultSummary: String {
        let total = engine.totalCount
        let shown = engine.results.count
        if total > shown {
            return tr("\(Formatters.count(total))개 중 \(Formatters.count(shown))개 표시", "Showing \(Formatters.count(shown)) of \(Formatters.count(total))")
        }
        return tr("\(Formatters.count(total))개 결과", "\(Formatters.count(total)) results")
    }
}
