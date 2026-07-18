import AppKit
import SwiftUI

/// 메인 창 참조를 붙잡아 전역 단축키·메뉴바에서 토글할 수 있게 한다.
/// 창을 닫아도 해제되지 않도록 유지해 앱이 메뉴바에 상주할 수 있다.
@MainActor
final class WindowManager {
    static let shared = WindowManager()

    private var mainWindow: NSWindow?

    private init() {}

    func adopt(_ window: NSWindow) {
        window.isReleasedWhenClosed = false
        mainWindow = window
    }

    /// 앱이 앞에 있으면 숨기고, 아니면 창을 앞으로 가져와 검색창에 포커스
    func toggle() {
        if NSApp.isActive, let window = mainWindow, window.isVisible {
            NSApp.hide(nil)
        } else {
            show()
        }
    }

    func show() {
        // NSApp.hide 로 숨긴 앱은 unhide 없이는 activate 로 돌아오지 않는다
        NSApp.unhide(nil)
        if mainWindow == nil {
            // 창 참조를 아직 못 잡았으면 앱의 메인 창 후보에서 복구
            mainWindow = NSApp.windows.first { $0.canBecomeKey }
        }
        mainWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        NotificationCenter.default.post(name: .qfFocusSearch, object: nil)
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
