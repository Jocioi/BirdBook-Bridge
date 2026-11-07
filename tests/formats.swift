// Generate test images and fingerprint decoded pixels without camera photographs.
import Foundation
import CoreGraphics
import ImageIO
import CryptoKit

func fixture(bits: Int, alpha: Bool) -> CGImage {
    let width = 96, height = 64, maxValue = bits == 16 ? 65535 : 255
    var bytes = [UInt8]()
    for y in 0..<height { for x in 0..<width {
        let a = alpha ? maxValue * (x + 1) / width : maxValue
        for value in [a*x/width, a*y/height, a*(x+y)/(width+height), a] {
            bytes.append(UInt8(value & 255))
            if bits == 16 { bytes.append(UInt8(value >> 8)) }
        }
    } }
    let provider = CGDataProvider(data: Data(bytes) as CFData)!
    let order: CGBitmapInfo = bits == 16 ? .byteOrder16Little : []
    return CGImage(width: width, height: height, bitsPerComponent: bits, bitsPerPixel: bits*4,
                   bytesPerRow: width*4*(bits/8), space: CGColorSpace(name: CGColorSpace.sRGB)!,
                   bitmapInfo: order.union(CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)),
                   provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)!
}
if CommandLine.arguments[1] == "generate" {
    let dir = URL(fileURLWithPath: CommandLine.arguments[2], isDirectory: true)
    for (name, type, bits, alpha) in [("image.jpg", "public.jpeg", 8, false),
                                    ("image.png", "public.png", 8, true),
                                    ("image.tif", "public.tiff", 16, false)] {
        let out = CGImageDestinationCreateWithURL(dir.appendingPathComponent(name) as CFURL, type as CFString, 1, nil)!
        CGImageDestinationAddImage(out, fixture(bits: bits, alpha: alpha), nil)
        guard CGImageDestinationFinalize(out) else { fatalError("could not create fixture") }
    }
    print("Generated JPEG, transparent PNG and 16-bit TIFF fixtures")
} else {
    let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: CommandLine.arguments[2]) as CFURL, nil)!
    let image = CGImageSourceCreateImageAtIndex(source, 0, nil)!
    let data = image.dataProvider!.data! as Data
    var result: [String: Any] = ["width": image.width, "height": image.height,
        "bits": image.bitsPerComponent, "pixelBits": image.bitsPerPixel,
        "alpha": image.alphaInfo.rawValue, "pixels": SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()]
    if let profile = image.colorSpace?.copyICCData() {
        result["profile"] = SHA256.hash(data: profile as Data).map { String(format: "%02x", $0) }.joined()
    }
    FileHandle.standardOutput.write(try JSONSerialization.data(withJSONObject: result, options: [.sortedKeys]))
}
