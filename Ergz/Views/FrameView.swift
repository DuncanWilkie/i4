//
//  Frame.swift
//  Inspiration 4 Sandbox
//
//  Created by Duncan Wilkie on 7/11/21.
//

import SwiftUI


struct FrameView: View {
    @EnvironmentObject var det: Detector
    var body: some View {
        VStack {
            
            var img = (1...65536).map({ _ -> UInt32 in
                let alpha = (Int.random(in: 0...15) == 0) ? Double.random(in: 0...1) : 0.0
                let r = alpha * 0.247
                let g = alpha * 0.808
                let b = alpha * 0.922
                return (UInt32(r * 255) << 24) | (UInt32(g * 255) << 16) | (UInt32(b * 255) << 8) | UInt32(alpha * 255)
                
            })
            // TODO: Rework this to support new lastFrame semantics
            /*let max = det.lastFrame.max { $0 < $1 } ?? 1 // consider implementing in Detector so this only updates on new frames
            var img = (1...65536).map { det.lastFrame[$0] != nil }.map { exp -> UInt32 in
             let alpha = exp / (max != 0 ? max : 1)
             let r = alpha * 0.247
             let g = alpha * 0.808
             let b = alpha * 0.922
             return (UInt32(r * 255) << 24) | (UInt32(g * 255) << 16) | (UInt32(b * 255) << 8) | UInt32(alpha * 255)
             } */
            
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
                Image(uiImage: uiImg).resizable().scaledToFit()
                
            }            
        }
    }
}


struct Frame_Previews: PreviewProvider {
    static var previews: some View {
        FrameView().preferredColorScheme(.dark).environmentObject(Detector(store: Store(), config: Config()))
    }
}
