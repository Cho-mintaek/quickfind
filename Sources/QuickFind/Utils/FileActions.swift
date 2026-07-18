import AppKit

/// 결과 항목에 대한 공통 동작 모음
enum FileActions {
    static func open(_ result: SearchResult) {
        NSWorkspace.shared.open(result.url)
    }

    static func revealInFinder(_ result: SearchResult) {
        NSWorkspace.shared.activateFileViewerSelecting([result.url])
    }

    static func revealInFinder(_ results: [SearchResult]) {
        NSWorkspace.shared.activateFileViewerSelecting(results.map(\.url))
    }

    static var trashURL: URL {
        FileManager.default.urls(for: .trashDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".Trash")
    }

    /// 휴지통으로 이동. 성공한 항목 ID 와 실패 수를 반환한다.
    static func trash(_ results: [SearchResult]) -> (succeeded: Set<SearchResult.ID>, failures: Int) {
        var succeeded: Set<SearchResult.ID> = []
        var failures = 0
        for result in results {
            do {
                try FileManager.default.trashItem(at: result.url, resultingItemURL: nil)
                succeeded.insert(result.id)
            } catch {
                failures += 1
            }
        }
        return (succeeded, failures)
    }

    /// 영구 삭제 (휴지통 안 항목용). 성공한 항목 ID 와 실패 수를 반환한다.
    static func deletePermanently(_ results: [SearchResult]) -> (succeeded: Set<SearchResult.ID>, failures: Int) {
        var succeeded: Set<SearchResult.ID> = []
        var failures = 0
        for result in results {
            do {
                try FileManager.default.removeItem(at: result.url)
                succeeded.insert(result.id)
            } catch {
                failures += 1
            }
        }
        return (succeeded, failures)
    }

    /// 휴지통 비우기. Finder 를 통해 실행하면 전체 디스크 접근 권한 없이도
    /// 동작한다 (첫 실행 시 Finder 제어 허용 프롬프트 1회).
    /// 실패 시 직접 삭제로 폴백하고, 오류 메시지를 반환한다 (nil = 성공).
    static func emptyTrash() -> String? {
        let script = NSAppleScript(source: "tell application \"Finder\" to empty trash")
        var errorInfo: NSDictionary?
        script?.executeAndReturnError(&errorInfo)
        guard errorInfo != nil else { return nil }

        // Finder 제어가 거부된 경우: 직접 삭제 시도 (전체 디스크 접근 권한 필요)
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: trashURL, includingPropertiesForKeys: nil,
            options: [.skipsSubdirectoryDescendants]
        ) else {
            return tr("Finder 제어가 거부되어 휴지통을 비우지 못했습니다. 시스템 설정 → 개인정보 보호 및 보안 → 자동화에서 QuickFind 의 Finder 제어를 허용해주세요.", "Finder control was denied. Allow QuickFind to control Finder in System Settings → Privacy & Security → Automation.")
        }
        var failures = 0
        for url in contents {
            do {
                try FileManager.default.removeItem(at: url)
            } catch {
                failures += 1
            }
        }
        return failures > 0 ? tr("\(failures)개 항목을 삭제하지 못했습니다.", "\(failures) item(s) could not be deleted.") : nil
    }

    static func copyPath(_ result: SearchResult) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(result.url.path, forType: .string)
    }

    static func copyFile(_ result: SearchResult) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([result.url as NSURL])
    }
}
