import AppKit
import SwiftUI

/// 창 참조를 붙잡아 전역 단축키·메뉴바에서 토글할 수 있게 한다.
/// 창을 닫아도 해제되지 않도록 유지해 앱이 메뉴바에 상주할 수 있으며,
/// 다중 창(⌘N·새 검색 창)을 모두 추적한다.
@MainActor
final class WindowManager {
    static let shared = WindowManager()

    private var windows: [NSWindow] = []
    private var claimedNewWindowRequests: Set<UUID> = []

    private init() {}

    func adopt(_ window: NSWindow) {
        window.isReleasedWhenClosed = false
        if !windows.contains(window) {
            windows.append(window)
        }
    }

    /// 앱이 앞에 있으면 숨기고, 아니면 창을 앞으로 가져와 검색창에 포커스
    func toggle() {
        pruneDead()
        if NSApp.isActive, windows.contains(where: { $0.isVisible }) {
            NSApp.hide(nil)
        } else {
            show()
        }
    }

    func show() {
        pruneDead()
        // NSApp.hide 로 숨긴 앱은 unhide 없이는 activate 로 돌아오지 않는다
        NSApp.unhide(nil)
        if windows.isEmpty, let fallback = NSApp.windows.first(where: { $0.canBecomeKey }) {
            adopt(fallback)
        }
        // 마지막에 열린(보이는) 창 우선, 없으면 가장 최근 창 복원
        let target = windows.last(where: { $0.isVisible }) ?? windows.last
        target?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        NotificationCenter.default.post(name: .qfFocusSearch, object: nil)
    }

    /// "새 검색 창" 알림을 여러 ContentView 가 받아도 한 창만 열리도록 선점 처리
    func claimNewWindowRequest(_ id: UUID) -> Bool {
        guard !claimedNewWindowRequests.contains(id) else { return false }
        claimedNewWindowRequests.insert(id)
        return true
    }

    func requestNewWindow() {
        NotificationCenter.default.post(name: .qfNewWindow, object: UUID())
    }

    private func pruneDead() {
        windows.removeAll { $0.contentView == nil }
    }
}

/// SwiftUI 뷰가 속한 NSWindow 를 붙잡기 위한 브릿지
struct WindowAccessor: NSViewRepresentable {
    let onResolve: (NSWindow) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window {
                onResolve(window)
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}
