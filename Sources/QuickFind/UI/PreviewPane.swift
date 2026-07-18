import SwiftUI
import Quartz

/// 여러 항목 선택 시 요약 패널: 개수·합계 용량 + 일괄 동작
struct MultiSelectionPane: View {
    let results: [SearchResult]
    var permanentDelete: Bool = false
    let requestTrash: ([SearchResult]) -> Void

    private var totalBytes: Int64 {
        results.reduce(0) { $0 + ($1.size ?? 0) }
    }

    var body: some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: "square.stack.3d.up.fill")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(.secondary)
            Text("\(Formatters.count(results.count))개 항목 선택됨")
                .font(.system(size: 15, weight: .semibold))
            Text("합계 \(Formatters.size(totalBytes))")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
            Spacer()

            VStack(spacing: 8) {
                Button {
                    FileActions.revealInFinder(results)
                } label: {
                    Label("Finder에서 보기", systemImage: "folder")
                        .frame(maxWidth: .infinity)
                }
                Button(role: .destructive) {
                    requestTrash(results)
                } label: {
                    Label(
                        permanentDelete ? "영구 삭제" : "휴지통으로 이동",
                        systemImage: permanentDelete ? "trash.slash" : "trash"
                    )
                    .frame(maxWidth: .infinity)
                }
                .tint(.red)
            }
            .controlSize(.regular)
            .padding(12)
        }
        .frame(minWidth: 260, idealWidth: 320, maxWidth: 420)
    }
}

/// 우측 미리보기 패널: Quick Look 미리보기 + 파일 메타데이터 + 동작 버튼
struct PreviewPane: View {
    let result: SearchResult
    var permanentDelete: Bool = false
    let requestTrash: ([SearchResult]) -> Void

    @State private var allocated: Int64?

    var body: some View {
        VStack(spacing: 0) {
            QuickLookPreview(url: result.url)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text(result.name)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(2)

                Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 4) {
                    metadataRow(label: "종류", value: result.kind ?? "—")
                    metadataRow(label: "크기", value: result.isDirectory ? "폴더" : Formatters.size(result.size))
                    if let allocated {
                        metadataRow(label: "실제 점유", value: Formatters.size(allocated))
                    }
                    metadataRow(label: "생성일", value: Formatters.absolute(result.created))
                    metadataRow(label: "수정일", value: Formatters.absolute(result.modified))
                    metadataRow(label: "마지막 사용", value: Formatters.absolute(result.lastUsed))
                    metadataRow(label: "위치", value: result.displayParentPath)
                }

                Grid(horizontalSpacing: 8, verticalSpacing: 8) {
                    GridRow {
                        Button {
                            FileActions.open(result)
                        } label: {
                            Label("열기", systemImage: "arrow.up.forward.app")
                                .frame(maxWidth: .infinity)
                        }
                        Button {
                            FileActions.revealInFinder(result)
                        } label: {
                            Label("Finder에서 보기", systemImage: "folder")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    GridRow {
                        Button {
                            FileActions.copyPath(result)
                        } label: {
                            Label("경로 복사", systemImage: "doc.on.doc")
                                .frame(maxWidth: .infinity)
                        }
                        Button(role: .destructive) {
                            requestTrash([result])
                        } label: {
                            Label(
                                permanentDelete ? "영구 삭제" : "휴지통으로 이동",
                                systemImage: permanentDelete ? "trash.slash" : "trash"
                            )
                            .frame(maxWidth: .infinity)
                        }
                        .tint(.red)
                    }
                }
                .controlSize(.small)
                .padding(.top, 4)
            }
            .padding(12)
        }
        .frame(minWidth: 260, idealWidth: 320, maxWidth: 420)
        .task(id: result.id) {
            allocated = result.allocatedSize()
        }
    }

    private func metadataRow(label: String, value: String) -> some View {
        GridRow {
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .gridColumnAlignment(.trailing)
            Text(value)
                .font(.system(size: 11))
                .lineLimit(2)
                .truncationMode(.middle)
                .textSelection(.enabled)
        }
    }
}

/// QLPreviewView 래퍼 — 선택한 파일의 실제 Quick Look 미리보기를 렌더링
private struct QuickLookPreview: NSViewRepresentable {
    let url: URL

    func makeNSView(context: Context) -> QLPreviewView {
        let view = QLPreviewView(frame: .zero, style: .normal) ?? QLPreviewView()
        view.shouldCloseWithWindow = false
        return view
    }

    func updateNSView(_ view: QLPreviewView, context: Context) {
        if (view.previewItem as? NSURL) != (url as NSURL) {
            view.previewItem = url as NSURL
        }
    }

    static func dismantleNSView(_ view: QLPreviewView, coordinator: ()) {
        view.close()
    }
}
