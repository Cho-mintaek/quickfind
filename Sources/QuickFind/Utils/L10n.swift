import Foundation

/// 시스템 언어가 한국어면 한국어, 그 외에는 영어 UI 를 사용한다.
enum L10n {
    static let isKorean: Bool =
        Locale.preferredLanguages.first?.lowercased().hasPrefix("ko") ?? false
}

/// UI 문자열 이중화 헬퍼 — 정의 지점에서 한국어/영어를 나란히 둔다
func tr(_ korean: String, _ english: String) -> String {
    L10n.isKorean ? korean : english
}
