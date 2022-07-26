//
//  GraphView.swift
//  Inspiration 4 Sandbox
//
//  Created by Duncan Wilkie on 5/24/21.
//

import SwiftUI




struct GraphView: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var config: Config
    @ObservedObject var slider: DoubleSlider
    
    @State var displayInfo: Bool = false
    @State var pressLocation: CGPoint = CGPoint.zero
    @State var nearestDatum: (Date, Double, Double, Double, Double, Double) = (Date(timeIntervalSinceReferenceDate: 0), 0, 0, 0, 0, 0) {
        didSet {
            let feedback = UIImpactFeedbackGenerator(style: .medium)
            feedback.impactOccurred()
        }
    }
    @ViewBuilder var body: some View {
        let startDate = Date(timeIntervalSinceReferenceDate: slider.lowHandle.currentValue)
        let endDate = Date(timeIntervalSinceReferenceDate: slider.highHandle.currentValue)
        
        
        if store.dataCount == 0 {
            Text("No Measurements Taken")
                .foregroundColor(Color.gray)
            
        } else {
            if slider.lowHandle.onDrag || slider.highHandle.onDrag {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: Color("primaryAccent")))
                    .scaleEffect(1.5)
            } else {
                let points = store.points(units: config.units,
                                          conversion: config.conversion_str,
                                          startDate: startDate,
                                          endDate: endDate,
                                          count: 120)
                
                
                VStack(alignment: .leading) {
                    let formatter = DateFormatter()
                    Text("\(autoDoubleFormatter(value: nearestDatum.3, unit: config.units + "/s", width: 6)) \(compressDate(nearestDatum.0, startDate, endDate, formatter))")
                        .foregroundColor(Color.white)
                        .frame(alignment: .leading)
                        .opacity(displayInfo ? 1.0 : 0.0)
                    GeometryReader { reader in
                        ZStack {
                            let toPixelsLine: (CGFloat, CGFloat) = (reader.size.width / CGFloat(points.width),
                                                                    reader.size.height / CGFloat(points.greatestMedian))
                            LinesView(data: points, start: startDate, end: endDate, toPixels: toPixelsLine, height: reader.size.height)
                                .opacity(config.plot == "line" ? 1.0 : 0)
                                .gesture(DragGesture(minimumDistance: 0, coordinateSpace: .local)
                                    .onChanged { value in
                                        self.displayInfo = true
                                        self.pressLocation = value.location
                                        let toPixels: CGFloat = reader.size.width / CGFloat(points.width)
                                        for i in points.stats {
                                            let checkDist = abs(CGFloat(i.0.timeIntervalSinceReferenceDate - startDate.timeIntervalSinceReferenceDate) * toPixels - pressLocation.x)
                                            let storedDist = abs(CGFloat(nearestDatum.0.timeIntervalSinceReferenceDate - startDate.timeIntervalSinceReferenceDate) * toPixels - pressLocation.x)
                                            if checkDist < storedDist {
                                                self.nearestDatum = i
                                            }
                                        }
                                    }
                                    .onEnded { _ in
                                        self.displayInfo = false
                                        self.pressLocation = .zero
                                    })
                            
                            let toPixelsBox = (reader.size.width / CGFloat(points.width),
                                               reader.size.height / CGFloat(points.height))
                            let spacing = 1.0
                            BoxWhiskerView(data: points, height: reader.size.height, width: reader.size.width,
                                           toPixels: toPixelsBox, spacing: spacing)
                            .opacity(config.plot == "bw" ? 1.0 : 0)
                            .gesture(DragGesture(minimumDistance: 0, coordinateSpace: .local)
                                .onChanged { value in
                                    self.displayInfo = true
                                    self.pressLocation = value.location
                                    let toPixels: CGFloat = reader.size.width / CGFloat(points.width)
                                    for i in points.stats {
                                        let checkDist = abs(CGFloat(i.0.timeIntervalSinceReferenceDate - startDate.timeIntervalSinceReferenceDate) * toPixels - pressLocation.x)
                                        let storedDist = abs(CGFloat(nearestDatum.0.timeIntervalSinceReferenceDate - startDate.timeIntervalSinceReferenceDate) * toPixels - pressLocation.x)
                                        if checkDist < storedDist {
                                            self.nearestDatum = i
                                        }
                                    }
                                }
                                .onEnded { _ in
                                    self.displayInfo = false
                                    self.pressLocation = .zero
                                })
                            
                            
                            
                            
                            
                            Path { path in // This is hard to separate out because of pressLocation, but it should be done
                                path.move(to: CGPoint(x: pressLocation.x, y:0))
                                path.addLine(to: CGPoint(x: pressLocation.x, y: reader.size.height))
                            }.stroke(Color.white, lineWidth: 3).opacity(displayInfo ? 1.0 : 0.0)
                        }
                    }
                }
            }
        }
    }
}




/* struct GraphView_Previews: PreviewProvider {
 static var previews: some View {
 GraphView(slider: DoubleSlider((Date(), Date(timeIntervalSinceReferenceDate: 0))))
 .environmentObject(Store())
 .preferredColorScheme(/*@START_MENU_TOKEN@*/.dark/*@END_MENU_TOKEN@*/)
 }
 } */
