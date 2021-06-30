//
//  IndicatorLamp.swift
//  Inspiration 4 Sandbox
//
//  Created by Duncan Wilkie on 6/24/21.
//

import SwiftUI

struct Hatching: View {
    var density: Int
    var width: Int
    
    var body: some View {
        GeometryReader { reader in
            Path { path in
                for i in 0..<density {
                    path.move(to: CGPoint(x: -10, y: CGFloat(i) / CGFloat(density) * reader.size.height) )
                    path.addLine(to: CGPoint(x: reader.size.width + 10,
                                             y: CGFloat(i) / CGFloat(density) * reader.size.height -
                                                reader.size.width))
                }
            }.stroke(Color.black, lineWidth: CGFloat(width)).offset(x:0, y: 110)
        }
    }
}

struct IndicatorLamp: View {
    var label: String
    @ObservedObject var device: DeviceWrapper
    var body: some View {
        
        ZStack {
            ZStack {
                Circle()
                    .foregroundColor(device.onoff ? Color.green : Color.red)
                    .mask (
                        Hatching(density: 9, width: 30).clipShape(/*@START_MENU_TOKEN@*/Circle()/*@END_MENU_TOKEN@*/)
                        
                    ).shadow(color: device.onoff ? Color.green : Color.red, radius: 90)
            }
            .scaleEffect(0.1)
            
            
            Text("\(label)").position(x: 212, y:380).foregroundColor(.gray)
        }
    }
}

struct IndicatorLamp_Previews: PreviewProvider {
    
    static var previews: some View {
        IndicatorLamp(label: "Power", device: DeviceWrapper(true)).preferredColorScheme(.dark)
    }
}
