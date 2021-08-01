//
//  Frame.swift
//  Inspiration 4 Sandbox
//
//  Created by Duncan Wilkie on 7/11/21.
//

import SwiftUI
var img = (1...65536).map({ _ -> UInt32 in
    let alpha = Double.random(in: 0...1)
    let r = alpha * 0.247
    let g = alpha * 0.808
    let b = alpha * 0.922
    return (UInt32(r * 255) << 24) | (UInt32(g * 255) << 16) | (UInt32(b * 255) << 8) | UInt32(alpha * 255)
    
})

struct FrameView: View {
    // @ObservedObject var frame = ...
    var body: some View {
        VStack {
        /*  Not implemented lastFrame yet--commented out for demo
            let max = det.lastFrame.map({ $0.max()}).max()
            var img = det.lastFrame.map({exp -> UInt32 in
            let alpha = exp / max
            let r = alpha * 0.247
            let g = alpha * 0.808
            let b = alpha * 0.922
            return (UInt32(r * 255) << 24) | (UInt32(g * 255) << 16) | (UInt32(b * 255) << 8) | UInt32(alpha * 255)
            }
       */
        let cgImg = img.withUnsafeMutableBytes { (ptr) -> CGImage in
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
                return ctx.makeImage()!
            }
            Image(cgImg, scale: 0.7, label: Text("Last Frame"))
        
        }
    }
}


struct Frame_Previews: PreviewProvider {
    static var previews: some View {
        FrameView().preferredColorScheme(.dark)
    }
}
