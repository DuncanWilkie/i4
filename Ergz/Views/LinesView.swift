//
//  LinesView.swift
//  Inspiration 4 Sandbox
//
//  Created by Duncan Wilkie on 6/11/21.
//

import SwiftUI

struct LinesView: View {
    var data: PointReport
    var start: Date
    var end: Date
    @State var displayInfo: Bool = false
    @State var pressLocation: CGPoint = CGPoint.zero
    @State var nearestDatum: (Date, Double) = (Date(timeIntervalSinceReferenceDate: 0), 0) {
        didSet {
            let feedback = UIImpactFeedbackGenerator(style: .medium)
            feedback.impactOccurred()
        }
    }
    
    
    var body: some View {
        VStack(alignment: .leading) {
            let formatter = DateFormatter()
            Text("\(String(Double(round(100*nearestDatum.1)/100))) keV/s \(autoFormatter(nearestDatum.0, start, end, formatter))")
                .foregroundColor(Color.white)
                .frame(alignment: .leading)
                .opacity(displayInfo ? 1.0 : 0.0)
            GeometryReader { reader in
                let toPixels: (CGFloat, CGFloat) = (reader.size.width / CGFloat(data.width),
                                                    reader.size.height / CGFloat(data.height))
                ZStack {
                    //show loading symbol when query is running
                    ProgressView().opacity(data.points.isEmpty ? 1.0 : 0.0)
                        .progressViewStyle(CircularProgressViewStyle(tint: Color("primaryAccent"))).scaleEffect(1.5)
                    //draw the path line
                    Path { path in
                        if !data.points.isEmpty {
                            path.move(to: CGPoint(x: 0,
                                                  y: reader.size.height - CGFloat(data.points[0].1 - data.min)  * toPixels.1))
                            for (date, dose) in data.points {
                                path.addLine(to: CGPoint(x: CGFloat(date.timeIntervalSinceReferenceDate -
                                                                    start.timeIntervalSinceReferenceDate) * toPixels.0,
                                                         y: reader.size.height - CGFloat(dose - data.min) * toPixels.1))
                            }
                        }
                        //draw
                        
                    }
                    .stroke(Color("primaryAccent"), lineWidth: 1.5)
                    .gesture(
                        DragGesture(minimumDistance: 0, coordinateSpace: .local)
                            .onChanged { value in
                                self.displayInfo = true
                                self.pressLocation = value.location
                                
                                for i in data.points {
                                    let checkDist = abs(CGFloat(i.0.timeIntervalSinceReferenceDate - start.timeIntervalSinceReferenceDate) * toPixels.0 - pressLocation.x)
                                    let storedDist = abs(CGFloat(nearestDatum.0.timeIntervalSinceReferenceDate - start.timeIntervalSinceReferenceDate) * toPixels.0 - pressLocation.x)
                                    if checkDist < storedDist {
                                        self.nearestDatum = i
                                    }
                                }
                            }
                            .onEnded { _ in
                                self.displayInfo = false
                                self.pressLocation = .zero
                            }
                    )
                    
                    Path { path in
                        path.move(to: CGPoint(x:pressLocation.x, y:0))
                        path.addLine(to: CGPoint(x: pressLocation.x, y: reader.size.height))
                    }.stroke(Color.white, lineWidth: 3).opacity(displayInfo ? 1.0 : 0.0)
                }
                
                
            }
        }
    }
}

//struct LinesView_Previews: PreviewProvider {
//  static var previews: some View {
//    LinesView()
//}
//}
