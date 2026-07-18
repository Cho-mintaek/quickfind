import AppKit
import Carbon.HIToolbox

/// 선택 가능한 전역 단축키 프리셋 (모두 Space 기반 — Spotlight 사용 감각 유지)
enum HotKeyOption: String, CaseIterable {
    case shiftCmdSpace
    case optSpace
    case ctrlShiftSpace

    static let `default`: HotKeyOption = .shiftCmdSpace

    var label: String {
        switch self {
        case .shiftCmdSpace: return "⇧⌘ Space"
        case .optSpace: return "⌥ Space"
        case .ctrlShiftSpace: return "⌃⇧ Space"
        }
    }

    var carbonModifiers: UInt32 {
        switch self {
        case .shiftCmdSpace: return UInt32(shiftKey | cmdKey)
        case .optSpace: return UInt32(optionKey)
        case .ctrlShiftSpace: return UInt32(controlKey | shiftKey)
        }
    }
}

/// 전역 단축키 등록. Carbon RegisterEventHotKey 는 접근성 권한 없이
/// 시스템 전역에서 동작하는 유일한 공개 API 다 (Spotlight류 앱 표준).
final class HotKeyManager {
    static let shared = HotKeyManager()

    var onHotKey: (() -> Void)?

    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?

    private init() {}

    func register(option: HotKeyOption) {
        unregister()

        if handlerRef == nil {
            var eventType = EventTypeSpec(
                eventClass: OSType(kEventClassKeyboard),
                eventKind: UInt32(kEventHotKeyPressed)
            )
            InstallEventHandler(
                GetApplicationEventTarget(),
                { _, _, userData in
                    guard let userData else { return noErr }
                    Unmanaged<HotKeyManager>.fromOpaque(userData)
                        .takeUnretainedValue().onHotKey?()
                    return noErr
                },
                1, &eventType,
                Unmanaged.passUnretained(self).toOpaque(),
                &handlerRef
            )
        }

        let hotKeyID = EventHotKeyID(signature: 0x51464B31, id: 1) // 'QFK1'
        RegisterEventHotKey(
            UInt32(kVK_Space), option.carbonModifiers, hotKeyID,
            GetApplicationEventTarget(), 0, &hotKeyRef
        )
    }

    func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
        }
        hotKeyRef = nil
    }

    var isRegistered: Bool { hotKeyRef != nil }
}
