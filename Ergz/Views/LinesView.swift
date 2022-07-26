//
//  LinesView.swift
//  Inspiration 4 Sandbox
//
//  Created by Duncan Wilkie on 6/11/21.
//

import SwiftUI

struct LinesView: View { // TODO: Make sure this displays an accurate graph
    var data: PointReport
    var start: Date
    var end: Date
    var toPixels: (CGFloat, CGFloat)
    var height: CGFloat

    
    var body: some View {
        
        Path { path in
            if !data.stats.isEmpty {
                path.move(to: CGPoint(x: 0,
                                      y: height - CGFloat(data.stats[0].3 - data.min)  * toPixels.1))
                for (date, _, _, med, _, _) in data.stats {
                    path.addLine(to: CGPoint(x: CGFloat(date.timeIntervalSinceReferenceDate -
                                                        start.timeIntervalSinceReferenceDate) * toPixels.0,
                                             y: height - CGFloat(med - data.min) * toPixels.1))
                }
            }
            
        }
        .stroke(Color("primaryAccent"), lineWidth: 1.5)
        
    }
    
    
}


//struct LinesView_Previews: PreviewProvider {
//  static var previews: some View {
//    LinesView()
//}
//}
