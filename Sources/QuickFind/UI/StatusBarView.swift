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
                    Text("합계 \(Formatters.size(engine.displayedBytes))")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                if let duration = engine.lastDuration {
                    Text("·")
                        .foregroundStyle(.tertiary)
                    Text(String(format: "%.2f초", duration))
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
                if selectionCount > 1 {
                    Text("·")
                        .foregroundStyle(.tertiary)
                    Text("\(Formatters.count(selectionCount))개 선택 (\(Formatters.size(selectionBytes)))")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.accentColor)
                }
            } else {
                Text("검색 범위: \(engine.scope.label)")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text("↩ 열기 · ⌘↩ Finder · ⌘⌫ 휴지통 · ⌘/⇧클릭 다중 선택")
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
            return "\(Formatters.count(total))개 중 \(Formatters.count(shown))개 표시"
        }
        return "\(Formatters.count(total))개 결과"
    }
}
