// 앱 아이콘 생성 스크립트: 그라디언트 배경 + 돋보기를 그려 .icns 를 만든다.
// 사용: swift scripts/make_icon.swift <출력 디렉토리>
import AppKit

let outputDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "packaging"
let iconsetPath = "\(outputDir)/AppIcon.iconset"
try? FileManager.default.removeItem(atPath: iconsetPath)
try FileManager.default.createDirectory(atPath: iconsetPath, withIntermediateDirectories: true)

func drawIcon(pixelSize: Int) -> NSImage {
    let size = CGFloat(pixelSize)
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()

    let s = size / 1024.0  // 1024 기준 좌표계 스케일

    // macOS 스타일 라운드 사각형 배경 (여백 포함)
    let inset = 100 * s
    let rect = NSRect(x: inset, y: inset, width: size - inset * 2, height: size - inset * 2)
    let bg = NSBezierPath(roundedRect: rect, xRadius: 185 * s, yRadius: 185 * s)
    let gradient = NSGradient(
        starting: NSColor(calibratedRed: 0.28, green: 0.51, blue: 0.98, alpha: 1),
        ending: NSColor(calibratedRed: 0.55, green: 0.30, blue: 0.95, alpha: 1)
    )!
    gradient.draw(in: bg, angle: -60)

    // 돋보기 렌즈
    NSColor.white.setStroke()
    let lensCenter = NSPoint(x: size * 0.46, y: size * 0.56)
    let lensRadius = 190 * s
    let lens = NSBezierPath(
        ovalIn: NSRect(
            x: lensCenter.x - lensRadius, y: lensCenter.y - lensRadius,
            width: lensRadius * 2, height: lensRadius * 2
        )
    )
    lens.lineWidth = 62 * s
    lens.stroke()

    // 렌즈 안 하이라이트
    NSColor.white.withAlphaComponent(0.35).setStroke()
    let highlight = NSBezierPath()
    highlight.appendArc(
        withCenter: lensCenter, radius: lensRadius * 0.62,
        startAngle: 100, endAngle: 175
    )
    highlight.lineWidth = 40 * s
    highlight.lineCapStyle = .round
    highlight.stroke()

    // 손잡이
    NSColor.white.setStroke()
    let handle = NSBezierPath()
    let angle = -45.0 * .pi / 180.0
    let start = NSPoint(
        x: lensCenter.x + cos(angle) * (lensRadius + 24 * s),
        y: lensCenter.y + sin(angle) * (lensRadius + 24 * s)
    )
    let end = NSPoint(
        x: lensCenter.x + cos(angle) * (lensRadius + 200 * s),
        y: lensCenter.y + sin(angle) * (lensRadius + 200 * s)
    )
    handle.move(to: start)
    handle.line(to: end)
    handle.lineWidth = 78 * s
    handle.lineCapStyle = .round
    handle.stroke()

    image.unlockFocus()
    return image
}

func savePNG(_ image: NSImage, pixelSize: Int, to path: String) throws {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: pixelSize, pixelsHigh: pixelSize,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    )!
    rep.size = NSSize(width: pixelSize, height: pixelSize)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    image.draw(in: NSRect(x: 0, y: 0, width: pixelSize, height: pixelSize))
    NSGraphicsContext.restoreGraphicsState()
    let data = rep.representation(using: .png, properties: [:])!
    try data.write(to: URL(fileURLWithPath: path))
}

let sizes: [(name: String, pixels: Int)] = [
    ("icon_16x16", 16), ("icon_16x16@2x", 32),
    ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256),
    ("icon_256x256", 256), ("icon_256x256@2x", 512),
    ("icon_512x512", 512), ("icon_512x512@2x", 1024),
]

for entry in sizes {
    let image = drawIcon(pixelSize: entry.pixels)
    try savePNG(image, pixelSize: entry.pixels, to: "\(iconsetPath)/\(entry.name).png")
}

print("iconset written to \(iconsetPath)")
