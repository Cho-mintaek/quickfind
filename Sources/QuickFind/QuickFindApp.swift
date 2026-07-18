import SwiftUI

extension Notification.Name {
    /// 보호 폴더(다운로드·데스크탑·문서) 접근 프로브 완료
    static let qfFolderAccessProbed = Notification.Name("qfFolderAccessProbed")
}

@main
struct QuickFindApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 900, minHeight: 560)
        }
        .defaultSize(width: 1150, height: 720)
        .commands {
            CommandGroup(after: .textEditing) {
                FocusSearchCommand()
            }
        }
    }
}

/// 앱 활성화 처리 — 번들 밖에서 실행돼도 창이 앞으로 오도록 한다
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        requestProtectedFolderAccess()
    }

    /// 다운로드·데스크탑·문서는 TCC 보호 폴더라 접근 권한이 없으면
    /// Spotlight 결과에서 조용히 제외된다. mds 는 프로세스가 메타데이터 서버에
    /// 처음 연결될 때의 권한을 쓰므로, 첫 쿼리가 시작되기 전(앱 시작 직후)에
    /// 동기적으로 접근을 시도해 권한을 확보해야 한다.
    private func requestProtectedFolderAccess() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        for folder in ["Downloads", "Desktop", "Documents"] {
            _ = try? FileManager.default.contentsOfDirectory(
                at: home.appendingPathComponent(folder),
                includingPropertiesForKeys: nil
            )
        }
        NotificationCenter.default.post(name: .qfFolderAccessProbed, object: nil)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

private struct FocusSearchCommand: View {
    @FocusedValue(\.focusSearchAction) private var focusSearch

    var body: some View {
        Button("검색창으로 이동") {
            focusSearch?()
        }
        .keyboardShortcut("f", modifiers: .command)
        .disabled(focusSearch == nil)
    }
}
