// CI-only acceptance check: a valid Light capture must visually differ from Dark.
// Verify overall luminance, not just bytes or a changing status-bar clock.
import AppKit
import Foundation

guard CommandLine.arguments.count == 2 else {
    fputs("Usage: validate_appearance_pairs.swift <screenshots-directory>\n", stderr)
    exit(2)
}
let root = URL(fileURLWithPath: CommandLine.arguments[1])
let productScreens = ["home", "rooms", "chat", "media",
                      "system", "light", "media-detail", "owner"]
var pairs: [(String, String)] = productScreens.map {
    ("catalog-dark-\($0).png", "catalog-light-\($0).png")
}
for page in 1...3 {
    pairs.append(("cards-dark-page-\(page).png", "cards-light-page-\(page).png"))
}

func sampleMean(_ url: URL) -> Double? {
    guard let data = try? Data(contentsOf: url),
          let bitmap = NSBitmapImageRep(data: data),
          bitmap.pixelsWide >= 300, bitmap.pixelsHigh >= 500 else { return nil }
    let w = bitmap.pixelsWide
    let h = bitmap.pixelsHigh
    var sum = 0.0
    var count = 0
    // Take a spatial mean across app content, excluding status/home indicators.
    for y in stride(from: h / 5, to: 4 * h / 5, by: max(1, h / 40)) {
        for x in stride(from: w / 8, to: 7 * w / 8, by: max(1, w / 34)) {
            guard let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB) else {
                continue
            }
            sum += 0.2126 * Double(color.redComponent) +
                   0.7152 * Double(color.greenComponent) +
                   0.0722 * Double(color.blueComponent)
            count += 1
        }
    }
    return count > 300 ? sum / Double(count) : nil
}

var failures = 0
for (dark, light) in pairs {
    let darkURL = root.appendingPathComponent(dark)
    let lightURL = root.appendingPathComponent(light)
    guard let darkMean = sampleMean(darkURL),
          let lightMean = sampleMean(lightURL) else {
        print("APPEARANCE_INVALID_PAIR dark=\(dark) light=\(light)")
        failures += 1
        continue
    }
    let delta = lightMean - darkMean
    print(String(format: "APPEARANCE_PAIR %@ dark=%.3f light=%.3f delta=%.3f",
                 dark, darkMean, lightMean, delta))
    if delta < 0.10 {
        print("APPEARANCE_NOT_DISTINCT \(dark) delta=\(delta)")
        failures += 1
    }
}
if failures > 0 {
    print("APPEARANCE_MATRIX=FAIL pairs=\(pairs.count) failures=\(failures)")
    exit(1)
}
print("APPEARANCE_MATRIX=PASS pairs=\(pairs.count)")
