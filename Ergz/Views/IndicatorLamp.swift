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
            }.stroke(Color.black, lineWidth: CGFloat(width) ).offset(x:0, y: 110)
        }
    }
}

struct IndicatorLamp: View {
    var label: String
    var state: Bool
    var body: some View {
        ZStack {
            
            ZStack {
                Circle()
                    .foregroundColor(state ? Color.green : Color.red)
                    .mask (
                        Hatching(density: 9, width: 30).clipShape(/*@START_MENU_TOKEN@*/Circle()/*@END_MENU_TOKEN@*/)
                    ).shadow(color: state ? Color.green : Color.red, radius: 90)
            }
            .scaleEffect(0.2)
            
            
            
            Text("\(label)")
                .foregroundColor(.gray)
                .offset(x: 0, y:70)
        }
    }
}

struct IndicatorLamp_Previews: PreviewProvider {
    
    static var previews: some View {
        IndicatorLamp(label: "Power", state: true).preferredColorScheme(.dark)
    }
}
