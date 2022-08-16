//
//  BoxWhiskerView.swift
//  Ergz
//
//  Created by Duncan Wilkie on 7/20/22.
//

import SwiftUI


struct BoxWhiskerView: View {
    var data: PointReport
    var height: CGFloat
    var width: CGFloat
    var toPixels: (CGFloat, CGFloat)
    var spacing: CGFloat
    var body: some View {
        let barRadius = data.stats.count == 0 || width / CGFloat(data.stats.count) / 2 < spacing ? 0 : width / CGFloat(data.stats.count) / 2 - spacing

        ZStack {
            Path { path in // Drawing the whiskers
                if !data.stats.isEmpty {
                    for (date, min, _, _, _, max) in data.stats {
                        let botWhiskerHeight = height - CGFloat(min - data.min) * toPixels.1
                        let centerPos = CGFloat(date.timeIntervalSinceReferenceDate -
                                                data.stats[0].0.timeIntervalSinceReferenceDate) * toPixels.0
                        let topWhiskerHeight = height - CGFloat(max - data.min) * toPixels.1
                        
                        path.move(to: CGPoint(x: centerPos - barRadius, y: botWhiskerHeight))
                        path.addLine(to: CGPoint(x: centerPos + barRadius, y: botWhiskerHeight))
                        path.move(to: CGPoint(x: centerPos, y: botWhiskerHeight))
                        path.addLine(to: CGPoint(x: centerPos, y: topWhiskerHeight))
                        path.move(to: CGPoint(x: centerPos - barRadius, y: topWhiskerHeight))
                        path.addLine(to: CGPoint(x: centerPos + barRadius, y: topWhiskerHeight))
                            
                    }
                }
            }.stroke(Color.gray)
            
            
            ForEach(data.stats, id: \.self.0) { tup in // Drawing the boxes
                let date: Date = tup.0
                let q1: Double = tup.2
                let med: Double = tup.3
                let q3: Double = tup.4

                RoundedRectangle(cornerRadius: 2.0)
                    .frame(width: 2 * barRadius, height: CGFloat(q3 - q1) * toPixels.1)
                    .position(x: CGFloat(date.timeIntervalSinceReferenceDate - data.stats[0].0.timeIntervalSinceReferenceDate) * toPixels.0,
                              y: height - CGFloat((q3 + q1) / 2 - data.min) * toPixels.1)
                    
                    .foregroundColor(Color("primaryAccent"))
                
                 Path { path in
                    path.move(to: CGPoint(x: CGFloat(date.timeIntervalSinceReferenceDate -
                                                     data.stats[0].0.timeIntervalSinceReferenceDate) * toPixels.0 - barRadius,
                                          y: height - CGFloat(med - data.min) * toPixels.1))
                    path.addLine(to: CGPoint(x: CGFloat(date.timeIntervalSinceReferenceDate -
                                                        data.stats[0].0.timeIntervalSinceReferenceDate) * toPixels.0 + barRadius,
                                             y: height - CGFloat(med - data.min) * toPixels.1))
                    
                 }.stroke(Color.gray)
                
            }
        }
    }
}

/* struct BoxWhiskerView_Previews: PreviewProvider {
 static var previews: some View {
 // BoxWhiskerView()
 }
 }
 */
