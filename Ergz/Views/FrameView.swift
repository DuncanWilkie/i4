//
//  Frame.swift
//  Inspiration 4 Sandbox
//
//  Created by Duncan Wilkie on 7/11/21.
//

import SwiftUI

let testimg = (0...65535).map { int in Double.random(in: 0..<0.55) > 0.5 ? Double.random(in: 0..<1) : 0.0 }
    .map { dose -> UInt32 in
        let alpha = dose
        let r = alpha * 0.247
        let g = alpha * 0.808
        let b = alpha * 0.922
        return (UInt32(r * 255) << 24) | (UInt32(g * 255) << 16) | (UInt32(b * 255) << 8) | UInt32(alpha * 255)
    }

struct FrameView: View {
    @EnvironmentObject var det: Detector
    var body: some View {
        VStack {
            let max = det.lastFrame.values.max() ?? 1
            
            var img = test ? testimg : (0...65535).map { det.lastFrame[PixelCoords(x: $0 % 256 + 1, y: $0 / 256 + 1)] ?? 0.0 }
                .map { dose -> UInt32 in
                    let alpha = dose / (max != 0 ? max : 1)
                    let r = alpha * 0.247
                    let g = alpha * 0.808
                    let b = alpha * 0.922
                    return (UInt32(r * 255) << 24) | (UInt32(g * 255) << 16) | (UInt32(b * 255) << 8) | UInt32(alpha * 255)
                }
            
            // This unsafe memory image hack is literal witchcraft; I'm just hoping old me read a really good SO post
            let cgImg = img.withUnsafeMutableBytes { (ptr) -> CGImage? in
                let ctx = CGContext(
                    data: ptr.baseAddress,
                    width: 256,
                    height: 256,
                    bitsPerComponent: 8,
                    bytesPerRow: 4*256,
                    space: CGColorSpace(name: CGColorSpace.sRGB)!,
                    bitmapInfo: CGBitmapInfo.byteOrder32Little.rawValue +
                    CGImageAlphaInfo.premultipliedLast.rawValue
                )!
                return ctx.makeImage()
            }
            
            if let _ = cgImg {
                let uiImg = UIImage(cgImage: cgImg!)
                Image(uiImage: uiImg).resizable().scaledToFit()            }
        }
    }
}


 /*struct Frame_Previews: PreviewProvider {
    static var previews: some View {
        FrameView().preferredColorScheme(.dark).environmentObject(Detector(store: Store(), config: Config()))
    }
} */
