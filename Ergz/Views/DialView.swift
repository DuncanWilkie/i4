//
//  DialView.swift
//  Ergz
//
//  Created by Duncan Wilkie on 10/10/21.
//

import SwiftUI

// Courtesy PLnda on Github
struct DialView: View {
    private let bounds: (Double, Double)
    @State private var value: CGFloat = 0

    private let initialTemperature: CGFloat
    private let scale: CGFloat = 275
    private let indicatorLength: CGFloat = 25
    private let maxTemperature: CGFloat
    private let stepSize: CGFloat

    private var innerScale: CGFloat {
        return scale - indicatorLength
    }


    init(bounds: (Double, Double), stepSize: Double) {
        
        self.bounds = bounds
        initialTemperature = bounds.0
        maxTemperature = bounds.1
        self.stepSize = stepSize
    }

    private func angle(between starting: CGPoint, ending: CGPoint) -> CGFloat {
        let center = CGPoint(x: ending.x - starting.x, y: ending.y - starting.y)
        let radians = atan2(center.y, center.x)
        var degrees = 90 + (radians * 180 / .pi)

        if degrees < 0 {
            degrees += 360
        }

        return degrees
    }

    var body: some View {
        ZStack(alignment: .center) {
            Circle()
                .fill(Color(white: 0.2))
                .frame(width: self.innerScale, height: self.innerScale, alignment: .center)
                .rotationEffect(.degrees(-90))
                .gesture(
                    DragGesture().onChanged() { value in

                        let x: CGFloat = min(max(value.location.x, 0), self.innerScale)
                        let y: CGFloat = min(max(value.location.y, 0), self.innerScale)

                        let ending = CGPoint(x: x, y: y)
                        let start = CGPoint(x: (self.innerScale) / 2, y: (self.innerScale) / 2)

                        let angle = self.angle(between: start, ending: ending)
                        self.value = CGFloat(Int(angle / 360 * self.maxTemperature / self.stepSize)) / ((self.maxTemperature) / self.stepSize)
                    }
                )
            Circle()
                .stroke(Color.black, style: StrokeStyle(lineWidth: self.indicatorLength, lineCap: .butt, lineJoin: .miter, dash: [4]))
                .frame(width: self.scale, height: self.scale, alignment: .center)
            Circle()
                .trim(from: 0.0, to: self.value)
                .stroke(Color("primaryAccent"), style: StrokeStyle(lineWidth: self.indicatorLength, lineCap: .butt, lineJoin: .miter, dash: [4]))
                .rotationEffect(.degrees(-90))
                .frame(width: self.scale, height: self.scale, alignment: .center)

            Text("\(self.value * (self.maxTemperature) + self.initialTemperature, specifier: "%.1f") \u{2103}")
                .font(.largeTitle)
                .foregroundColor(Color.white)
                .fontWeight(.semibold)
        }
        .onAppear(perform: {
            self.value = 0.0
        })
    }
}

struct DialView_Previews: PreviewProvider {
    static var previews: some View {
        DialView(bounds: (15.0,25.0), stepSize: 0.1)
        .preferredColorScheme(.dark)
    }
}
