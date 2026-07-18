import SwiftUI

struct ContentView: View {
    @StateObject private var primaryEngine = SearchEngine()
    @StateObject private var secondaryEngine = SearchEngine()
    @State private var splitEnabled = false
    @State private var hostWindow: NSWindow?
    @Environment(\.openWindow) private var openWindow

    /// 실행 인자 주입은 최초 창에서 한 번만
    private static var launchArgumentsApplied = false

    var body: some View {
        NavigationSplitView {
            SidebarView(engine: primaryEngine)
        } detail: {
            HSplitView {
                SearchPaneView(
                    engine: primaryEngine,
                    respondsToGlobalFocus: true
                )
                .frame(minWidth: 420)
                if splitEnabled {
                    SearchPaneView(
                        engine: secondaryEngine,
                        showsFilterPickers: true
                    )
                    .frame(minWidth: 420)
                }
            }
            // 분할 시 두 패널 최소 폭이 확보되도록 창 최소 폭을 함께 올린다
            .frame(minWidth: splitEnabled ? 1100 : 420)
        }
        .navigationTitle("QuickFind")
        .toolbar {
            ToolbarItem {
                Button {
                    splitEnabled.toggle()
                } label: {
                    Label(
                        splitEnabled ? tr("분할 닫기", "Close Split") : tr("화면 분할", "Split View"),
                        systemImage: splitEnabled
                            ? "rectangle.split.2x1.slash" : "rectangle.split.2x1"
                    )
                }
                .help(splitEnabled
                      ? tr("분할 패널을 닫습니다", "Close the split pane")
                      : tr("독립 검색 패널을 하나 더 엽니다 (다른 폴더를 동시에 검색)", "Open a second independent search pane"))
            }
            ToolbarItem {
                Button {
                    openWindow(id: "main")
                } label: {
                    Label(tr("새 검색 창", "New Search Window"), systemImage: "macwindow.badge.plus")
                }
                .help(tr("독립 검색 창을 새로 엽니다 (⌘N)", "Open a new independent search window (⌘N)"))
            }
        }
        .background(WindowAccessor { window in
            hostWindow = window
            WindowManager.shared.adopt(window)
        })
        .onReceive(NotificationCenter.default.publisher(for: .qfNewWindow)) { notification in
            // 여러 창이 동시에 반응해 창이 중복 생성되지 않도록 요청을 선점한 창만 연다
            if let id = notification.object as? UUID,
               WindowManager.shared.claimNewWindowRequest(id) {
                openWindow(id: "main")
            }
        }
        .onChange(of: splitEnabled) { _, enabled in
            // 분할을 켰을 때 창이 좁으면 두 패널이 답답하지 않게 넓혀준다
            guard enabled, let window = hostWindow ?? NSApp.keyWindow,
                  window.frame.width < 1600 else { return }
            var frame = window.frame
            let targetWidth: CGFloat = 1600
            let screenFrame = window.screen?.visibleFrame
                ?? NSRect(x: 0, y: 0, width: targetWidth, height: frame.height)
            frame.size.width = min(targetWidth, screenFrame.width)
            // 넓힌 뒤에도 화면 밖으로 나가지 않게 좌우 위치 보정
            frame.origin.x = max(
                screenFrame.minX,
                min(frame.origin.x - (frame.width - window.frame.width) / 2,
                    screenFrame.maxX - frame.width)
            )
            window.setFrame(frame, display: true, animate: true)
        }
        .onAppear {
            applyLaunchArguments()
        }
    }

    private func applyLaunchArguments() {
        guard !Self.launchArgumentsApplied else { return }
        Self.launchArgumentsApplied = true
        // UI 자동 검증용 초기 상태 주입 (일반 실행에는 영향 없음)
        if let initial = ProcessInfo.processInfo.environment["QUICKFIND_INITIAL_QUERY"] {
            primaryEngine.queryText = initial
        } else if let index = CommandLine.arguments.firstIndex(of: "--query"),
                  CommandLine.arguments.indices.contains(index + 1) {
            primaryEngine.queryText = CommandLine.arguments[index + 1]
        }
        if let index = CommandLine.arguments.firstIndex(of: "--preset"),
           CommandLine.arguments.indices.contains(index + 1),
           let preset = CleanupPreset(rawValue: CommandLine.arguments[index + 1]) {
            primaryEngine.cleanupPreset = preset
        }
        if CommandLine.arguments.contains("--trash") {
            primaryEngine.showingTrash = true
        }
        if CommandLine.arguments.contains("--split") {
            splitEnabled = true
        }
    }
}

/// ⌘F 메뉴 커맨드에서 검색창 포커스를 주기 위한 FocusedValue
struct FocusSearchActionKey: FocusedValueKey {
    typealias Value = () -> Void
}

extension FocusedValues {
    var focusSearchAction: (() -> Void)? {
        get { self[FocusSearchActionKey.self] }
        set { self[FocusSearchActionKey.self] = newValue }
    }
}
