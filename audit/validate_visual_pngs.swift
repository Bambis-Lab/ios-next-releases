// Fail closed when a screenshot exists but the app surface is black.
// macOS + Xcode only; no third-party image dependencies.
import AppKit
import Foundation

let paths = Array(CommandLine.arguments.dropFirst())
guard !paths.isEmpty else {
    fputs("No screenshots to validate\n", stderr)
    exit(2)
}
var failures = 0
for path in paths {
    let url = URL(fileURLWithPath: path)
    guard let data = try? Data(contentsOf: url),
          let image = NSBitmapImageRep(data: data),
          image.pixelsWide >= 300, image.pixelsHigh >= 500 else {
        fputs("INVALID_PNG \(url.lastPathComponent)\n", stderr)
        failures += 1
        continue
    }
    var visible = 0
    var sampled = 0
    let w = image.pixelsWide
    let h = image.pixelsHigh
    // Ignore status bar and home indicator; inspect the central app canvas.
    for y in stride(from: h / 5, to: h * 4 / 5, by: max(1, h / 44)) {
        for x in stride(from: w / 6, to: w * 5 / 6, by: max(1, w / 32)) {
            guard let color = image.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB) else {
                continue
            }
            sampled += 1
            if max(color.redComponent, color.greenComponent, color.blueComponent) > 0.085 {
                visible += 1
            }
        }
    }
    let fraction = sampled == 0 ? 0.0 : Double(visible) / Double(sampled)
    print(String(format: "SCREENSHOT_CHECK %@ visible_fraction=%.3f", url.lastPathComponent, fraction))
    if sampled < 200 || fraction < 0.01 {
        fputs("BLACK_OR_EMPTY_CAPTURE \(url.lastPathComponent)\n", stderr)
        failures += 1
    }
}
if failures != 0 {
    fputs("VISUAL_CONTENT_GATE=FAIL count=\(failures)\n", stderr)
    exit(1)
}
print("VISUAL_CONTENT_GATE=PASS count=\(paths.count)")
