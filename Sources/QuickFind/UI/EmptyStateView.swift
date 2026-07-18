import SwiftUI
import AppKit

/// 검색 전 / 결과 없음 상태 화면
struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    var showShortcuts: Bool = false

    static var initial: EmptyStateView {
        EmptyStateView(
            icon: "sparkle.magnifyingglass",
            title: tr("무엇이든 빠르게 찾아보세요", "Find anything, fast"),
            message: tr("Spotlight 인덱스를 사용해 타이핑하는 즉시 결과가 나타납니다.", "Results appear as you type, powered by the Spotlight index."),
            showShortcuts: true
        )
    }

    static func noResults(query: String) -> EmptyStateView {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        return EmptyStateView(
            icon: "questionmark.folder",
            title: trimmed.isEmpty ? tr("조건에 맞는 파일 없음", "No matching files") : tr("‘\(trimmed)’ 결과 없음", "No results for ‘\(trimmed)’"),
            message: tr("검색어를 바꾸거나, 사이드바에서 종류·검색 범위를 넓혀보세요.", "Try a different query, or widen the kind/scope in the sidebar.")
        )
    }

    /// 휴지통 접근 권한 안내 (전체 디스크 접근 필요)
    static func trashAccessDenied(retry: @escaping () -> Void) -> some View {
        VStack(spacing: 14) {
            Image(systemName: "lock.shield")
                .font(.system(size: 42, weight: .light))
                .foregroundStyle(.tertiary)
            VStack(spacing: 6) {
                Text(tr("휴지통을 보려면 권한이 필요합니다", "Permission needed to view Trash"))
                    .font(.system(size: 16, weight: .semibold))
                Text(tr("macOS 는 휴지통 내용 읽기에 '전체 디스크 접근 권한'을 요구합니다.\n설정에서 QuickFind 를 켠 뒤, 앱을 재시작하거나 '다시 확인'을 눌러주세요.", "macOS requires Full Disk Access to read Trash contents.\nEnable QuickFind in Settings, then restart the app or press Retry."))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            HStack(spacing: 10) {
                Button(tr("전체 디스크 접근 설정 열기", "Open Full Disk Access Settings")) {
                    let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!
                    NSWorkspace.shared.open(url)
                }
                .keyboardShortcut(.defaultAction)
                Button(tr("다시 확인", "Retry"), action: retry)
            }
            .padding(.top, 6)
            Text(tr("권한 없이도 '휴지통 비우기'는 Finder 를 통해 동작합니다.", "Empty Trash still works via Finder without this permission."))
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }

    /// 휴지통이 비어 있음
    static var trashEmpty: EmptyStateView {
        EmptyStateView(
            icon: "trash",
            title: tr("휴지통이 비어 있습니다", "Trash is empty"),
            message: tr("삭제한 파일이 여기에 표시되고, 영구 삭제하거나 비울 수 있습니다.", "Deleted files appear here for permanent removal.")
        )
    }

    /// 검색 진행 중 (아직 결과 없음)
    static var loading: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
            Text(tr("검색 중…", "Searching…"))
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)
            Text(tr("Spotlight 인덱스에서 결과를 모으고 있습니다", "Gathering results from the Spotlight index"))
                .font(.system(size: 12))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 42, weight: .light))
                .foregroundStyle(.tertiary)

            VStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                Text(message)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            if showShortcuts {
                VStack(alignment: .leading, spacing: 8) {
                    shortcutRow(keys: "↑ ↓", description: tr("결과 이동", "Move selection"))
                    shortcutRow(keys: "↩", description: tr("파일 열기", "Open file"))
                    shortcutRow(keys: "⌘ ↩", description: tr("Finder에서 보기", "Reveal in Finder"))
                    shortcutRow(keys: "⌘ F", description: tr("검색창으로 이동", "Focus search field"))
                }
                .padding(.top, 10)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }

    private func shortcutRow(keys: String, description: String) -> some View {
        HStack(spacing: 10) {
            Text(keys)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(Color.primary.opacity(0.07))
                )
                .frame(width: 64, alignment: .center)
            Text(description)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
    }
}
