//
//  GaugeView.swift
//  Inspiration 4 Sandbox
//
//  Created by Duncan Wilkie on 5/24/21.
//

import SwiftUI
import Foundation

//for testing; 
class DeviceWrapper: ObservableObject {
    @Published var relVal: Double = 0.0
    @Published var onoff: Bool = false
    init(_ val: Double) {
        self.relVal = val
    }
    init( _ onoff: Bool) {
        self.onoff = onoff
    }
}


struct GaugeView: View {
    var startVal: Double = 0
    var endVal: Double = 100
    var density: Int = 12
    var label: String = "Temp"

    @ObservedObject var value: DeviceWrapper
    var body: some View {
        GeometryReader { reader in
            ZStack {
                let offset = (Double(reader.size.width / 2),
                              Double(reader.size.height / 2))
                let centerRadius: Double = Double(reader.size.width * 0.05)
                let pointerLength: Double = Double(reader.size.width * 0.4)
                let tickLength: Double = Double(reader.size.width * 0.075)
                
                Path { path in
                    for angleIndex in 0...density {
                        let angle =  -1 * Double(angleIndex) * Double.pi / Double(density)
                        let r = Double(min(reader.size.width, reader.size.height)) / 2
                        
                        
                        
                        path.move(to: CGPoint(x: r * cos(angle) + offset.0,
                                              y: r * sin(angle) + offset.1))
                        let reduction = Double(angleIndex % 2 + 1)
                        let r2 = r - tickLength / reduction
                        path.addLine(to: CGPoint(x: r2 * cos(angle) + offset.0,
                                                 y: r2 * sin(angle) + offset.1))
                    }
                }
                .stroke(Color.white, lineWidth: 2)
                
                Path { path in
                    let valueAngle = Double.pi - value.relVal * Double.pi
                    
                    let startAngle = valueAngle - Double.pi / 2
                    let baseStart = CGPoint(x: offset.0 + centerRadius * cos(startAngle),
                                            y: offset.1 - centerRadius * sin(startAngle))
                    
                    let endAngle = valueAngle + Double.pi / 2
                    let baseEnd = CGPoint(x: offset.0 + centerRadius * cos(endAngle),
                                          y: offset.1 - centerRadius * sin(endAngle))
                    
                    let apex = CGPoint(x: offset.0 + pointerLength * cos(valueAngle),
                                       y: offset.1 - pointerLength * sin(valueAngle))
                    path.move(to: baseStart)
                    path.addLine(to: baseEnd)
                    path.addLine(to: apex)
                    path.addLine(to: baseStart)
                }
                .fill(Color("primaryAccent"))
                .shadow(color: Color("primaryAccent"), radius: 10)
                
                Circle()
                    .frame(width: CGFloat(centerRadius * 2),
                           height: CGFloat(centerRadius * 2))
                    .position(x: CGFloat(offset.0), y: CGFloat(offset.1))
                    .foregroundColor(.gray)
                
                Text("\(String(String((endVal - startVal) * value.relVal).prefix(5)))")
                    .offset(x: CGFloat(0), y: CGFloat(40))
                    .scaleEffect(2.5)
                
                RoundedRectangle(cornerRadius: 20).stroke(Color.gray, lineWidth: 8)
                    .frame(width: 150, height: 75)
                    .offset(x: 0.0, y: 100)
            }
        }
    }
}

struct GaugeView_Previews: PreviewProvider {
    static var previews: some View {
        GaugeView(value: DeviceWrapper(0.7245)).preferredColorScheme(.dark)
    }
}
