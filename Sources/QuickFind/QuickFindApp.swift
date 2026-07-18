import SwiftUI

extension Notification.Name {
    /// 보호 폴더(다운로드·데스크탑·문서) 접근 프로브 완료
    static let qfFolderAccessProbed = Notification.Name("qfFolderAccessProbed")
    /// 전역 단축키/메뉴바로 창을 열 때 검색창 포커스 요청
    static let qfFocusSearch = Notification.Name("qfFocusSearch")
    /// 새 검색 창 열기 요청 (object: UUID — 중복 생성 방지용 선점 토큰)
    static let qfNewWindow = Notification.Name("qfNewWindow")
}

enum SettingsKey {
    static let hotKeyEnabled = "hotKeyEnabled"
    static let hotKeyOption = "hotKeyOption"
    static let hideDockIcon = "hideDockIcon"
}

@main
struct QuickFindApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup(id: "main") {
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

/// 앱 수명주기: 활성화, 전역 단축키, 메뉴바 상주
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: SettingsKey.hotKeyEnabled) == nil {
            defaults.set(true, forKey: SettingsKey.hotKeyEnabled)
        }

        NSApp.setActivationPolicy(
            defaults.bool(forKey: SettingsKey.hideDockIcon) ? .accessory : .regular
        )
        NSApp.activate(ignoringOtherApps: true)
        requestProtectedFolderAccess()
        setupStatusItem()

        HotKeyManager.shared.onHotKey = {
            Task { @MainActor in WindowManager.shared.toggle() }
        }
        applyHotKeySetting()
    }

    private var currentHotKeyOption: HotKeyOption {
        HotKeyOption(rawValue: UserDefaults.standard.string(forKey: SettingsKey.hotKeyOption) ?? "")
            ?? .default
    }

    private func applyHotKeySetting() {
        if UserDefaults.standard.bool(forKey: SettingsKey.hotKeyEnabled) {
            HotKeyManager.shared.register(option: currentHotKeyOption)
        } else {
            HotKeyManager.shared.unregister()
        }
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

    /// 창을 닫아도 종료하지 않는다 — 메뉴바·전역 단축키로 상주
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    /// Dock 아이콘 클릭 등으로 재활성화되면 창을 다시 보여준다
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        if !hasVisibleWindows {
            Task { @MainActor in WindowManager.shared.show() }
        }
        return true
    }

    // MARK: - 메뉴바

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = item.button {
            button.image = NSImage(
                systemSymbolName: "magnifyingglass.circle.fill",
                accessibilityDescription: "QuickFind"
            )
            button.action = #selector(statusItemClicked)
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        statusItem = item
    }

    @objc private func statusItemClicked() {
        if NSApp.currentEvent?.type == .rightMouseUp {
            showStatusMenu()
        } else {
            Task { @MainActor in WindowManager.shared.toggle() }
        }
    }

    private func showStatusMenu() {
        let defaults = UserDefaults.standard
        let menu = NSMenu()

        let hotKeyEnabled = defaults.bool(forKey: SettingsKey.hotKeyEnabled)
        let openItem = NSMenuItem(
            title: "열기 / 숨기기 (\(currentHotKeyOption.label))",
            action: #selector(menuToggleWindow), keyEquivalent: ""
        )
        openItem.target = self
        menu.addItem(openItem)

        let newWindowItem = NSMenuItem(
            title: "새 검색 창",
            action: #selector(menuNewWindow), keyEquivalent: ""
        )
        newWindowItem.target = self
        menu.addItem(newWindowItem)
        menu.addItem(.separator())

        let hotKeyMenu = NSMenu()
        for option in HotKeyOption.allCases {
            let item = NSMenuItem(
                title: option.label,
                action: #selector(menuSelectHotKey(_:)), keyEquivalent: ""
            )
            item.target = self
            item.representedObject = option.rawValue
            item.state = (hotKeyEnabled && option == currentHotKeyOption) ? .on : .off
            hotKeyMenu.addItem(item)
        }
        hotKeyMenu.addItem(.separator())
        let disableItem = NSMenuItem(
            title: "사용 안 함",
            action: #selector(menuDisableHotKey), keyEquivalent: ""
        )
        disableItem.target = self
        disableItem.state = hotKeyEnabled ? .off : .on
        hotKeyMenu.addItem(disableItem)

        let hotKeyRoot = NSMenuItem(title: "전역 단축키", action: nil, keyEquivalent: "")
        hotKeyRoot.submenu = hotKeyMenu
        menu.addItem(hotKeyRoot)

        let dockItem = NSMenuItem(
            title: "Dock 아이콘 숨기기",
            action: #selector(menuToggleDockIcon), keyEquivalent: ""
        )
        dockItem.target = self
        dockItem.state = defaults.bool(forKey: SettingsKey.hideDockIcon) ? .on : .off
        menu.addItem(dockItem)

        menu.addItem(.separator())
        let quitItem = NSMenuItem(
            title: "QuickFind 종료",
            action: #selector(menuQuit), keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        // 메뉴를 일회성으로 붙였다 떼어 좌클릭 토글이 계속 동작하게 한다
        statusItem?.menu = menu
        statusItem?.button?.performClick(nil)
        statusItem?.menu = nil
    }

    @objc private func menuToggleWindow() {
        Task { @MainActor in WindowManager.shared.toggle() }
    }

    @objc private func menuNewWindow() {
        Task { @MainActor in
            // 창을 먼저 앞으로 가져와야 알림 수신자(ContentView)가 살아 있다
            WindowManager.shared.show()
            WindowManager.shared.requestNewWindow()
        }
    }

    @objc private func menuSelectHotKey(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let option = HotKeyOption(rawValue: raw) else { return }
        let defaults = UserDefaults.standard
        defaults.set(option.rawValue, forKey: SettingsKey.hotKeyOption)
        defaults.set(true, forKey: SettingsKey.hotKeyEnabled)
        applyHotKeySetting()
    }

    @objc private func menuDisableHotKey() {
        UserDefaults.standard.set(false, forKey: SettingsKey.hotKeyEnabled)
        applyHotKeySetting()
    }

    @objc private func menuToggleDockIcon() {
        let defaults = UserDefaults.standard
        let hide = !defaults.bool(forKey: SettingsKey.hideDockIcon)
        defaults.set(hide, forKey: SettingsKey.hideDockIcon)
        NSApp.setActivationPolicy(hide ? .accessory : .regular)
        if hide {
            // 정책 전환 직후 창이 뒤로 숨는 것 방지
            Task { @MainActor in WindowManager.shared.show() }
        }
    }

    @objc private func menuQuit() {
        NSApp.terminate(nil)
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
