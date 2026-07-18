import SwiftUI

struct ResultRowView: View {
    let result: SearchResult
    var showLastUsed: Bool = false

    /// sparse 파일이면 논리 크기와 함께 실제 점유를 보여준다
    @State private var allocated: Int64?

    var body: some View {
        HStack(spacing: 10) {
            FileIconView(url: result.url, side: 34)

            VStack(alignment: .leading, spacing: 2) {
                Text(result.name)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                Text(result.displayParentPath)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 12)

            VStack(alignment: .trailing, spacing: 2) {
                Text(sizeText)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                if showLastUsed {
                    Text("사용: \(Formatters.relative(result.lastUsed))")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                } else {
                    Text(Formatters.relative(result.modified))
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.vertical, 3)
        .contentShape(Rectangle())
        .task(id: result.id) {
            allocated = result.allocatedSize()
        }
    }

    private var sizeText: String {
        if result.isDirectory { return "폴더" }
        let logical = Formatters.size(result.size)
        // 실제 점유가 논리 크기의 90% 미만이면(sparse 등) 함께 표시
        if let allocated, let size = result.size, size > 0,
           Double(allocated) < Double(size) * 0.9 {
            return "\(logical) (실제 \(Formatters.size(allocated)))"
        }
        return logical
    }
}
