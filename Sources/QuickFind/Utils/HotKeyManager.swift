import AppKit
import Carbon.HIToolbox

/// 전역 단축키(⌥Space) 등록. Carbon RegisterEventHotKey 는 접근성 권한 없이
/// 시스템 전역에서 동작하는 유일한 공개 API 다 (Spotlight류 앱 표준).
final class HotKeyManager {
    static let shared = HotKeyManager()

    var onHotKey: (() -> Void)?

    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?

    private init() {}

    func register() {
        guard hotKeyRef == nil else { return }

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
            UInt32(kVK_Space), UInt32(optionKey), hotKeyID,
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
