
// Tests are appended to the production functions by scripts/test.sh.
// All test images are generated locally, with no photographs or camera metadata.
func texture(seed: UInt64) -> CIImage {
    var state = seed, data = [UInt8](repeating: 0, count: 512*512*4)
    for i in stride(from: 0, to: data.count, by: 4) {
        state = state &* 6364136223846793005 &+ 1
        let value = UInt8(state >> 56)
        data[i] = value; data[i+1] = value; data[i+2] = value; data[i+3] = 255
    }
    return CIImage(bitmapData: Data(data), bytesPerRow: 512*4,
                   size: CGSize(width: 512, height: 512), format: .RGBA8,
                   colorSpace: CGColorSpaceCreateDeviceRGB())
        .applyingFilter("CIGaussianBlur", parameters: ["inputRadius": 1.5])
        .cropped(to: CGRect(x: 0, y: 0, width: 512, height: 512))
}
let sample = texture(seed: 42)
let input = Input(crop: [0,0,1,1], frame: [0.4,0.3,0.2,0.2])
let identity = try register(preview: sample, final: sample, input: input)
assert(zip(identity.rect,input.frame).allSatisfy { abs($0-$1) < 0.002 })
let moved = sample.clampedToExtent()
    .transformed(by: .init(scaleX: 1.01, y: 1.01))
    .transformed(by: .init(translationX: 4, y: -3)).cropped(to: sample.extent)
let result = try register(preview: sample, final: moved, input: input)
assert(abs(result.rect[0]-(0.4*1.01+4.0/512)) < 0.003)
assert(abs(result.rect[1]-(1-(1-0.3)*1.01+3.0/512)) < 0.003)
do {
    _ = try register(preview: sample, final: texture(seed: 123), input: input)
    fatalError("unrelated image accepted")
} catch { }
let flat = CIImage(color: CIColor(red: 0.5, green: 0.5, blue: 0.5)).cropped(to: sample.extent)
do {
    _ = try register(preview: flat, final: flat, input: input)
    fatalError("low-texture image accepted")
} catch { }
do {
    _ = try register(preview: sample, final: sample,
                     input: Input(crop: [0,0,1,1], frame: [0.9,0.9,0.2,0.2]))
    fatalError("out-of-bounds frame accepted")
} catch { }
let folder = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
for orientation in 1...8 {
    let cropped = sample.cropped(to: CGRect(x: 102.4, y: 51.2, width: 307.2, height: 409.6))
        .transformed(by: .init(translationX: -102.4, y: -51.2))
        .oriented(forExifOrientation: Int32(orientation))
    let upright = cropped.transformed(by: .init(translationX: -cropped.extent.minX, y: -cropped.extent.minY))
    let cropInput = Input(crop: [0.2,0.1,0.6,0.8], frame: [0.4,0.3,0.2,0.2], orientation: orientation)
    let output = try register(preview: sample, final: upright, input: cropInput)
    assert(zip(output.rect,cropInput.frame).allSatisfy { abs($0-$1) < 0.003 })
}
// A matching background cannot excuse an unrelated patch around the recorded AF frame.
let localMismatch = texture(seed: 123).cropped(to: CGRect(x: 180,y: 230,width: 160,height: 160))
    .composited(over: sample)
do {
    _ = try register(preview: sample, final: localMismatch, input: input)
    fatalError("unrelated focus-region content accepted")
} catch { }
do {
    _ = try register(preview: sample, final: sample,
        input: Input(crop: [0,0,1,1], frame: [0.4,0.3,0.2,0.2], orientation: 9))
    fatalError("invalid orientation accepted")
} catch { }
// Build the expected output from a known crop centre and size, independently of the XMP diagonal mapping.
let wide = sample.transformed(by: .init(scaleX: 1.5, y: 1))
for angle in [-45.0, -36.87, -15.0, -1.83, 1.83, 15.0, 36.87, 45.0] { for orientation in 1...8 {
    let radians = angle * Double.pi / 180, c = cos(radians), s = sin(radians)
    let width = 320.0, height = 220.0, cx = 390.0, cy = 240.0
    let dx = c*width-s*height, dy = s*width+c*height
    let centre = CGPoint(x: cx, y: 512-cy).applying(.init(rotationAngle: radians))
    let expected = wide.transformed(by: .init(rotationAngle: radians))
        .cropped(to: CGRect(x: centre.x-width/2, y: centre.y-height/2, width: width, height: height))
        .transformed(by: .init(translationX: width/2-centre.x, y: height/2-centre.y))
        .oriented(forExifOrientation: Int32(orientation))
    let straight = Input(crop: [(cx-dx/2)/768,(cy-dy/2)/512,dx/768,dy/512],
                         frame: [0.4,0.3,0.2,0.2], orientation: orientation, angle: angle)
    let mapped = try register(preview: wide, final: expected, input: straight)
    assert(zip(mapped.rect,straight.frame).allSatisfy { abs($0-$1) < 0.003 })
} }
for angle in [Double.nan, Double.infinity, -46, 46] {
    do {
        _ = try register(preview: sample, final: sample,
            input: Input(crop: [0,0,1,1], frame: [0.4,0.3,0.2,0.2], angle: angle))
        fatalError("invalid angle accepted")
    } catch { }
}
for (name, fixture) in [("sample",sample), ("flat",flat)] {
    try context.writeJPEGRepresentation(of: fixture, to: folder.appendingPathComponent(name+".jpg"),
                                       colorSpace: CGColorSpaceCreateDeviceRGB())
}
print("PASS: 83 registration cases (including straighten, all orientations, asymmetric crop and rejection guards)")
