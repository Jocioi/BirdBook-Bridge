// Maps the camera's recorded frame through mild lens correction using image registration.
// It never detects a subject or invents a focus point; outputs are explicitly reference frames.
import Foundation
import CoreImage
import ImageIO
import Vision
import simd

struct Input: Decodable {
    let crop: [Double]
    let frame: [Double]
    var orientation: Int? = nil
}
struct Output: Encodable { let rect: [Double]; let correlation: Double }
enum Failure: Error { case invalid, unreliable }
let context = CIContext(options: [.cacheIntermediates: false])

func image(_ path: String, applyOrientation: Bool = true) throws -> CIImage {
    guard let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil),
          let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: 1536,
            kCGImageSourceCreateThumbnailWithTransform: applyOrientation
          ] as CFDictionary) else { throw Failure.invalid }
    return CIImage(cgImage: thumbnail)
}
func validRect(_ v: [Double]) -> Bool {
    v.count == 4 && v.allSatisfy(\.isFinite) && v[0] >= 0 && v[1] >= 0 && v[2] > 0 && v[3] > 0
        && v[0]+v[2] <= 1 && v[1]+v[3] <= 1
}
func warp(_ m: simd_float3x3, _ point: CGPoint) throws -> CGPoint {
    let p = m * SIMD3<Float>(Float(point.x), Float(point.y), 1)
    guard p.x.isFinite, p.y.isFinite, p.z.isFinite, p.z > 0.1 else { throw Failure.unreliable }
    return CGPoint(x: Double(p.x/p.z), y: Double(p.y/p.z))
}
func matrix(_ source: CIImage, _ destination: CIImage) throws -> simd_float3x3 {
    guard let a = context.createCGImage(source, from: source.extent),
          let b = context.createCGImage(destination, from: destination.extent) else { throw Failure.invalid }
    let request = VNHomographicImageRegistrationRequest(targetedCGImage: a)
    try VNImageRequestHandler(cgImage: b).perform([request])
    guard let result = request.results?.first else { throw Failure.unreliable }
    return result.warpTransform
}
func pixels(_ image: CIImage, _ size: CGSize) -> [Float] {
    var result = [Float](repeating: 0, count: Int(size.width)*Int(size.height))
    context.render(image, toBitmap: &result, rowBytes: Int(size.width)*4,
                   bounds: CGRect(origin: .zero, size: size), format: .Lf, colorSpace: CGColorSpaceCreateDeviceGray())
    return result
}
func correlation(_ a: [Float], _ b: [Float], size: CGSize, area: CGRect) throws -> Double {
    let w = Int(size.width), h = Int(size.height)
    let x0 = max(2, Int(area.minX)), x1 = min(w-2, Int(area.maxX))
    let y0 = max(2, Int(area.minY)), y1 = min(h-2, Int(area.maxY))
    guard x1-x0 >= 16, y1-y0 >= 16 else { throw Failure.unreliable }
    var aa = 0.0, ab = 0.0, bb = 0.0
    for y in y0..<y1 { for x in x0..<x1 {
        let p = y*w+x
        for d in [1,w] {
            let da = Double(a[p+d]-a[p-d]), db = Double(b[p+d]-b[p-d])
            aa += da*da; ab += da*db; bb += db*db
        }
    } }
    let count = Double((x1-x0)*(y1-y0)*2)
    guard aa/count > 0.0001, bb/count > 0.0001 else { throw Failure.unreliable }
    let score = ab/sqrt(aa*bb)
    guard score.isFinite, score >= 0.80 else { throw Failure.unreliable }
    return score
}
func register(preview: CIImage, final: CIImage, input: Input) throws -> Output {
    let orientation = input.orientation ?? 1
    guard validRect(input.crop), validRect(input.frame), (1...8).contains(orientation) else { throw Failure.invalid }
    let crop = CGRect(x: input.crop[0]*preview.extent.width,
                      y: (1-input.crop[1]-input.crop[3])*preview.extent.height,
                      width: input.crop[2]*preview.extent.width, height: input.crop[3]*preview.extent.height)
    let size = CGSize(width: (512*final.extent.width/max(final.extent.width,final.extent.height)).rounded(),
                      height: (512*final.extent.height/max(final.extent.width,final.extent.height)).rounded())
    // Crop in source axes, then apply the RAW orientation once, independently of preview JPEG metadata.
    let upright = preview.cropped(to: crop).transformed(by: .init(translationX: -crop.minX, y: -crop.minY))
        .oriented(forExifOrientation: Int32(orientation))
    guard min(size.width,size.height) >= 64,
          abs((upright.extent.width/upright.extent.height)/(final.extent.width/final.extent.height)-1) < 0.01 else { throw Failure.invalid }
    let a = upright.transformed(by: .init(translationX: -upright.extent.minX, y: -upright.extent.minY))
        .transformed(by: .init(scaleX: size.width/upright.extent.width, y: size.height/upright.extent.height))
    let b = final.transformed(by: .init(scaleX: size.width/final.extent.width, y: size.height/final.extent.height))
    let m = try matrix(a,b), reverse = try matrix(b,a)
    let frame = CGRect(x: input.frame[0]*size.width, y: (1-input.frame[1]-input.frame[3])*size.height,
                       width: input.frame[2]*size.width, height: input.frame[3]*size.height)
    let points = [CGPoint(x: frame.minX,y: frame.minY), CGPoint(x: frame.maxX,y: frame.minY),
                  CGPoint(x: frame.minX,y: frame.maxY), CGPoint(x: frame.maxX,y: frame.maxY),
                  CGPoint(x: frame.midX,y: frame.midY)]
    let mapped = try points.map { p -> CGPoint in
        let q = try warp(m,p), back = try warp(reverse,q)
        guard hypot(q.x-p.x,q.y-p.y) <= 512*0.04, hypot(back.x-p.x,back.y-p.y) <= 1 else { throw Failure.unreliable }
        return q
    }
    let xs = mapped.map(\.x), ys = mapped.map(\.y)
    guard let x0 = xs.min(), let x1 = xs.max(), let y0 = ys.min(), let y1 = ys.max() else { throw Failure.unreliable }
    let box = CGRect(x:x0,y:y0,width:x1-x0,height:y1-y0)
    guard (0.85...1.15).contains(box.width/frame.width), (0.85...1.15).contains(box.height/frame.height) else { throw Failure.unreliable }
    let rect = [box.minX/size.width, 1-box.maxY/size.height, box.width/size.width, box.height/size.height].map(Double.init)
    guard validRect(rect) else { throw Failure.unreliable }
    func vector(_ x: Double, _ y: Double) throws -> CIVector {
        let p = try warp(m,CGPoint(x:x,y:y)); return CIVector(x:p.x,y:p.y)
    }
    let aligned = try a.applyingFilter("CIPerspectiveTransform", parameters: [
        "inputTopLeft": vector(0,size.height), "inputTopRight": vector(size.width,size.height),
        "inputBottomLeft": vector(0,0), "inputBottomRight": vector(size.width,0)
    ])
    let pa = pixels(aligned,size), pb = pixels(b,size)
    let roi = box.insetBy(dx:-max(12,box.width*0.25),dy:-max(12,box.height*0.25))
    let score = try correlation(pa,pb,size:size,area:roi)
    // Keep the close frame check, and give each independent side enough context for small AF boxes.
    let anchors = box.insetBy(dx:-max(24,box.width*0.25),dy:-max(24,box.height*0.25))
    _ = try correlation(pa,pb,size:size,area:CGRect(x:anchors.minX,y:anchors.minY,width:anchors.width/2,height:anchors.height))
    _ = try correlation(pa,pb,size:size,area:CGRect(x:anchors.midX,y:anchors.minY,width:anchors.width/2,height:anchors.height))
    return Output(rect:rect, correlation:score)
}

// Bound the export delay even if the system image-registration service stalls.
DispatchQueue.global().asyncAfter(deadline: .now()+10) { exit(2) }
do {
    guard CommandLine.arguments.count == 4 else { throw Failure.invalid }
    let input = try JSONDecoder().decode(Input.self, from: Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[3])))
    let result = try register(preview:image(CommandLine.arguments[1], applyOrientation: false), final:image(CommandLine.arguments[2]), input:input)
    FileHandle.standardOutput.write(try JSONEncoder().encode(result))
} catch { exit(2) }
