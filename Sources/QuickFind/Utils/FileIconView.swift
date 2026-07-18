import SwiftUI
import AppKit
import QuickLookThumbnailing

/// 파일 아이콘 뷰. 시스템 아이콘을 즉시 보여주고,
/// 이미지·동영상·PDF 는 QuickLook 썸네일이 준비되는 대로 교체한다.
struct FileIconView: View {
    let url: URL
    var side: CGFloat = 32

    @State private var thumbnail: NSImage?

    private static let iconCache = NSCache<NSString, NSImage>()
    private static let thumbnailCache = NSCache<NSString, NSImage>()

    var body: some View {
        Group {
            if let thumbnail {
                Image(nsImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            } else {
                Image(nsImage: Self.systemIcon(for: url.path))
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            }
        }
        .frame(width: side, height: side)
        .task(id: url) {
            await loadThumbnailIfNeeded()
        }
    }

    private static func systemIcon(for path: String) -> NSImage {
        if let cached = iconCache.object(forKey: path as NSString) {
            return cached
        }
        let icon = NSWorkspace.shared.icon(forFile: path)
        iconCache.setObject(icon, forKey: path as NSString)
        return icon
    }

    private func loadThumbnailIfNeeded() async {
        let key = "\(url.path)@\(Int(side))" as NSString
        if let cached = Self.thumbnailCache.object(forKey: key) {
            thumbnail = cached
            return
        }
        guard Self.wantsThumbnail(url) else { return }

        let scale = NSScreen.main?.backingScaleFactor ?? 2
        let request = QLThumbnailGenerator.Request(
            fileAt: url,
            size: CGSize(width: side, height: side),
            scale: scale,
            representationTypes: .thumbnail
        )
        let generated = try? await QLThumbnailGenerator.shared.generateBestRepresentation(for: request)
        guard let cgImage = generated?.cgImage else { return }
        let image = NSImage(cgImage: cgImage, size: CGSize(width: side, height: side))
        Self.thumbnailCache.setObject(image, forKey: key)
        thumbnail = image
    }

    private static func wantsThumbnail(_ url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        let thumbnailable: Set<String> = [
            "png", "jpg", "jpeg", "gif", "heic", "heif", "tiff", "bmp", "webp", "svg",
            "mp4", "mov", "m4v", "avi", "mkv", "pdf",
        ]
        return thumbnailable.contains(ext)
    }
}
